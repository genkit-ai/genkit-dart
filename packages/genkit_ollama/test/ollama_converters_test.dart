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

import 'package:genkit/genkit.dart';
import 'package:genkit_ollama/genkit_ollama.dart';
import 'package:ollama_dart/ollama_dart.dart' as sdk;
import 'package:test/test.dart';

void main() {
  group('toOllamaMessages', () {
    test('maps a system message', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.system,
          content: [TextPart(text: 'be brief')],
        ),
      ]);
      expect(result, hasLength(1));
      expect(result.first.role, sdk.MessageRole.system);
      expect(result.first.content, 'be brief');
    });

    test('maps a user message with text', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ]);
      expect(result.first.role, sdk.MessageRole.user);
      expect(result.first.content, 'hello');
      expect(result.first.images, isNull);
    });

    test('throws on an unsupported part in a user message', () {
      expect(
        () => GenkitConverter.toOllamaMessages([
          Message(
            role: Role.user,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(name: 'x', output: 1),
              ),
            ],
          ),
        ]),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('strips data-URI prefix from image media', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'describe'),
            MediaPart(
              media: Media(
                url: 'data:image/png;base64,AAAA',
                contentType: 'image/png',
              ),
            ),
          ],
        ),
      ]);
      expect(result.first.images, ['AAAA']);
    });

    test('maps an assistant message with tool calls', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.model,
          content: [
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'getWeather',
                input: {'city': 'NY'},
              ),
            ),
          ],
        ),
      ]);
      final toolCalls = result.first.toolCalls;
      expect(toolCalls, hasLength(1));
      expect(toolCalls!.first.function?.name, 'getWeather');
      expect(toolCalls.first.function?.arguments, {'city': 'NY'});
    });

    test('expands a tool message with multiple responses', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.tool,
          content: [
            ToolResponsePart(
              toolResponse: ToolResponse(name: 'a', output: {'v': 1}),
            ),
            ToolResponsePart(
              toolResponse: ToolResponse(name: 'b', output: 'plain'),
            ),
          ],
        ),
      ]);
      expect(result, hasLength(2));
      expect(result[0].role, sdk.MessageRole.tool);
      expect(result[0].content, jsonEncode({'v': 1}));
      // String output is passed through verbatim, not double-encoded.
      expect(result[1].content, 'plain');
    });

    test('passes a bare (non-data-URI) image through unchanged', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.user,
          content: [
            MediaPart(
              media: Media(url: 'AAAA', contentType: 'image/png'),
            ),
          ],
        ),
      ]);
      expect(result.first.images, ['AAAA']);
    });

    test('keeps text and tool calls together in a model message', () {
      final result = GenkitConverter.toOllamaMessages([
        Message(
          role: Role.model,
          content: [
            TextPart(text: 'calling tool'),
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'getWeather',
                input: {'city': 'NY'},
              ),
            ),
          ],
        ),
      ]);
      expect(result.first.content, 'calling tool');
      expect(result.first.toolCalls, hasLength(1));
    });

    test('throws on a tool message with no tool responses', () {
      expect(
        () => GenkitConverter.toOllamaMessages([
          Message(
            role: Role.tool,
            content: [TextPart(text: 'oops')],
          ),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('toOllamaTool', () {
    test('wraps a tool definition', () {
      final tool = GenkitConverter.toOllamaTool(
        ToolDefinition(
          name: 'getWeather',
          description: 'gets weather',
          inputSchema: {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'},
            },
          },
        ),
      );
      expect(tool.function.name, 'getWeather');
      expect(tool.function.description, 'gets weather');
      expect(tool.function.parameters['type'], 'object');
    });

    test('defaults missing schema to an object schema', () {
      final tool = GenkitConverter.toOllamaTool(
        ToolDefinition(name: 't', description: 'd'),
      );
      expect(tool.function.parameters['type'], 'object');
    });

    test('injects a type when the schema omits it, keeping other keys', () {
      final tool = GenkitConverter.toOllamaTool(
        ToolDefinition(
          name: 't',
          description: 'd',
          inputSchema: {
            'properties': {
              'city': {'type': 'string'},
            },
          },
        ),
      );
      expect(tool.function.parameters['type'], 'object');
      expect(tool.function.parameters['properties'], isNotNull);
    });
  });

  group('fromOllamaMessage', () {
    test('maps text content', () {
      final msg = GenkitConverter.fromOllamaMessage(
        sdk.ChatResponseMessage(
          role: sdk.MessageRole.assistant,
          content: 'hi there',
        ),
      );
      expect(msg.role, Role.model);
      expect(msg.text, 'hi there');
    });

    test('yields an empty model message for null or empty content', () {
      final fromNull = GenkitConverter.fromOllamaMessage(null);
      expect(fromNull.role, Role.model);
      expect(fromNull.content, isEmpty);

      final fromEmpty = GenkitConverter.fromOllamaMessage(
        sdk.ChatResponseMessage(role: sdk.MessageRole.assistant, content: ''),
      );
      expect(fromEmpty.content, isEmpty);
    });

    test('maps tool calls into tool-request parts', () {
      final msg = GenkitConverter.fromOllamaMessage(
        sdk.ChatResponseMessage(
          role: sdk.MessageRole.assistant,
          content: '',
          toolCalls: [
            sdk.ToolCall(
              function: sdk.ToolCallFunction(
                name: 'getWeather',
                arguments: {'city': 'NY'},
              ),
            ),
          ],
        ),
      );
      final part = msg.content.single;
      expect(part.isToolRequest, isTrue);
      expect(part.toolRequest!.name, 'getWeather');
      expect(part.toolRequest!.input, {'city': 'NY'});
    });

    test('assigns a distinct ref to each tool call', () {
      final msg = GenkitConverter.fromOllamaMessage(
        sdk.ChatResponseMessage(
          role: sdk.MessageRole.assistant,
          content: '',
          toolCalls: [
            sdk.ToolCall(
              function: sdk.ToolCallFunction(name: 'get', arguments: {'i': 1}),
            ),
            sdk.ToolCall(
              function: sdk.ToolCallFunction(name: 'get', arguments: {'i': 2}),
            ),
          ],
        ),
      );
      final refs = msg.content.map((p) => p.toolRequest!.ref).toList();
      expect(refs, ['tool_call_0', 'tool_call_1']);
      // Same-named calls get distinct refs, avoiding tracking collisions.
      expect(refs.toSet(), hasLength(2));
    });
  });

  group('buildModelOptions', () {
    test('passes stop sequences as a list (not joined)', () {
      final options = GenkitConverter.buildModelOptions(
        OllamaChatOptions.$schema.parse({
          'stop': ['END', 'STOP'],
          'temperature': 0.5,
          'numCtx': 4096,
          'maxOutputTokens': 256,
        }),
      );
      expect(options!.stop, isA<sdk.StopList>());
      expect((options.stop as sdk.StopList).values, ['END', 'STOP']);
      expect(options.temperature, 0.5);
      expect(options.numCtx, 4096);
      expect(options.numPredict, 256);
    });

    test('omits stop when empty', () {
      final options = GenkitConverter.buildModelOptions(OllamaChatOptions());
      expect(options!.stop, isNull);
    });
  });

  group('buildResponseFormat', () {
    test('returns null without structured output', () {
      expect(GenkitConverter.buildResponseFormat(null), isNull);
      expect(
        GenkitConverter.buildResponseFormat(OutputConfig(format: 'text')),
        isNull,
      );
    });

    test('returns a JSON format for format=json without schema', () {
      final format = GenkitConverter.buildResponseFormat(
        OutputConfig(format: 'json'),
      );
      expect(format, isA<sdk.JsonFormat>());
    });

    test('returns a schema format when a schema is present', () {
      final format = GenkitConverter.buildResponseFormat(
        OutputConfig(
          format: 'json',
          schema: {
            'type': 'object',
            'properties': {
              'x': {'type': 'string'},
            },
          },
        ),
      );
      expect(format, isA<sdk.SchemaFormat>());
    });
  });

  group('buildKeepAlive', () {
    test('parses numeric values', () {
      expect(GenkitConverter.buildKeepAlive('0'), isA<sdk.KeepAliveNumber>());
      expect(GenkitConverter.buildKeepAlive('-1'), isA<sdk.KeepAliveNumber>());
    });

    test('parses duration strings', () {
      expect(
        GenkitConverter.buildKeepAlive('5m'),
        isA<sdk.KeepAliveDuration>(),
      );
    });

    test('returns null when unset', () {
      expect(GenkitConverter.buildKeepAlive(null), isNull);
    });
  });

  group('mapDoneReason', () {
    test('maps known reasons', () {
      expect(
        GenkitConverter.mapDoneReason(sdk.DoneReason.stop),
        FinishReason.stop,
      );
      expect(
        GenkitConverter.mapDoneReason(sdk.DoneReason.length),
        FinishReason.length,
      );
      expect(GenkitConverter.mapDoneReason(null), FinishReason.stop);
    });

    test('maps load/unload to other', () {
      expect(
        GenkitConverter.mapDoneReason(sdk.DoneReason.load),
        FinishReason.other,
      );
      expect(
        GenkitConverter.mapDoneReason(sdk.DoneReason.unload),
        FinishReason.other,
      );
    });
  });

  group('documentText', () {
    test('joins text parts', () {
      final text = GenkitConverter.documentText(
        DocumentData(
          content: [
            TextPart(text: 'foo'),
            TextPart(text: 'bar'),
          ],
        ),
      );
      expect(text, 'foobar');
    });
  });
}
