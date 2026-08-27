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

  sdk.AnthropicClient? _client;

  /// Creates an [AnthropicPluginImpl].
  AnthropicPluginImpl({
    this.apiKey,
    this.headers,
    this.baseUrl,
    this.httpClient,
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

          if (ctx.streamingRequested) {
            final stream = requestClient.messages.createStream(createRequest);
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
            final response = await requestClient.messages.create(createRequest);
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

    if (req.output?.schema != null) {
      final schema = Map<String, dynamic>.from(req.output!.schema!);
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

    if (req.toolChoice != null) {
      toolChoice = switch (req.toolChoice) {
        'auto' => sdk.ToolChoice.auto(),
        'any' => sdk.ToolChoice.any(),
        'none' => sdk.ToolChoice.none(),
        final name => sdk.ToolChoice.tool(name!),
      };
    }

    final thinking = _mapThinkingConfig(options.thinking, modelName);
    final outputConfig = _mapOutputConfig(options.outputConfig);

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

/// Metadata key carrying the opaque payload of a redacted thinking block.
const _redactedThinkingKey = 'redactedThinking';

/// Rebuilds the Anthropic thinking block a [ReasoningPart] came from.
///
/// `anthropic_sdk_dart` has no thinking input-block variant, so the wire JSON
/// is handed to [sdk.InputContentBlock.fromJson], which routes an unrecognized
/// type to a block that round-trips it verbatim.
///
/// Returns an empty list for reasoning this plugin cannot round-trip: Anthropic
/// rejects a thinking block whose signature is missing, so a part that never
/// carried one - hand-built history, or reasoning from another provider - is
/// dropped rather than turned into a request the API will reject.
List<sdk.InputContentBlock> _toAnthropicThinkingBlocks(Part p) {
  final metadata = p.metadata;

  final redacted = metadata?[_redactedThinkingKey];
  if (redacted is String && redacted.isNotEmpty) {
    return [
      sdk.InputContentBlock.fromJson({
        'type': 'redacted_thinking',
        'data': redacted,
      }),
    ];
  }

  final signature = metadata?[_thoughtSignatureKey];
  if (signature is! String || signature.isEmpty) return const [];

  return [
    sdk.InputContentBlock.fromJson({
      'type': 'thinking',
      'thinking': p.reasoning ?? '',
      'signature': signature,
    }),
  ];
}

/// Converts a Genkit [Message] to an Anthropic [sdk.InputMessage].
sdk.InputMessage toAnthropicMessage(Message m) {
  final isUser = m.role == Role.user || m.role == Role.tool;

  final blocks = m.content.expand<sdk.InputContentBlock>((p) {
    if (p.isReasoning) {
      // Anthropic accepts thinking blocks only on assistant turns, and only
      // when echoed back complete and unmodified.
      return isUser ? const [] : _toAnthropicThinkingBlocks(p);
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
          // dropped. The reasoning text is necessarily empty.
          sdk.RedactedThinkingBlock(:final data) => ReasoningPart(
            reasoning: '',
            metadata: {_redactedThinkingKey: data},
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

sdk.ThinkingConfig? _mapThinkingConfig(
  ThinkingConfig? config,
  String modelName,
) {
  if (config == null) return null;

  final type =
      config.type ?? knownClaudeModelFor(modelName)?.defaultThinkingMode.name;
  if (type == null) {
    throw GenkitException(
      'Set thinking.type explicitly for unknown Anthropic model "$modelName".',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

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

sdk.OutputConfig? _mapOutputConfig(AnthropicOutputConfig? config) {
  final effort = config?.effort;
  if (effort == null) return null;

  return sdk.OutputConfig(
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
