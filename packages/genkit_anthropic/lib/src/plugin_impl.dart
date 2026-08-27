// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:collection';
import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as sdk;
import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'known_models.dart';
import 'model.dart';

final _logger = Logger('genkit_anthropic');

/// Fallback capabilities for Claude models resolved by name without a curated
/// entry.
///
/// Claims [baseClaudeSupports], not [structuredClaudeSupports]: the structured
/// output this plugin sends today is the forced `return_output` tool below
/// (`:252-262`), and not every Claude name accepts a forced `tool_choice` -
/// `claude-fable-5-1`, for one, answers `tool_choice` `type: "tool"` with a
/// 400. Curation is the only signal this plugin has for which names do, so an
/// uncurated name withholds the claim and core simulates instead: a longer
/// prompt rather than a rejection.
final commonModelInfo = ModelInfo(supports: baseClaudeSupports);

/// Anthropic returns 529 when the API is overloaded.
const _overloadedStatusCode = 529;

StatusCodes _statusForHttpCode(int code) => code == _overloadedStatusCode
    ? StatusCodes.UNAVAILABLE
    : StatusCodes.fromHttpStatus(code);

/// Beta features requested when a request resolves to the beta API surface.
///
/// Sent as the `anthropic-beta` header. Mirrors the list the Genkit JS plugin
/// enables by default; a request can replace it via `AnthropicOptions.betas`.
const defaultAnthropicBetas = <String>[
  'files-api-2025-04-14',
  'effort-2025-11-24',
  'structured-outputs-2025-11-13',
  'task-budgets-2026-03-13',
];

/// Resolves whether a request runs against the beta API surface.
///
/// The request's own `apiVersion` wins, then the plugin default, else stable.
@visibleForTesting
bool resolveBetaEnabled(String? requestApiVersion, String? pluginApiVersion) {
  final selected = requestApiVersion ?? pluginApiVersion;
  return selected == 'beta';
}

/// Core Genkit plugin implementation for Anthropic Claude models.
///
/// Automatically discovers available models from the Anthropic API and
/// registers them in the Genkit action registry.
@visibleForTesting
class AnthropicPluginImpl extends GenkitPlugin {
  /// The static API key used to authenticate requests.
  final String? apiKey;

  /// Extra HTTP headers sent with every request.
  final Map<String, String>? headers;

  /// Custom base URL for the Anthropic API.
  final String? baseUrl;

  /// Optional HTTP client used for every request. Useful for proxies,
  /// instrumentation, or injecting a mock transport in tests.
  final http.Client? httpClient;

  /// Default Anthropic API surface (`'stable'` or `'beta'`) for every request.
  ///
  /// A request's own `apiVersion` overrides this. Defaults to stable.
  final String? apiVersion;

  sdk.AnthropicClient? _client;

  /// Creates an [AnthropicPluginImpl].
  AnthropicPluginImpl({
    this.apiKey,
    this.headers,
    this.baseUrl,
    this.httpClient,
    this.apiVersion,
  });

  @override
  String get name => 'anthropic';

  /// Curated per-model capability metadata, keyed by bare model name.
  ///
  /// Names absent here still resolve; they fall back to [commonModelInfo].
  final Map<String, ModelInfo> knownModels = UnmodifiableMapView(
    knownClaudeModels,
  );

  /// Strips a trailing dated-snapshot suffix (e.g.
  /// `claude-haiku-4-5-20251001` -> `claude-haiku-4-5`) so dated ids returned
  /// by the models endpoint map onto the curated aliases.
  static String _aliasOf(String modelName) => claudeModelAlias(modelName);

  /// Whether this plugin's requests default to the beta API surface.
  bool get _betaByDefault => apiVersion == 'beta';

  /// Returns the capability metadata for [modelName], matching by exact name
  /// first and then by dated-snapshot alias, falling back to [commonModelInfo]
  /// for names not in [knownModels].
  ///
  /// The claim follows the surface this plugin defaults to, because the
  /// mechanism does: on beta a curated model is served by
  /// `output_config.format` and claims `constrained: true`, on stable by the
  /// forced `return_output` tool and claims `'no-tools'`.
  ///
  /// The plugin's default, not the request's: core reads this to decide
  /// whether to simulate, and it reads it before the request's own config is
  /// in hand. A request that overrides `apiVersion` to beta is therefore
  /// judged by the stable claim - simulated where the native path would have
  /// served it, which costs a longer prompt. The reverse override is the one
  /// that cannot be absorbed quietly, and `_assertToolOutputAllowed` says so.
  ModelInfo modelInfoFor(String modelName) {
    final curated =
        knownClaudeModelFor(modelName) ??
        knownClaudeModelFor(_aliasOf(modelName));
    return curated?.infoFor(beta: _betaByDefault) ?? commonModelInfo;
  }

  sdk.AnthropicClient get client {
    if (_client != null) return _client!;
    if (apiKey != null) {
      return _client = sdk.AnthropicClient.withApiKey(
        apiKey!,
        defaultHeaders: headers,
        baseUrl: baseUrl,
        httpClient: httpClient,
      );
    }
    final config = sdk.AnthropicConfig.fromEnvironment();
    return _client = sdk.AnthropicClient(
      config: config.copyWith(defaultHeaders: headers, baseUrl: baseUrl),
      httpClient: httpClient,
    );
  }

  ActionMetadata _curatedMetadata(String name, ModelInfo info) => modelMetadata(
    'anthropic/$name',
    customOptions: AnthropicOptions.$schema,
    modelInfo: info,
  );

  @override
  Future<List<ActionMetadata>> list() async {
    // Attempt to enrich the curated catalog with dynamically discovered
    // models; fall back to the curated catalog alone if listing fails.
    try {
      final response = await client.models.list();
      final discovered = response.data
          .map((m) => _curatedMetadata(m.id, modelInfoFor(m.id)))
          .toList();
      // Curated aliases already covered by discovery. The endpoint may return
      // dated snapshot ids (e.g. `claude-haiku-4-5-20251001`), so match on the
      // alias to both enrich (above) and dedup against the curated catalog.
      final coveredAliases = response.data.map((m) => _aliasOf(m.id)).toSet();

      // Curated models are listed even when discovery omits them.
      // Through `modelInfoFor`, not the map's own values: the claim depends
      // on the surface this plugin defaults to, and a listing that disagreed
      // with what `resolve` registers would have the Dev UI describing a
      // model the plugin does not serve.
      final curated = knownModels.keys
          .where((name) => !coveredAliases.contains(name))
          .map((name) => _curatedMetadata(name, modelInfoFor(name)));

      return [...discovered, ...curated];
    } catch (e, s) {
      // The sibling plugins rethrow here; this plugin degrades gracefully
      // instead, advertising the curated catalog so known models stay listable
      // when discovery is unavailable (e.g. offline).
      _logger.warning('Failed to list Anthropic models: $e', e, s);
      return [
        for (final name in knownModels.keys)
          _curatedMetadata(name, modelInfoFor(name)),
      ];
    }
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType != .model) return null;
    return _createModel(name);
  }

  Model _createModel(String modelName) {
    return _createModelWithClient(modelName, client);
  }

  Model _createModelWithClient(String modelName, sdk.AnthropicClient client) {
    return Model(
      name: 'anthropic/$modelName',
      customOptions: AnthropicOptions.$schema,
      metadata: {'model': modelInfoFor(modelName).toJson()},
      fn: (req, ctx) async {
        final options = req!.config == null
            ? AnthropicOptions()
            : AnthropicOptions.$schema.parse(req.config!);

        final requestClient = options.apiKey != null
            ? sdk.AnthropicClient.withApiKey(
                options.apiKey!,
                defaultHeaders: headers,
                baseUrl: baseUrl,
                httpClient: httpClient,
              )
            : client;

        try {
          final beta = resolveBetaEnabled(options.apiVersion, apiVersion);
          final createRequest = _buildCreateRequest(
            req,
            modelName,
            options,
            beta: beta,
          );
          // Empty on the stable surface, which suppresses the header entirely.
          final betas = beta
              ? (options.betas ?? defaultAnthropicBetas)
              : const <String>[];

          if (ctx.streamingRequested) {
            final stream = requestClient.messages.createStream(
              createRequest,
              betas: betas,
            );
            final accumulator = sdk.MessageStreamAccumulator();
            await for (final event in stream) {
              accumulator.add(event);
              _handleStreamEvent(event, ctx.sendChunk);
            }
            final message = accumulator.toMessage();
            return ModelResponse(
              finishReason: mapFinishReason(message.stopReason),
              message: fromAnthropicMessage(message),
              usage: mapUsage(message.usage),
            );
          } else {
            final response = await requestClient.messages.create(
              createRequest,
              betas: betas,
            );
            return ModelResponse(
              finishReason: mapFinishReason(response.stopReason),
              message: fromAnthropicMessage(response),
              usage: mapUsage(response.usage),
              raw: response.toJson(),
            );
          }
        } catch (e, stackTrace) {
          if (e is GenkitException) rethrow;
          StatusCodes? status;
          String? details;
          if (e is sdk.ApiException) {
            status = _statusForHttpCode(e.statusCode);
            details = e.message;
          }
          throw GenkitException(
            'Anthropic API error: $e',
            status: status,
            details: details ?? e.toString(),
            underlyingException: e,
            stackTrace: stackTrace,
          );
        } finally {
          if (options.apiKey != null) {
            requestClient.close();
          }
        }
      },
    );
  }

  sdk.MessageCreateRequest _buildCreateRequest(
    ModelRequest req,
    String modelName,
    AnthropicOptions options, {
    required bool beta,
  }) {
    final systemMessage = req.messages
        .where((m) => m.role == Role.system)
        .firstOrNull;

    final system = systemMessage != null
        ? convertSystemMessage(systemMessage)
        : null;

    // History is reconverted in full on every request, so one unsigned part in
    // turn 1 would otherwise warn once per turn for the rest of the
    // conversation. Conversion is synchronous, so this is a request-scoped
    // flag in practice.
    _warnedUnsigned = false;
    final messages = req.messages
        .where((m) => m.role != Role.system)
        .map(toAnthropicMessage)
        .toList();

    final tools =
        req.tools?.map(toAnthropicTool).toList() ?? <sdk.ToolDefinition>[];

    sdk.ToolChoice? toolChoice;
    sdk.JsonOutputFormat? outputFormat;

    if (req.output?.schema != null) {
      final schema = Map<String, dynamic>.from(req.output!.schema!);

      if (_supportsNativeStructuredOutput(modelName, beta: beta)) {
        // Native structured output needs no forced tool, so it composes with
        // manual thinking - unlike the fallback below. The schema goes over
        // as-authored; adding a `type` here would collide with a `$ref` root.
        outputFormat = sdk.JsonOutputFormat(schema: _toAnthropicSchema(schema));
      } else {
        // Outside beta there is no `output_config.format`, so the schema is
        // served by a tool the model is forced to call.
        //
        // Forced only for a request that asked to be constrained: with
        // `constrained: false` the caller opted out of the mechanism and core
        // stripped nothing, so the tool is offered rather than pinned - and
        // the two restrictions below, which are restrictions on pinning, do
        // not apply.
        final pinsOutputTool = req.output?.constrained == true;
        if (pinsOutputTool) {
          _assertToolOutputAllowed(req, modelName, options);
        }
        // Anthropic's tool input schemas must declare an object type.
        if (!schema.containsKey('type')) {
          schema['type'] = 'object';
        }
        const toolName = 'return_output';
        tools.add(
          sdk.ToolDefinition.custom(
            sdk.Tool(
              name: toolName,
              description: 'Return the structured output.',
              inputSchema: sdk.InputSchema.fromJson(schema),
            ),
          ),
        );
        if (pinsOutputTool) {
          toolChoice = sdk.ToolChoice.tool(toolName);
        }
      }
    }

    // The forced `return_output` tool is the whole mechanism behind the
    // `constrained` claim on the fallback path, so it outranks the caller's
    // `toolChoice`: honouring a `none` there would leave the model neither the
    // tool nor the instructions core stripped. Nothing is forced on the native
    // path or for an unconstrained request, and then the caller's choice
    // stands.
    if (req.toolChoice != null && toolChoice == null) {      toolChoice = switch (req.toolChoice) {
        'auto' => sdk.ToolChoice.auto(),
        'any' => sdk.ToolChoice.any(),
        'none' => sdk.ToolChoice.none(),
        final name => sdk.ToolChoice.tool(name!),
      };
    }

    final thinking = _mapThinkingConfig(options.thinking, modelName);
    final outputConfig = _mapOutputConfig(options.outputConfig, outputFormat);

    return sdk.MessageCreateRequest(
      model: modelName,
      messages: messages,
      system: system,
      maxTokens: options.maxTokens ?? 4096,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      stopSequences: options.stopSequences,
      tools: tools.isNotEmpty ? tools : null,
      toolChoice: toolChoice,
      thinking: thinking,
      outputConfig: outputConfig,
    );
  }

  void close() {
    _client?.close();
  }
}

/// Converts a Genkit system [Message] to an Anthropic [sdk.SystemPrompt].
sdk.SystemPrompt? convertSystemMessage(Message m) {
  final parts = <String>[];
  for (final p in m.content) {
    if (p.isText) {
      parts.add(p.text!);
    }
  }
  final text = parts.join('\n');
  if (text.isEmpty) return null;
  return sdk.SystemPrompt.text(text);
}

/// Metadata key carrying an Anthropic thinking block's signature.
///
/// Matches the key used by the Gemini plugins and by Genkit JS.
const _thoughtSignatureKey = 'thoughtSignature';

/// The key this plugin wrote for the same value through v0.3.1.
///
/// Read, never written. Conversations persisted by an earlier version carry
/// it, and a session replayed after upgrading would otherwise have its
/// thinking blocks dropped for want of a signature that is right there under
/// the old name - the exact failure this conversion exists to prevent.
const _legacyThoughtSignatureKey = 'signature';

/// Metadata key carrying the opaque payload of a redacted thinking block.
const _redactedThinkingKey = 'redactedThinking';

/// Rebuilds the Anthropic thinking block [p] came from, or null when it
/// cannot be rebuilt.
///
/// Null means the part is dropped: Anthropic rejects a thinking block whose
/// signature is missing, so a part that never carried one - hand-built
/// history, say - is left out rather than turned into a request the API will
/// reject.
///
/// Reasoning from another provider is a known limitation, not something this
/// catches. The Gemini plugins write the same [_thoughtSignatureKey], so a
/// Gemini part arrives with a signature Anthropic cannot verify and is
/// forwarded, then rejected server-side. Genkit JS collides the same way.
///
/// Blocks are replayed whether or not thinking is enabled for the request in
/// hand. Anthropic documents that toggling thinking mid-conversation does not
/// error: the API disables it for that request and strips blocks that would
/// leave the turn structure invalid. Sending them unconditionally is
/// therefore safe, and the wire tests assert it.
sdk.InputContentBlock? _toAnthropicThinkingBlock(Part p) {
  // A part carrying the key at all is a redacted block, so it is judged as
  // one. Falling through to the signature check would blame a missing
  // thoughtSignature for a payload problem, naming a key nothing read.
  //
  // This wins over a signature on the same part, which only a hand-built part
  // can have: the two keys land on disjoint part types coming back from the
  // API. Redacted first because its payload is the half that cannot be
  // reconstructed - a thought whose signature is dropped can be sent again
  // from the model, an opaque payload cannot.
  if (_claimsRedactedThinking(p)) {
    final redacted = _redactedThinkingPayload(p);
    if (redacted != null) {
      return sdk.RedactedThinkingInputBlock(data: redacted);
    }
    _logger.warning(
      'Dropping a redacted thinking part: its $_redactedThinkingKey payload '
      'is empty or not a string. Anthropic requires the payload echoed back '
      'exactly as it arrived.',
    );
    return null;
  }

  final metadata = p.metadata;
  final signature =
      metadata?[_thoughtSignatureKey] ?? metadata?[_legacyThoughtSignatureKey];
  if (signature is! String || signature.isEmpty) {
    const message =
        'Dropping a reasoning part with no thoughtSignature: Anthropic '
        'rejects a thinking block whose signature is missing or altered. '
        'Preserve the metadata a model turn came back with to replay it.';
    // Once per request: the same part is reconverted on every turn after the
    // one that produced it, and repeating the warning for each says nothing
    // new.
    if (_warnedUnsigned) {
      _logger.fine(message);
    } else {
      _warnedUnsigned = true;
      _logger.warning(message);
    }
    return null;
  }

  return sdk.ThinkingInputBlock(
    thinking: p.reasoning ?? '',
    signature: signature,
  );
}

/// Whether an unsigned reasoning part has already been reported for the
/// request being converted. Reset in `generate`.
bool _warnedUnsigned = false;

/// Whether [p] presents itself as a redacted thinking block, whatever the
/// state of its payload.
bool _claimsRedactedThinking(Part p) =>
    p.custom?.containsKey(_redactedThinkingKey) == true ||
    p.metadata?.containsKey(_redactedThinkingKey) == true;

/// The opaque payload of a redacted thinking block carried by [p], if any.
///
/// Accepts both shapes: the [CustomPart] this plugin now emits, which is what
/// Genkit JS reads and writes, and the [ReasoningPart] it wrote through v0.3.1,
/// so history persisted by an earlier version still replays.
String? _redactedThinkingPayload(Part p) {
  for (final value in [
    p.custom?[_redactedThinkingKey],
    p.metadata?[_redactedThinkingKey],
  ]) {
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// Converts a Genkit [Message] to an Anthropic [sdk.InputMessage].
sdk.InputMessage toAnthropicMessage(Message m) {
  final isUser = m.role == Role.user || m.role == Role.tool;

  final blocks = m.content.expand<sdk.InputContentBlock>((p) {
    if (p.isReasoning || p.custom?.containsKey(_redactedThinkingKey) == true) {
      // Anthropic accepts thinking blocks only on assistant turns, and only
      // when echoed back complete and unmodified.
      return isUser
          ? const <sdk.InputContentBlock>[]
          : [?_toAnthropicThinkingBlock(p)];
    } else if (p.isText) {
      return [sdk.InputContentBlock.text(p.text!)];
    } else if (p.isToolRequest) {
      final req = p.toolRequest!;
      return [
        sdk.InputContentBlock.toolUse(
          id: req.ref ?? '',
          name: req.name,
          input: req.input is Map
              ? (req.input as Map).cast<String, dynamic>()
              : <String, dynamic>{},
        ),
      ];
    } else if (p.isToolResponse) {
      final res = p.toolResponse!;
      // Multipart tool content (images, media, etc.) travels alongside the
      // structured output. Anthropic tool_result blocks accept text and image
      // content, so map any image media parts to image content and keep the
      // structured output as text.
      final content = <sdk.ToolResultContent>[
        sdk.ToolResultContent.text(jsonEncode(res.output)),
        ...?res.content
            ?.map((c) => Part.fromJson((c as Map).cast<String, dynamic>()))
            .where((part) => part.isMedia)
            .map((part) => _toAnthropicToolResultImage(part.media!))
            .nonNulls,
      ];
      return [
        sdk.InputContentBlock.toolResult(
          toolUseId: res.ref ?? '',
          content: content,
        ),
      ];
    } else if (p.isMedia) {
      final media = p.media!;
      return _convertMediaFromJson(media.url, media.contentType);
    }
    return <sdk.InputContentBlock>[];
  }).toList();

  return isUser
      ? sdk.InputMessage.userBlocks(blocks)
      : sdk.InputMessage.assistantBlocks(blocks);
}

const _base64Marker = ';base64';
final _whitespace = RegExp(r'\s');

List<sdk.InputContentBlock> _convertMediaFromJson(
  String url,
  String? contentType,
) {
  final declaredMime = _cleanMimeType(contentType);
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    final header = comma < 0
        ? ''
        : url.substring('data:'.length, comma).toLowerCase();
    final base64Data = comma < 0
        ? ''
        : url.substring(comma + 1).replaceAll(_whitespace, '');
    if (!header.endsWith(_base64Marker) || base64Data.isEmpty) {
      final preview = url.length > 64 ? '${url.substring(0, 64)}...' : url;
      throw GenkitException(
        'Invalid media data URL for Anthropic: expected '
        '"data:<mime>;base64,<data>", got "$preview".',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final urlMime = _cleanMimeType(
      header.substring(0, header.length - _base64Marker.length),
    );
    final mimeType = urlMime ?? declaredMime;
    if (mimeType == 'application/pdf') {
      return [
        sdk.InputContentBlock.document(
          sdk.DocumentSource.base64Pdf(base64Data),
        ),
      ];
    }
    return [
      sdk.InputContentBlock.image(
        sdk.ImageSource.base64(
          data: base64Data,
          mediaType: _requireImageMediaType(mimeType),
        ),
      ),
    ];
  }
  if (declaredMime == 'application/pdf') {
    return [sdk.InputContentBlock.document(sdk.DocumentSource.url(url))];
  }
  if (declaredMime != null) {
    _requireImageMediaType(declaredMime);
  }
  return [sdk.InputContentBlock.image(sdk.ImageSource.url(url))];
}

/// Maps a Genkit image [Media] to an Anthropic [sdk.ToolResultContent] image.
///
/// Returns null for non-image or non-data URLs, since Anthropic tool_result
/// image content only supports base64-encoded image sources.
sdk.ToolResultContent? _toAnthropicToolResultImage(Media media) {
  final contentType = media.contentType ?? '';
  if (!media.url.startsWith('data:')) return null;
  if (contentType.isNotEmpty && !contentType.startsWith('image/')) return null;
  final commaIdx = media.url.indexOf(',');
  if (commaIdx < 0) return null;
  final base64Data = media.url.substring(commaIdx + 1);
  final mimeType = contentType.isEmpty ? 'image/png' : contentType;
  return sdk.ToolResultContent.image(
    sdk.ImageSource.base64(
      data: base64Data,
      mediaType: _requireImageMediaType(mimeType),
    ),
  );
}

String? _cleanMimeType(String? contentType) {
  final mimeType = contentType?.split(';').first.trim().toLowerCase();
  return mimeType?.isEmpty ?? true ? null : mimeType;
}

sdk.ImageMediaType _requireImageMediaType(String? mimeType) {
  return switch (mimeType) {
    'image/jpeg' || 'image/jpg' => sdk.ImageMediaType.jpeg,
    'image/png' => sdk.ImageMediaType.png,
    'image/gif' => sdk.ImageMediaType.gif,
    'image/webp' => sdk.ImageMediaType.webp,
    _ => throw GenkitException(
      'Unsupported media type for Anthropic: ${mimeType ?? '(none)'}. '
      'Supported: image/jpeg, image/png, image/gif, image/webp, '
      'application/pdf.',
      status: StatusCodes.INVALID_ARGUMENT,
    ),
  };
}

/// Converts a Genkit [ToolDefinition] to an Anthropic [sdk.ToolDefinition].
sdk.ToolDefinition toAnthropicTool(ToolDefinition t) {
  final schema = Map<String, dynamic>.from(t.inputSchema?.flatten() ?? {});
  if (!schema.containsKey('type')) {
    schema['type'] = 'object';
  }
  return sdk.ToolDefinition.custom(
    sdk.Tool(
      name: t.name,
      description: t.description,
      inputSchema: sdk.InputSchema.fromJson(schema),
    ),
  );
}

/// Converts an Anthropic [sdk.Message] to a Genkit [Message].
Message fromAnthropicMessage(sdk.Message m) {
  final content = m.content
      .map(
        (block) => switch (block) {
          sdk.TextBlock(:final text) => TextPart(text: text),
          sdk.ToolUseBlock(:final id, :final name, :final input) =>
            name == 'return_output'
                ? TextPart(text: jsonEncode(_extractOutput(input)))
                : ToolRequestPart(
                        toolRequest: ToolRequest(
                          ref: id,
                          name: name,
                          input: input,
                        ),
                      )
                      as Part,
          sdk.ThinkingBlock(:final thinking, :final signature) => ReasoningPart(
            reasoning: thinking,
            metadata: {_thoughtSignatureKey: signature},
          ),
          // The payload is opaque and unreadable, but Anthropic still requires
          // it echoed back on later turns, so it is preserved rather than
          // dropped. A CustomPart, not a ReasoningPart: the payload is not
          // reasoning text and there is none to carry. Matches the shape
          // Genkit JS persists, so a conversation crosses between the SDKs,
          // and spares consumers an empty ReasoningPart in `message.content`.
          sdk.RedactedThinkingBlock(:final data) => CustomPart(
            custom: {_redactedThinkingKey: data},
          ),
          _ => TextPart(text: ''),
        },
      )
      .where((p) => p is! TextPart || p.text.isNotEmpty)
      .toList();

  return Message(role: Role.model, content: content);
}

Map<String, dynamic> _extractOutput(Map<String, dynamic> input) {
  if (input.keys.length == 1) {
    if (input.containsKey('output') && input['output'] is Map) {
      return input['output'] as Map<String, dynamic>;
    } else if (input.containsKey('\$output') && input['\$output'] is Map) {
      return input['\$output'] as Map<String, dynamic>;
    }
  }
  return input;
}

/// Resolves the effective thinking type, applying the curated per-model default
/// when the request does not name one.
String _resolveThinkingType(ThinkingConfig config, String modelName) {
  final type =
      config.type ?? knownClaudeModelFor(modelName)?.defaultThinkingMode.name;
  if (type == null) {
    throw GenkitException(
      'Set thinking.type explicitly for unknown Anthropic model "$modelName".',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return type;
}

sdk.ThinkingConfig? _mapThinkingConfig(
  ThinkingConfig? config,
  String modelName,
) {
  if (config == null) return null;

  final type = _resolveThinkingType(config, modelName);

  return switch (type) {
    'disabled' => sdk.ThinkingConfig.disabled(),
    'adaptive' => sdk.ThinkingConfig.adaptive(),
    // 1024 is the minimum budget_tokens required by the Anthropic API.
    'enabled' => sdk.ThinkingConfig.enabled(
      budgetTokens: config.budgetTokens ?? 1024,
    ),
    _ => throw GenkitException(
      'Unsupported Anthropic thinking type "$type".',
      status: StatusCodes.INVALID_ARGUMENT,
    ),
  };
}

/// Whether the schema can travel as `output_config.format` for this request.
///
/// Two conditions, and both are load-bearing. The feature is beta-gated
/// (`structured-outputs-2025-11-13`), so a stable request has no such field to
/// put it in. And it is a per-model list, which only a curated entry can speak
/// for: an uncurated name gets no claim either way, which is why
/// `commonModelInfo` withholds `constrained` and lets core simulate rather
/// than betting the request on a guess.
bool _supportsNativeStructuredOutput(String modelName, {required bool beta}) =>
    beta && (knownClaudeModelFor(modelName)?.structuredOutputs ?? false);

/// Rewrites a Genkit JSON schema into the shape Anthropic accepts.
///
/// Anthropic rejects `$schema` and requires `additionalProperties: false` on
/// every object, including ones nested under `$defs`.
Map<String, dynamic> _toAnthropicSchema(Map<String, dynamic> schema) {
  final out = <String, dynamic>{};
  for (final entry in schema.entries) {
    if (entry.key == r'$schema') continue;
    out[entry.key] = _normalizeSchemaValue(entry.value);
  }
  // A `$ref` node may not carry sibling constraints; Anthropic rejects the
  // combination outright. Named Genkit schemas arrive as a bare `$ref` plus
  // `$defs`, and the recursion above has already closed the definitions.
  if (out.containsKey(r'$ref')) return out;

  // A hand-written schema may describe an object through its keywords alone.
  // Anthropic needs the type spelled out before it will accept the closed
  // marker below, so infer it the way the tool fallback does.
  if (!out.containsKey('type') &&
      (out.containsKey('properties') || out.containsKey('required'))) {
    out['type'] = 'object';
  }
  if (out['type'] == 'object') {
    out['additionalProperties'] = false;
  }
  return out;
}

Object? _normalizeSchemaValue(Object? value) => switch (value) {
  final Map<String, dynamic> map => _toAnthropicSchema(map),
  final Map map => _toAnthropicSchema(map.cast<String, dynamic>()),
  final List list => list.map(_normalizeSchemaValue).toList(),
  _ => value,
};

/// Guards the tool-based structured-output fallback against manual thinking.
///
/// The fallback forces `tool_choice`, which Anthropic rejects when extended
/// thinking is on. Native structured output has no such conflict, so the fix is
/// to move to a model that supports it rather than to drop thinking.
void _assertToolOutputAllowed(
  ModelRequest req,
  String modelName,
  AnthropicOptions options,
) {
  // Core keeps the caller's tools away from this path by simulating for a
  // model that claims `'no-tools'` - unless the request talked its way here by
  // overriding `apiVersion` to stable, after core read a `constrained: true`
  // claim that only holds on beta. Forcing `return_output` then would leave
  // the caller's tools on the wire and unreachable, and the tool loop would
  // silently never fire.
  if (req.tools?.isNotEmpty ?? false) {
    throw GenkitException(
      'Structured output with tools needs the beta API for "$modelName": the '
      'stable surface serves the schema with a forced tool call, which the '
      "request's own tools could then never reach. Drop the request's "
      'apiVersion override, or ask for structured output without tools.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final thinking = options.thinking;
  if (thinking == null) return;
  // Resolve through the same path the wire uses, so a bare ThinkingConfig()
  // that defaults to manual on a 4.5-era model is caught too.
  if (_resolveThinkingType(thinking, modelName) != 'enabled') return;

  throw GenkitException(
    'Structured output with manual thinking is not supported for '
    '"$modelName": it needs a forced tool call, which Anthropic rejects '
    'alongside extended thinking. Use a model with native structured output '
    'support, or set thinking.type to "adaptive" or "disabled".',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

sdk.OutputConfig? _mapOutputConfig(
  AnthropicOutputConfig? config,
  sdk.JsonOutputFormat? format,
) {
  final effort = config?.effort;
  if (effort == null && format == null) return null;
  if (effort == null) return sdk.OutputConfig(format: format);

  return sdk.OutputConfig(
    format: format,
    effort: switch (effort) {
      'low' => sdk.EffortLevel.low,
      'medium' => sdk.EffortLevel.medium,
      'high' => sdk.EffortLevel.high,
      'xhigh' => sdk.EffortLevel.xhigh,
      'max' => sdk.EffortLevel.max,
      _ => throw GenkitException(
        'Unsupported Anthropic output effort "$effort".',
        status: StatusCodes.INVALID_ARGUMENT,
      ),
    },
  );
}

/// Emits streaming chunks for content deltas and throws on error events.
void _handleStreamEvent(
  sdk.MessageStreamEvent event,
  void Function(ModelResponseChunk chunk) sendChunk,
) {
  switch (event) {
    case sdk.ContentBlockDeltaEvent(:final index, :final delta):
      switch (delta) {
        case sdk.TextDelta(:final text):
          sendChunk(
            ModelResponseChunk(
              index: index,
              content: [TextPart(text: text)],
            ),
          );
        case sdk.ThinkingDelta(:final thinking):
          sendChunk(
            ModelResponseChunk(
              index: index,
              content: [ReasoningPart(reasoning: thinking)],
            ),
          );
        case sdk.InputJsonDelta():
        case sdk.SignatureDelta():
        case sdk.CitationsDelta():
        case sdk.CompactionDelta():
        case sdk.UnknownContentBlockDelta():
      }
    case sdk.ErrorEvent(:final message):
      throw GenkitException(
        'Anthropic stream error: $message',
        status: StatusCodes.INTERNAL,
      );
    default:
  }
}

/// Maps an Anthropic [sdk.StopReason] to a Genkit [FinishReason].
FinishReason mapFinishReason(sdk.StopReason? reason) {
  return switch (reason) {
    sdk.StopReason.endTurn => FinishReason.stop,
    sdk.StopReason.maxTokens => FinishReason.length,
    sdk.StopReason.stopSequence => FinishReason.stop,
    sdk.StopReason.toolUse => FinishReason.stop,
    sdk.StopReason.pauseTurn => FinishReason.stop,
    sdk.StopReason.compaction => FinishReason.stop,
    sdk.StopReason.modelContextWindowExceeded => FinishReason.length,
    sdk.StopReason.refusal => FinishReason.blocked,
    null => FinishReason.unknown,
  };
}

/// Maps Anthropic [sdk.Usage] to Genkit [GenerationUsage].
GenerationUsage mapUsage(sdk.Usage? usage) {
  if (usage == null) {
    return GenerationUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0);
  }
  return GenerationUsage(
    inputTokens: usage.inputTokens.toDouble(),
    outputTokens: usage.outputTokens.toDouble(),
    totalTokens: (usage.inputTokens + usage.outputTokens).toDouble(),
  );
}
