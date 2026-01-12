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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

part 'generate_test.schema.g.dart';

@GenkitSchema()
abstract class TestToolInputSchema {
  String get name;
}

void main() {
  group('generate', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should use toolChoice to select a tool', () async {
      const modelName = 'toolChoiceModel';
      const tool1Name = 'tool1';
      const tool2Name = 'tool2';
      var tool1Called = false;
      var tool2Called = false;

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          if (request.messages.last.role == Role.tool) {
            return ModelResponse.from(
              finishReason: FinishReason.stop,
              message: Message.from(
                role: Role.model,
                content: [TextPart.from(text: 'Done')],
              ),
            );
          }
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [
                ToolRequestPart.from(
                  toolRequest: ToolRequest.from(
                    name: tool1Name,
                    input: {'name': 'world'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: tool1Name,
        description: 'Tool 1',
        inputType: TestToolInputType,
        fn: (input, context) async {
          tool1Called = true;
          return 'tool 1 output';
        },
      );

      genkit.defineTool(
        name: tool2Name,
        description: 'Tool 2',
        inputType: TestToolInputType,
        fn: (input, context) async {
          tool2Called = true;
          return 'tool 2 output';
        },
      );

      await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Use a tool',
        tools: [tool1Name, tool2Name],
        toolChoice: tool1Name,
      );

      expect(tool1Called, isTrue);
      expect(tool2Called, isFalse);
    });

    test(
      'should return tool requests when returnToolRequests is true',
      () async {
        const modelName = 'returnToolRequestsModel';
        const toolName = 'testTool';
        var toolCalled = false;

        genkit.defineModel(
          name: modelName,
          fn: (request, context) async {
            return ModelResponse.from(
              finishReason: FinishReason.stop,
              message: Message.from(
                role: Role.model,
                content: [
                  ToolRequestPart.from(
                    toolRequest: ToolRequest.from(
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
          inputType: TestToolInputType,
          fn: (input, context) async {
            toolCalled = true;
            return 'tool output';
          },
        );

        final result = await genkit.generate(
          model: modelRef(modelName),
          prompt: 'Use a tool',
          tools: [toolName],
          returnToolRequests: true,
        );

        expect(toolCalled, isFalse);
        expect(result.toolRequests, isNotEmpty);
        expect(result.toolRequests.first.name, toolName);
      },
    );

    test('should throw an error when maxTurns is reached', () async {
      const modelName = 'maxTurnsModel';
      const toolName = 'testTool';

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [
                ToolRequestPart.from(
                  toolRequest: ToolRequest.from(
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
        inputType: TestToolInputType,
        fn: (input, context) async {
          return 'tool output';
        },
      );

      await expectLater(
        () => genkit.generate(
          model: modelRef(modelName),
          prompt: 'Use a tool',
          tools: [toolName],
          maxTurns: 2,
        ),
        throwsA(isA<GenkitException>()),
      );
    });
  });
}
