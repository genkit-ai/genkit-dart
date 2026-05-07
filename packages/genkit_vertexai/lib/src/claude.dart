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

import 'dart:convert';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as sdk;
import 'package:genkit/plugin.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart' as anthropic;
import 'package:genkit_google_genai/common.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

const _vertexAnthropicVersion = 'vertex-2023-10-16';
const _defaultClaudeMaxTokens = 4096;
const _structuredOutputToolName = '__genkit_output__';

final claudeModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

bool isClaudeModel(String name) => name.startsWith('claude-');

ActionMetadata<dynamic, dynamic, dynamic, dynamic> claudeModelMetadata(
  String pluginName,
  String modelName,
) {
  return modelMetadata(
    '$pluginName/$modelName',
    customOptions: anthropic.AnthropicOptions.$schema,
    modelInfo: claudeModelInfo,
  );
}

class VertexClaudeModelFactory {
  VertexClaudeModelFactory({
    required this.pluginName,
    required this.getApiClient,
    required this.resolvedProjectId,
    required this.resolvedLocation,
    required this.shouldCloseClient,
    required this.handleException,
  });

  final String pluginName;
  final Future<GenerativeLanguageBaseClient> Function() getApiClient;
  final String Function() resolvedProjectId;
  final String Function() resolvedLocation;
  final bool Function() shouldCloseClient;
  final GenkitException Function(Object e, StackTrace stack) handleException;

  Model createModel(String modelName) {
    return Model(
      name: '$pluginName/$modelName',
      customOptions: anthropic.AnthropicOptions.$schema,
      metadata: {'model': claudeModelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = modelRequest.config == null
            ? anthropic.AnthropicOptions()
            : anthropic.AnthropicOptions.$schema.parse(modelRequest.config!);

        if (options.apiKey != null) {
          throw ArgumentError(
            'apiKey is not supported for Vertex AI Claude models. '
            'Use Application Default Credentials instead.',
          );
        }

        final service = await getApiClient();

        try {
          final createRequest = _buildCreateRequest(
            modelRequest,
            modelName,
            options,
          );

          if (ctx.streamingRequested) {
            final stream = _streamMessage(service, modelName, createRequest);
            final accumulator = sdk.MessageStreamAccumulator();
            await for (final event in stream) {
              accumulator.add(event);
              _handleStreamEvent(event, ctx.sendChunk);
            }
            final message = accumulator.toMessage();
            return ModelResponse(
              finishReason: _mapFinishReason(message.stopReason),
              message: _fromMessage(message),
              usage: _mapUsage(message.usage),
            );
          }

          final response = await _createMessage(
            service,
            modelName,
            createRequest,
          );
          return ModelResponse(
            finishReason: _mapFinishReason(response.stopReason),
            message: _fromMessage(response),
            usage: _mapUsage(response.usage),
            raw: response.toJson(),
          );
        } catch (e, stack) {
          if (e is GenkitException) rethrow;
          throw handleException(e, stack);
        } finally {
          if (shouldCloseClient()) {
            service.client.close();
          }
        }
      },
    );
  }

  sdk.MessageCreateRequest _buildCreateRequest(
    ModelRequest req,
    String modelName,
    anthropic.AnthropicOptions options,
  ) {
    final systemMessage = req.messages
        .where((m) => m.role == Role.system)
        .firstOrNull;

    final system = systemMessage != null
        ? _convertSystemMessage(systemMessage)
        : null;

    final messages = req.messages
        .where((m) => m.role != Role.system)
        .map(_toMessage)
        .toList();

    final tools = req.tools?.map(_toTool).toList() ?? <sdk.ToolDefinition>[];

    sdk.ToolChoice? toolChoice;

    if (req.output?.schema != null) {
      final schema = Map<String, dynamic>.from(req.output!.schema!);
      if (!schema.containsKey('type')) {
        schema['type'] = 'object';
      }
      tools.add(
        sdk.ToolDefinition.custom(
          sdk.Tool(
            name: _structuredOutputToolName,
            description: 'Return the structured output.',
            inputSchema: sdk.InputSchema.fromJson(schema),
          ),
        ),
      );
      toolChoice = sdk.ToolChoice.tool(_structuredOutputToolName);
    }

    if (req.toolChoice != null) {
      toolChoice = switch (req.toolChoice) {
        'auto' => sdk.ToolChoice.auto(),
        'any' => sdk.ToolChoice.any(),
        'none' => sdk.ToolChoice.none(),
        final name => sdk.ToolChoice.tool(name!),
      };
    }

    return sdk.MessageCreateRequest(
      model: modelName,
      messages: messages,
      system: system,
      maxTokens: options.maxTokens ?? _defaultClaudeMaxTokens,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      stopSequences: options.stopSequences,
      tools: tools.isNotEmpty ? tools : null,
      toolChoice: toolChoice,
      thinking: _mapThinkingConfig(options.thinking),
    );
  }

  Future<sdk.Message> _createMessage(
    GenerativeLanguageBaseClient service,
    String modelName,
    sdk.MessageCreateRequest request,
  ) async {
    final response = await service.client.post(
      Uri.parse('${service.baseUrl}${_endpointPath(modelName)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_toVertexBody(request, stream: false)),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw _parseVertexError(response.statusCode, response.body);
    }

    return sdk.Message.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Stream<sdk.MessageStreamEvent> _streamMessage(
    GenerativeLanguageBaseClient service,
    String modelName,
    sdk.MessageCreateRequest request,
  ) async* {
    final httpRequest =
        http.Request(
            'POST',
            Uri.parse(
              '${service.baseUrl}${_endpointPath(modelName, stream: true)}',
            ),
          )
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(_toVertexBody(request, stream: true));

    final response = await service.client.send(httpRequest);

    if (!_isSuccessStatus(response.statusCode)) {
      final body = await response.stream.bytesToString();
      throw _parseVertexError(response.statusCode, body);
    }

    final parser = sdk.SseParser();
    await for (final event in parser.parse(response.stream)) {
      yield sdk.MessageStreamEvent.fromJson(event);
    }
  }

  String _endpointPath(String modelName, {bool stream = false}) {
    final safeProjectId = Uri.encodeComponent(resolvedProjectId());
    final safeLocation = Uri.encodeComponent(resolvedLocation());
    final safeModelName = Uri.encodeComponent(modelName);
    final method = stream ? 'streamRawPredict' : 'rawPredict';

    return 'v1/projects/$safeProjectId/locations/$safeLocation/'
        'publishers/anthropic/models/$safeModelName:$method';
  }

  Map<String, dynamic> _toVertexBody(
    sdk.MessageCreateRequest request, {
    required bool stream,
  }) {
    final body = request.toJson()
      ..remove('model')
      ..['anthropic_version'] = _vertexAnthropicVersion;

    if (stream) {
      body['stream'] = true;
    } else {
      body.remove('stream');
    }

    return body;
  }
}

sdk.SystemPrompt? _convertSystemMessage(Message message) {
  final parts = <String>[];
  for (final part in message.content) {
    if (part.isText) {
      parts.add(part.text!);
    }
  }

  final text = parts.join('\n');
  if (text.isEmpty) {
    return null;
  }
  return sdk.SystemPrompt.text(text);
}

sdk.InputMessage _toMessage(Message message) {
  final isUser = message.role == Role.user || message.role == Role.tool;

  final blocks = message.content.expand<sdk.InputContentBlock>((part) {
    if (part.isText) {
      return [sdk.InputContentBlock.text(part.text!)];
    }
    if (part.isToolRequest) {
      final request = part.toolRequest!;
      return [
        sdk.InputContentBlock.toolUse(
          id: request.ref ?? '',
          name: request.name,
          input: request.input ?? {},
        ),
      ];
    }
    if (part.isToolResponse) {
      final response = part.toolResponse!;
      return [
        sdk.InputContentBlock.toolResult(
          toolUseId: response.ref ?? '',
          content: [
            sdk.ToolResultContent.text(_toolOutputText(response.output)),
          ],
        ),
      ];
    }
    if (part.isMedia) {
      final media = part.media!;
      return _convertMedia(media.url, media.contentType);
    }
    return <sdk.InputContentBlock>[];
  }).toList();

  return isUser
      ? sdk.InputMessage.userBlocks(blocks)
      : sdk.InputMessage.assistantBlocks(blocks);
}

List<sdk.InputContentBlock> _convertMedia(String url, String? contentType) {
  if (url.startsWith('data:')) {
    final commaIndex = url.indexOf(',');
    final base64Data = url.substring(commaIndex + 1);
    final mimeType = contentType ?? 'image/png';
    return [
      sdk.InputContentBlock.image(
        sdk.ImageSource.base64(
          data: base64Data,
          mediaType: _mapImageMediaType(mimeType),
        ),
      ),
    ];
  }

  throw GenkitException(
    'Vertex AI Claude models require media URLs to be data URLs with base64 '
    'image data.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

String _toolOutputText(dynamic output) {
  return output is String ? output : jsonEncode(output);
}

sdk.ImageMediaType _mapImageMediaType(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' || 'image/jpg' => sdk.ImageMediaType.jpeg,
    'image/gif' => sdk.ImageMediaType.gif,
    'image/webp' => sdk.ImageMediaType.webp,
    _ => sdk.ImageMediaType.png,
  };
}

sdk.ToolDefinition _toTool(ToolDefinition tool) {
  final rawSchema = Map<String, Object?>.from(tool.inputSchema ?? const {});
  final schema = Map<String, dynamic>.from(rawSchema.flatten());
  if (!schema.containsKey('type')) {
    schema['type'] = 'object';
  }

  return sdk.ToolDefinition.custom(
    sdk.Tool(
      name: tool.name,
      description: tool.description,
      inputSchema: sdk.InputSchema.fromJson(schema),
    ),
  );
}

Message _fromMessage(sdk.Message message) {
  final content = message.content
      .map(
        (block) => switch (block) {
          sdk.TextBlock(:final text) => TextPart(text: text),
          sdk.ToolUseBlock(:final id, :final name, :final input) =>
            name == _structuredOutputToolName
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
      .where((part) => part is! TextPart || part.text.isNotEmpty)
      .toList();

  return Message(role: Role.model, content: content);
}

Map<String, dynamic> _extractOutput(Map<String, dynamic> input) {
  if (input.keys.length == 1) {
    if (input.containsKey('output') && input['output'] is Map) {
      return input['output'] as Map<String, dynamic>;
    }
    if (input.containsKey('\$output') && input['\$output'] is Map) {
      return input['\$output'] as Map<String, dynamic>;
    }
  }

  return input;
}

sdk.ThinkingConfig? _mapThinkingConfig(anthropic.ThinkingConfig? config) {
  if (config == null) {
    return null;
  }

  return switch (config.type ?? 'enabled') {
    'disabled' => sdk.ThinkingConfig.disabled(),
    'adaptive' => sdk.ThinkingConfig.adaptive(),
    _ => sdk.ThinkingConfig.enabled(budgetTokens: config.budgetTokens ?? 1024),
  };
}

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
          break;
      }
    case sdk.ErrorEvent(:final message):
      throw GenkitException(
        'Anthropic stream error: $message',
        status: StatusCodes.INTERNAL,
      );
    default:
      break;
  }
}

FinishReason _mapFinishReason(sdk.StopReason? reason) {
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

GenerationUsage _mapUsage(sdk.Usage? usage) {
  if (usage == null) {
    return GenerationUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0);
  }

  return GenerationUsage(
    inputTokens: usage.inputTokens.toDouble(),
    outputTokens: usage.outputTokens.toDouble(),
    totalTokens: (usage.inputTokens + usage.outputTokens).toDouble(),
  );
}

bool _isSuccessStatus(int statusCode) => statusCode >= 200 && statusCode < 300;

GenkitException _parseVertexError(int statusCode, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['error'] is Map<String, dynamic>) {
        final error = decoded['error'] as Map<String, dynamic>;
        final message = error['message'] as String? ?? 'Unknown error';
        return GenkitException(
          'Vertex AI error: $message',
          status: StatusCodes.fromHttpStatus(statusCode),
          details: body,
        );
      }
    }
  } catch (_) {}

  return GenkitException(
    'Vertex AI error: $body',
    status: StatusCodes.fromHttpStatus(statusCode),
    details: body,
  );
}
