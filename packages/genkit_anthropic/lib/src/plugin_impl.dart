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
import 'package:genkit/genkit.dart';

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
  sdk.AnthropicClient? _client;

  AnthropicPluginImpl({this.apiKey});

  @override
  String get name => 'anthropic';

  sdk.AnthropicClient get client {
    if (_client != null) return _client!;
    return _client = sdk.AnthropicClient(
      apiKey: apiKey ?? String.fromEnvironment('ANTHROPIC_API_KEY'),
    );
  }

  @override
  Future<List<ActionMetadata>> list() async {
    // Attempt to list models from the API if available, otherwise return manual list.
    // The SDK currently supports listing models via `client.listModels()`.
    try {
      final response = await client.listModels();
      return response.data
          .map(
            (m) => modelMetadata(
              'anthropic/${m.displayName}',
              customOptions: AnthropicOptions.$schema,
            ),
          )
          .toList();
    } catch (_) {
      // Fallback or empty if listing fails/not supported as expected
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
            ? sdk.AnthropicClient(apiKey: options.apiKey!)
            : client;

        try {
          final systemMessage = req.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;

          // Anthropic system prompt
          final system = systemMessage != null
              ? convertSystemMessage(systemMessage)
              : null;

          final messages = req.messages
              .where((m) => m.role != Role.system)
              .map(toAnthropicMessage)
              .toList();

          final tools =
              req.tools?.map(toAnthropicTool).toList() ?? <sdk.Tool>[];

          // Determine tool choice
          sdk.ToolChoice? toolChoice;

          // Handle Structured Output via Tool
          if (req.output?.schema != null) {
            final schema = Map<String, dynamic>.from(req.output!.schema!);
            if (!schema.containsKey('type')) {
              schema['type'] = 'object';
            }
            const toolName = 'return_output';
            tools.add(
              sdk.Tool.custom(
                name: toolName,
                description: 'Return the structured output.',
                inputSchema: schema,
              ),
            );
            toolChoice = sdk.ToolChoice(
              type: sdk.ToolChoiceType.tool,
              name: toolName,
            );
          }

          if (req.toolChoice != null) {
            if (req.toolChoice == 'auto') {
              toolChoice = const sdk.ToolChoice(type: sdk.ToolChoiceType.auto);
            } else if (req.toolChoice == 'any') {
              toolChoice = const sdk.ToolChoice(type: sdk.ToolChoiceType.any);
            } else if (req.toolChoice != 'none') {
              // specific tool
              toolChoice = sdk.ToolChoice(
                type: sdk.ToolChoiceType.tool,
                name: req.toolChoice!,
              );
            }
          }

          // Model ID handling
          final createRequest = sdk.CreateMessageRequest(
            model: sdk.Model.modelId(modelName),
            messages: messages,
            system: system,
            maxTokens: options.maxTokens ?? 4096,
            temperature: options.temperature,
            topP: options.topP,
            topK: options.topK,
            stopSequences: options.stopSequences,
            tools: tools,
            toolChoice: toolChoice,
            thinking: options.thinking != null
                ? sdk.ThinkingConfig.enabled(
                    type: sdk.ThinkingConfigEnabledType.enabled,
                    budgetTokens: options.thinking!.budgetTokens,
                  )
                : null,
          );

          if (ctx.streamingRequested) {
            final stream = requestClient.createMessageStream(
              request: createRequest,
            );
            final chunks = <sdk.MessageStreamEvent>[];
            await for (final event in stream) {
              chunks.add(event);
              event.map(
                messageStart: (_) {},
                messageDelta: (_) {},
                messageStop: (_) {},
                contentBlockStart: (_) {},
                contentBlockDelta: (e) {
                  final index = e.index;
                  e.delta.map(
                    textDelta: (d) {
                      ctx.sendChunk(
                        ModelResponseChunk(
                          index: index,
                          content: [TextPart(text: d.text)],
                        ),
                      );
                    },
                    thinking: (d) {
                      ctx.sendChunk(
                        ModelResponseChunk(
                          index: index,
                          content: [ReasoningPart(reasoning: d.thinking)],
                        ),
                      );
                    },
                    inputJsonDelta: (_) {},
                    signature: (_) {},
                    citations: (_) {},
                  );
                },
                contentBlockStop: (_) {},
                ping: (_) {},
                error: (e) {
                  throw Exception(e.error.message);
                },
              );
            }
            final message = await _aggregateStream(chunks);
            return ModelResponse(
              finishReason: _mapFinishReason(message.stopReason),
              message: fromAnthropicMessage(message),
              usage: _mapUsage(message.usage),
            );
          } else {
            final response = await requestClient.createMessage(
              request: createRequest,
            );
            return ModelResponse(
              finishReason: _mapFinishReason(response.stopReason),
              message: fromAnthropicMessage(response),
              usage: _mapUsage(response.usage),
              raw: response.toJson(),
            );
          }
        } finally {
          if (options.apiKey != null) {
            requestClient.endSession();
          }
        }
      },
    );
  }

  void close() {
    _client?.endSession();
  }
}

sdk.CreateMessageRequestSystem? convertSystemMessage(Message m) {
  final text = m.content.whereType<TextPart>().map((p) => p.text).join('\n');
  if (text.isEmpty) return null;
  return sdk.CreateMessageRequestSystem.text(text);
}

sdk.Message toAnthropicMessage(Message m) {
  final role = (m.role == Role.user || m.role == Role.tool)
      ? sdk.MessageRole.user
      : sdk.MessageRole.assistant;

  final content = sdk.MessageContent.blocks(
    m.content.expand((p) {
      final map = p.toJson();
      if (map.containsKey('text')) {
        return [sdk.Block.text(text: map['text'] as String)];
      } else if (map.containsKey('toolRequest')) {
        final req = map['toolRequest'] as Map<String, dynamic>;
        return [
          sdk.Block.toolUse(
            id: req['ref'],
            name: req['name'],
            input: req['input'],
            type: 'tool_use',
          ),
        ];
      } else if (map.containsKey('toolResponse')) {
        final res = map['toolResponse'] as Map<String, dynamic>;
        return [
          sdk.Block.toolResult(
            toolUseId: res['ref'],
            content: sdk.ToolResultBlockContent.text(jsonEncode(res['output'])),
          ),
        ];
      } else if (map.containsKey('media')) {
        // TODO: Handle media types.
        return <sdk.Block>[];
      }
      return <sdk.Block>[];
    }).toList(),
  );

  return sdk.Message(role: role, content: content);
}

sdk.Tool toAnthropicTool(ToolDefinition t) {
  final schema = Map<String, dynamic>.from(t.inputSchema ?? {});
  if (!schema.containsKey('type')) {
    schema['type'] = 'object';
  }
  return sdk.Tool.custom(
    name: t.name,
    description: t.description,
    inputSchema: schema,
  );
}

Message fromAnthropicMessage(sdk.Message m) {
  final content = m.content.blocks
      .map((block) {
        return block.map(
          text: (b) => TextPart(text: b.text),
          toolUse: (b) {
            if (b.name == 'return_output') {
              var input = b.input;
              if (input.keys.length == 1) {
                if (input.containsKey('output') && input['output'] is Map) {
                  input = input['output'] as Map<String, dynamic>;
                } else if (input.containsKey('\$output') &&
                    input['\$output'] is Map) {
                  input = input['\$output'] as Map<String, dynamic>;
                }
              }
              return TextPart(text: jsonEncode(input));
            }
            return ToolRequestPart(
              toolRequest: ToolRequest(ref: b.id, name: b.name, input: b.input),
            );
          },
          toolResult: (_) => TextPart(text: ''),
          thinking: (b) => ReasoningPart(
            reasoning: b.thinking,
            metadata: {'signature': b.signature},
          ),
          image: (_) => TextPart(text: ''),
          redactedThinking: (_) => TextPart(text: ''),
          codeExecutionToolResult: (_) => TextPart(text: ''),
          containerUpload: (_) => TextPart(text: ''),
          document: (_) => TextPart(text: ''),
          mCPToolResult: (_) => TextPart(text: ''),
          mCPToolUse: (_) => TextPart(text: ''),
          searchResult: (_) => TextPart(text: ''),
          serverToolUse: (_) => TextPart(text: ''),
          webSearchToolResult: (_) => TextPart(text: ''),
        );
      })
      .where((p) => p is! TextPart || p.text.isNotEmpty)
      .toList();

  return Message(role: Role.model, content: content);
}

Future<sdk.Message> _aggregateStream(
  List<sdk.MessageStreamEvent> chunks,
) async {
  String? id;
  String? model;
  sdk.MessageRole? role;
  sdk.StopReason? stopReason;
  String? stopSequence;
  final usageBuilder = _MutableUsage();
  final blockBuilders = <int, _BlockBuilder>{};

  for (final event in chunks) {
    event.map(
      messageStart: (e) {
        id = e.message.id;
        model = e.message.model;
        role = e.message.role;
        usageBuilder.inputTokens += e.message.usage?.inputTokens.toInt() ?? 0;
        usageBuilder.outputTokens += e.message.usage?.outputTokens.toInt() ?? 0;
      },
      messageDelta: (e) {
        stopReason = e.delta.stopReason;
        stopSequence = e.delta.stopSequence;
        usageBuilder.outputTokens += e.usage.outputTokens.toInt();
      },
      messageStop: (_) {},
      contentBlockStart: (e) {
        final block = e.contentBlock;
        block.map(
          text: (b) {
            blockBuilders[e.index] = _TextBlockBuilder(b.text);
          },
          toolUse: (b) {
            blockBuilders[e.index] = _ToolUseBlockBuilder(
              b.id,
              b.name,
              b.input,
            );
          },
          thinking: (b) {
            blockBuilders[e.index] = _ThinkingBlockBuilder(
              b.thinking,
              b.signature ?? '',
            );
          },
          toolResult: (_) {},
          image: (_) {},
          redactedThinking: (_) {},
          codeExecutionToolResult: (_) {},
          containerUpload: (_) {},
          document: (_) {},
          mCPToolResult: (_) {},
          mCPToolUse: (_) {},
          searchResult: (_) {},
          serverToolUse: (_) {},
          webSearchToolResult: (_) {},
        );
      },
      contentBlockDelta: (e) {
        final builder = blockBuilders[e.index];
        e.delta.map(
          textDelta: (d) {
            if (builder is _TextBlockBuilder) {
              builder.buffer.write(d.text);
            }
          },
          inputJsonDelta: (d) {
            if (builder is _ToolUseBlockBuilder && d.partialJson != null) {
              builder.jsonBuffer.write(d.partialJson);
            }
          },
          thinking: (d) {
            if (builder is _ThinkingBlockBuilder) {
              builder.buffer.write(d.thinking);
            }
          },
          signature: (d) {
            if (builder is _ThinkingBlockBuilder) {
              builder.signatureBuffer.write(d.signature);
            }
          },
          citations: (_) {},
        );
      },
      contentBlockStop: (_) {},
      ping: (_) {},
      error: (_) {},
    );
  }

  final blocks = blockBuilders.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  return sdk.Message(
    id: id ?? '',
    role: role ?? sdk.MessageRole.assistant,
    content: sdk.MessageContent.blocks(
      blocks.map((e) => e.value.build()).toList(),
    ),
    model: model ?? '',
    stopReason: stopReason,
    stopSequence: stopSequence,
    usage: usageBuilder.toUsage(),
  );
}

class _MutableUsage {
  int inputTokens = 0;
  int outputTokens = 0;
  sdk.Usage toUsage() =>
      sdk.Usage(inputTokens: inputTokens, outputTokens: outputTokens);
}

abstract class _BlockBuilder {
  sdk.Block build();
}

class _TextBlockBuilder extends _BlockBuilder {
  final StringBuffer buffer;
  _TextBlockBuilder(String initial) : buffer = StringBuffer(initial);
  @override
  sdk.Block build() => sdk.Block.text(text: buffer.toString());
}

class _ToolUseBlockBuilder extends _BlockBuilder {
  final String id;
  final String name;
  final StringBuffer jsonBuffer = StringBuffer();
  _ToolUseBlockBuilder(this.id, this.name, Map<String, dynamic> initial) {
    if (initial.isNotEmpty) jsonBuffer.write(jsonEncode(initial));
  }
  @override
  sdk.Block build() {
    final str = jsonBuffer.toString();
    final input = str.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(str) as Map<String, dynamic>;
    return sdk.Block.toolUse(
      id: id,
      name: name,
      input: input,
      type: 'tool_use',
    );
  }
}

class _ThinkingBlockBuilder extends _BlockBuilder {
  final StringBuffer buffer;
  final StringBuffer signatureBuffer;
  _ThinkingBlockBuilder(String initial, String initialSignature)
    : buffer = StringBuffer(initial),
      signatureBuffer = StringBuffer(initialSignature);
  @override
  sdk.Block build() => sdk.Block.thinking(
    type: sdk.ThinkingBlockType.thinking,
    thinking: buffer.toString(),
    signature: signatureBuffer.toString(),
  );
}

FinishReason _mapFinishReason(sdk.StopReason? reason) {
  return switch (reason) {
    sdk.StopReason.endTurn => FinishReason.stop,
    sdk.StopReason.maxTokens => FinishReason.length,
    sdk.StopReason.stopSequence => FinishReason.stop,
    sdk.StopReason.toolUse => FinishReason.stop,
    null => FinishReason.unknown,
    _ => FinishReason(reason.toString().split('.').last),
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
