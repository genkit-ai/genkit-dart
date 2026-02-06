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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'genkit_test.g.dart';

@Schematic()
abstract class $TestCustomOptions {
  String get customField;
}

@Schematic()
abstract class $TestToolInput {
  String get name;
}

void main() {
  group('Genkit', () {
    const reflectionPort = 3111;
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, reflectionPort: reflectionPort);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should start reflection server in dev mode', () async {
      genkit = Genkit(isDevEnv: true, reflectionPort: reflectionPort);
      final response = await http.get(
        Uri.parse('http://localhost:$reflectionPort/api/__health'),
      );
      expect(response.statusCode, 200);
    });

    test('should not start reflection server in non-dev mode', () async {
      await expectLater(
        () => http.get(
          Uri.parse('http://localhost:$reflectionPort/api/__health'),
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('should define and register a flow', () async {
      const flowName = 'testFlow';

      final flow = genkit.defineFlow(
        name: flowName,
        function: (String input, context) async => 'output: $input',
      );

      // Check if the returned flow is correct
      expect(flow, isA<Flow>());
      expect(flow.name, flowName);

      // Check if the flow is registered in the registry
      final retrievedAction = await genkit.registry.lookUpFlow(flowName);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, flowName);

      // Check if the returned flow and the registered flow are the same instance
      expect(identical(flow, retrievedAction), isTrue);
    });

    test('should define and register a tool', () async {
      const toolName = 'testTool';
      const toolDescription = 'A test tool.';

      final tool = genkit.defineTool(
        name: toolName,
        description: toolDescription,
        function: (String input, context) async => 'output: $input',
      );

      // Check if the returned tool is correct
      expect(tool, isA<Tool>());
      expect(tool.name, toolName);
      expect(tool.description, toolDescription);

      // Check if the tool is registered in the registry
      final retrievedAction = await genkit.registry.lookupTool(toolName);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, toolName);
      expect(retrievedAction.description, toolDescription);

      // Check if the returned tool and the registered tool are the same instance
      expect(identical(tool, retrievedAction), isTrue);
    });

    test('should call generate action with correct parameters', () async {
      const modelName = 'testModel';
      const prompt = 'test prompt';

      genkit.defineModel(
        name: modelName,
        function: (request, context) async {
          final response = ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                TextPart(
                  text:
                      'config:${request.config} req:${request.messages.map((m) => m.content.map((c) => c.toJson().toString())).join('\n')}',
                ),
              ],
            ),
          );
          return response;
        },
      );

      final result = await genkit.generate(
        model: modelRef(modelName, customOptions: TestCustomOptions.$schema),
        prompt: prompt,
        config: TestCustomOptions(customField: 'yo'),
      );
      expect(result.text, 'config:{customField: yo} req:({text: test prompt})');
    });

    test('should execute a tool and return the result', () async {
      const modelName = 'toolModel';
      const toolName = 'testTool';

      genkit.defineModel(
        name: modelName,
        function: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  TextPart(
                    text:
                        'Tool output: ${request.messages.last.content.firstWhere((p) => p.isToolResponse).toolResponse!.output}',
                  ),
                ],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: toolName,
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: toolName,
        description: 'A test tool',
        inputSchema: TestToolInput.$schema,
        function: (input, context) async {
          return 'Hello, ${input.name}!';
        },
      );

      final result = await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Use the test tool',
        toolNames: [toolName],
      );

      expect(result.text, 'Tool output: Hello, world!');
    });

    test('should handle streaming with onChunk callback', () async {
      const modelName = 'streamingModel';
      const prompt = 'streaming prompt';

      genkit.defineModel(
        name: modelName,
        function: (request, context) async {
          final chunks = [
            ModelResponseChunk(index: 0, content: [TextPart(text: 'chunk1')]),
            ModelResponseChunk(index: 0, content: [TextPart(text: 'chunk2')]),
          ];

          for (final chunk in chunks) {
            context.sendChunk(chunk);
          }

          final response = ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'final response')],
            ),
          );
          return response;
        },
      );

      final receivedChunks = <GenerateResponseChunk>[];
      final result = await genkit.generate(
        model: modelRef(modelName),
        prompt: prompt,
        onChunk: receivedChunks.add,
      );

      expect(receivedChunks.length, 2);
      expect(receivedChunks[0].text, 'chunk1');
      expect(receivedChunks[1].text, 'chunk2');
      expect(result.text, 'final response');
    });

    test('should handle streaming with generateStream', () async {
      const modelName = 'streamingModel';
      const prompt = 'streaming prompt';

      genkit.defineModel(
        name: modelName,
        function: (request, context) async {
          final chunks = [
            ModelResponseChunk(index: 0, content: [TextPart(text: 'chunk1')]),
            ModelResponseChunk(index: 0, content: [TextPart(text: 'chunk2')]),
          ];

          for (final chunk in chunks) {
            context.sendChunk(chunk);
          }

          final response = ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'final response')],
            ),
          );
          return response;
        },
      );

      final stream = genkit.generateStream(
        model: modelRef(modelName),
        prompt: prompt,
      );

      final receivedChunks = <GenerateResponseChunk>[];
      await for (final chunk in stream) {
        receivedChunks.add(chunk);
      }

      final result = await stream.onResult;

      expect(receivedChunks.length, 2);
      expect(receivedChunks[0].text, 'chunk1');
      expect(receivedChunks[1].text, 'chunk2');
      expect(result.text, 'final response');
    });
  });
}
