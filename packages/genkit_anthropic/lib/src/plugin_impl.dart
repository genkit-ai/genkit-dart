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
final commonModelInfo = ModelInfo(supports: baseClaudeSupports);

/// Beta features requested when a request resolves to the beta API surface.
///
/// Sent as the `anthropic-beta` header. Limited to the features this plugin
/// actually exposes - `effort` via [AnthropicOutputConfig], and structured
/// outputs via an output schema.
///
/// Deliberately shorter than the Genkit JS default list, which also carries
/// `files-api-2025-04-14` and `task-budgets-2026-03-13`. This plugin never
/// calls `/v1/files` and exposes no task budget, so those names buy nothing -
/// and Anthropic 400s on an unrecognised beta rather than ignoring it, so a
/// name kept past its retirement fails every `apiVersion: 'beta'` request
/// until the next release. A caller who needs one can pass it explicitly
/// through `AnthropicOptions.betas`, which replaces this list.
const defaultAnthropicBetas = <String>[
  'effort-2025-11-24',
  'structured-outputs-2025-11-13',
];

/// Resolves whether a request runs against the beta API surface.
///
/// The request's own `apiVersion` wins, then the plugin default, else stable.
///
/// Throws on anything but `'beta'` or `'stable'`. Silently reading `'Beta'`
/// as stable would drop the beta header and the features that depend on it,
/// with nothing to point at.
@visibleForTesting
bool resolveBetaEnabled(String? requestApiVersion, String? pluginApiVersion) {
  final selected = requestApiVersion ?? pluginApiVersion;
  if (selected == null) return false;
  if (selected != 'beta' && selected != 'stable') {
    throw GenkitException(
      'Invalid apiVersion "$selected". Expected "beta" or "stable".',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
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

  /// Returns the capability metadata for [modelName], matching by exact name
  /// first and then by dated-snapshot alias, falling back to [commonModelInfo]
  /// for names not in [knownModels].
  ModelInfo modelInfoFor(String modelName) =>
      knownModels[modelName] ??
      knownModels[_aliasOf(modelName)] ??
      commonModelInfo;

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
      final curated = knownModels.entries
          .where((entry) => !coveredAliases.contains(entry.key))
          .map((entry) => _curatedMetadata(entry.key, entry.value));

      return [...discovered, ...curated];
    } catch (e, s) {
      // The sibling plugins rethrow here; this plugin degrades gracefully
      // instead, advertising the curated catalog so known models stay listable
      // when discovery is unavailable (e.g. offline).
      _logger.warning('Failed to list Anthropic models: $e', e, s);
      return [
        for (final entry in knownModels.entries)
          _curatedMetadata(entry.key, entry.value),
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
          final createRequest = _buildCreateRequest(req, modelName, options);
          // Empty on the stable surface, which suppresses the header entirely.
          // `betas: []` is an explicit "send none", distinct from omitting
          // the field, which takes the defaults.
          final betas = resolveBetaEnabled(options.apiVersion, apiVersion)
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
            status = StatusCodes.fromHttpStatus(e.statusCode);
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
    AnthropicOptions options,
  ) {
    final systemMessage = req.messages
        .where((m) => m.role == Role.system)
        .firstOrNull;

    final system = systemMessage != null
        ? convertSystemMessage(systemMessage)
        : null;

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

      if (_supportsNativeStructuredOutput(modelName)) {
        // Native structured output needs no forced tool, so it composes with
        // manual thinking - unlike the fallback below. The schema goes over
        // as-authored; adding a `type` here would collide with a `$ref` root.
        outputFormat = sdk.JsonOutputFormat(schema: _toAnthropicSchema(schema));
      } else {
        // Older and uncurated models are not on Anthropic's Structured Outputs
        // list, so the schema is served by a tool the model is forced to call.
        _assertToolOutputAllowed(req, modelName, options);
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
        toolChoice = sdk.ToolChoice.tool(toolName);
      }
    }

    // A caller-supplied choice must not silently unforce `return_output`; that
    // would leave the model free to answer without producing the schema.
    if (req.toolChoice != null && toolChoice == null) {
      toolChoice = switch (req.toolChoice) {
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
      // Anthropic rejects a choice with nothing to choose from - "tool_choice.
      // any may only be specified while providing tools". Reachable since an
      // output schema stopped always appending `return_output`: a caller's
      // toolChoice can now outlive the tools it referred to.
      toolChoice: tools.isNotEmpty ? toolChoice : null,
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

/// Converts a Genkit [Message] to an Anthropic [sdk.InputMessage].
sdk.InputMessage toAnthropicMessage(Message m) {
  final isUser = m.role == Role.user || m.role == Role.tool;

  final blocks = m.content.expand<sdk.InputContentBlock>((p) {
    if (p.isText) {
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
            metadata: {'signature': signature},
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

/// Whether [modelName] is on Anthropic's Structured Outputs list.
///
/// An uncurated name is assumed to support it. Every model Anthropic
/// currently lists does, and assuming otherwise sent a newly released model
/// down the tool fallback, which fails on exactly the models that do not
/// accept a forced tool choice:
///
///     400 tool_choice: type "tool" and "any" are not supported for this model
///
/// So the fallback is opt-out now: a curated entry sets `structuredOutputs:
/// false` to claim it, rather than every unknown name inheriting it.
bool _supportsNativeStructuredOutput(String modelName) =>
    knownClaudeModelFor(modelName)?.structuredOutputs ?? true;

/// Keywords whose value is a single nested schema.
const _schemaValuedKeywords = {
  'items',
  'additionalItems',
  'contains',
  'not',
  'if',
  'then',
  'else',
  'propertyNames',
};

/// Keywords whose value is a list of schemas.
const _schemaListKeywords = {'allOf', 'anyOf', 'oneOf', 'prefixItems'};

/// Keywords whose value maps names to schemas.
const _schemaMapKeywords = {
  'properties',
  r'$defs',
  'definitions',
  'patternProperties',
};

/// Validation keywords Anthropic's structured-output schema rejects.
///
/// `output_config.format` validates the schema strictly and 400s on these -
/// "For 'integer' type, properties maximum, minimum are not supported". The
/// tool fallback never validated, which is why they rode through unnoticed.
/// Genkit's own generator emits them from `@IntegerField(minimum:)` and
/// friends, so ordinary annotated types hit this.
///
/// Dropped rather than translated: they constrain values, and losing them
/// costs a validation the model was never guaranteed to honour anyway.
const _unsupportedValidationKeywords = {
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'multipleOf',
  'minLength',
  'maxLength',
  'pattern',
  'minItems',
  'maxItems',
  'uniqueItems',
  'minProperties',
  'maxProperties',
};

/// Whether [type] denotes an object, including the nullable `["object",
/// "null"]` spelling schemantic emits for an optional object field.
bool _isObjectType(Object? type) =>
    type == 'object' || (type is List && type.contains('object'));

/// Rewrites a Genkit JSON schema into the shape Anthropic accepts.
///
/// Anthropic rejects `$schema`, rejects the validation keywords above, and
/// requires `additionalProperties: false` on every object, including ones
/// nested under `$defs`.
///
/// Recursion follows JSON Schema structure rather than descending into every
/// map it meets. A `properties` map is not itself a schema - descending into
/// it applied the object inference and the closed marker to the map of field
/// names, which corrupted any schema with a field called `type`, `properties`
/// or `required`.
Map<String, dynamic> _toAnthropicSchema(Map<String, dynamic> schema) {
  final out = <String, dynamic>{};
  for (final entry in schema.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key == r'$schema') continue;
    if (_unsupportedValidationKeywords.contains(key)) continue;

    if (_schemaMapKeywords.contains(key) && value is Map) {
      out[key] = {
        for (final field in value.entries)
          field.key.toString(): _asSchema(field.value),
      };
    } else if (_schemaListKeywords.contains(key) && value is List) {
      out[key] = value.map(_asSchema).toList();
    } else if (_schemaValuedKeywords.contains(key)) {
      // `items` may be a list of schemas in older drafts.
      out[key] = value is List
          ? value.map(_asSchema).toList()
          : _asSchema(value);
    } else if (key == 'additionalProperties' && value is Map) {
      out[key] = _asSchema(value);
    } else {
      out[key] = value;
    }
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
  if (_isObjectType(out['type'])) {
    out['additionalProperties'] = false;
  }
  return out;
}

/// Normalises [value] when it is a schema, and leaves anything else alone.
Object? _asSchema(Object? value) => switch (value) {
  final Map<String, dynamic> map => _toAnthropicSchema(map),
  final Map map => _toAnthropicSchema(map.cast<String, dynamic>()),
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
