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
import 'package:schemantic/schemantic.dart';

import 'model.dart';

final commonModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true, // Anthropic supports tool choice
    'systemRole': true,
    'constrained':
        true, // Supports JSON schema (via tool/constrained mode usually, or just prompt)
  },
);

class AnthropicPluginImpl extends GenkitPlugin {
  final String? apiKey;
  final Map<String, String>? headers;
  final String? baseUrl;
  sdk.AnthropicClient? _client;

  AnthropicPluginImpl({this.apiKey, this.headers, this.baseUrl});

  @override
  String get name => 'anthropic';

  sdk.AnthropicClient get client {
    if (_client != null) return _client!;
    if (apiKey != null) {
      return _client = sdk.AnthropicClient.withApiKey(
        apiKey!,
        defaultHeaders: headers,
        baseUrl: baseUrl,
      );
    }
    final config = sdk.AnthropicConfig.fromEnvironment();
    return _client = sdk.AnthropicClient(
      config: config.copyWith(defaultHeaders: headers, baseUrl: baseUrl),
    );
  }

  @override
  Future<List<ActionMetadata>> list() async {
    // Attempt to list models from the API if available, otherwise return manual list.
    try {
      final response = await client.models.list();
      return response.data
          .map(
            (m) => modelMetadata(
              'anthropic/${m.id}',
              customOptions: AnthropicOptions.$schema,
            ),
          )
          .toList();
    } catch (e, s) {
      // Fallback or empty if listing fails/not supported as expected
      print('Failed to list Anthropic models: $e\n$s');
      return [];
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType != 'model') return null;
    return _createModel(name);
  }

  Model _createModel(String modelName) {
    return _createModelWithClient(modelName, client);
  }

  Model _createModelWithClient(String modelName, sdk.AnthropicClient client) {
    return Model(
      name: 'anthropic/$modelName',
      customOptions: AnthropicOptions.$schema,
      metadata: {'model': commonModelInfo.toJson()},
      fn: (req, ctx) async {
        final options = req!.config == null
            ? AnthropicOptions()
            : AnthropicOptions.$schema.parse(req.config!);

        final requestClient = options.apiKey != null
            ? sdk.AnthropicClient.withApiKey(options.apiKey!)
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

    final thinking = _mapThinkingConfig(options.thinking);

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
    );
  }

  void close() {
    _client?.close();
  }
}

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
          input: req.input ?? {},
        ),
      ];
    } else if (p.isToolResponse) {
      final res = p.toolResponse!;
      return [
        sdk.InputContentBlock.toolResult(
          toolUseId: res.ref ?? '',
          content: [sdk.ToolResultContent.text(jsonEncode(res.output))],
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

List<sdk.InputContentBlock> _convertMediaFromJson(
  String url,
  String? contentType,
) {
  if (url.startsWith('data:')) {
    final commaIdx = url.indexOf(',');
    final base64Data = url.substring(commaIdx + 1);
    final mimeType = contentType ?? 'image/png';
    return [
      sdk.InputContentBlock.image(
        sdk.ImageSource.base64(
          data: base64Data,
          mediaType: _mapImageMediaType(mimeType),
        ),
      ),
    ];
  } else {
    return [sdk.InputContentBlock.image(sdk.ImageSource.url(url))];
  }
}

sdk.ImageMediaType _mapImageMediaType(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' || 'image/jpg' => sdk.ImageMediaType.jpeg,
    'image/gif' => sdk.ImageMediaType.gif,
    'image/webp' => sdk.ImageMediaType.webp,
    _ => sdk.ImageMediaType.png,
  };
}

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

sdk.ThinkingConfig? _mapThinkingConfig(ThinkingConfig? config) {
  if (config == null) return null;
  return switch (config.type ?? 'enabled') {
    'disabled' => sdk.ThinkingConfig.disabled(),
    'adaptive' => sdk.ThinkingConfig.adaptive(),
    // 1024 is the minimum budget_tokens required by the Anthropic API.
    _ => sdk.ThinkingConfig.enabled(budgetTokens: config.budgetTokens ?? 1024),
  };
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
