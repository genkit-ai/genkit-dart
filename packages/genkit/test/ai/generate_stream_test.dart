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

void main() {
  group('generate stream', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should increment index for chunks across turns', () async {
      const modelName = 'streamingParamsModel';
      const toolName = 'streamTool';

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          // If first turn, return tool request
          if (request.messages.length == 1) {
            context.sendChunk(
              ModelResponseChunk(content: [TextPart(text: 'Calling tool...')]),
            );
            context.sendChunk(
              ModelResponseChunk(
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

            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  TextPart(text: 'Calling tool...'),
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: toolName,
                      input: {'name': 'world'},
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Second turn (after tool)
            context.sendChunk(
              ModelResponseChunk(content: [TextPart(text: 'Done')]),
            );

            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done')],
              ),
            );
          }
        },
      );

      genkit.defineTool(
        name: toolName,
        description: 'A test tool',
        inputSchema: .map(.string(), .dynamicSchema()),
        fn: (input, context) async {
          return 'tool output';
        },
      );

      final chunks = <GenerateResponseChunk>[];
      await genkit.generate(
        model: modelRef(modelName),
        prompt: 'Start',
        toolNames: [toolName],
        onChunk: chunks.add,
      );

      // The tool-response message is streamed between turns (matching JS), so
      // the sequence is: 2 model chunks (turn 1), 1 tool-response chunk, then
      // 1 model chunk (turn 2).
      expect(chunks.length, 4);

      expect(
        chunks[0].index,
        0,
        reason: 'First chunk of first turn should be 0',
      );
      expect(
        chunks[1].index,
        0,
        reason: 'Second chunk of first turn should be 0',
      );
      expect(
        chunks[2].index,
        1,
        reason: 'Tool-response chunk should be 1',
      );
      expect(chunks[3].index, 2, reason: 'Chunk of second turn should be 2');
    });

    test(
      'should not increment messageIndex on first chunk of a turn even if role differs',
      () async {
        const modelName = 'multiTurnRoleModel';
        const toolName = 'dummyTool';

        genkit.defineModel(
          name: modelName,
          fn: (request, context) async {
            if (request.messages.length == 1) {
              context.sendChunk(
                ModelResponseChunk(
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(name: toolName, input: {}),
                    ),
                  ],
                ),
              );

              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(name: toolName, input: {}),
                    ),
                  ],
                ),
              );
            } else {
              // Second turn: messageIndex should be 2.
              // If we send a chunk with a role other than Role.model,
              // it should NOT increment messageIndex if it's the first chunk of the turn.
              context.sendChunk(
                ModelResponseChunk(
                  role: Role.tool,
                  content: [TextPart(text: 'Injected tool chunk')],
                ),
              );
              context.sendChunk(
                ModelResponseChunk(
                  role: Role.model,
                  content: [TextPart(text: 'Done')],
                ),
              );

              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [TextPart(text: 'Done')],
                ),
              );
            }
          },
        );

        genkit.defineTool(
          name: toolName,
          description: 'Dummy tool',
          inputSchema: .map(.string(), .dynamicSchema()),
          fn: (input, context) async {
            return 'tool output';
          },
        );

        final chunks = <GenerateResponseChunk>[];
        await genkit.generate(
          model: modelRef(modelName),
          prompt: 'Start',
          toolNames: [toolName],
          onChunk: chunks.add,
        );

        // Turn 1 model chunk, then the streamed tool-response chunk, then the
        // two turn-2 chunks.
        expect(chunks.length, 4);

        expect(chunks[0].index, 0, reason: 'Turn 1, Chunk 1 should be 0');
        // The tool-response message streamed between turns occupies slot 1.
        expect(
          chunks[1].index,
          1,
          reason: 'Tool-response chunk should be 1',
        );
        // Turn 2: messageIndex starts at 2
        expect(
          chunks[2].index,
          2,
          reason: 'Turn 2, Chunk 1 (Role.tool) should be 2',
        );
        // Then role changes to Role.model for the next chunk in the same turn -> modelHasSentChunks is true
        expect(
          chunks[3].index,
          3,
          reason: 'Turn 2, Chunk 2 (Role.model) should be 3',
        );
      },
    );

    test('generateStream() without model uses defaultModel', () async {
      var defaultModelCalled = false;
      genkit = Genkit(
        isDevEnv: false,
        model: modelRef('defaultTestModel', config: {'temperature': 0.7}),
      );

      genkit.defineModel(
        name: 'defaultTestModel',
        fn: (request, context) async {
          defaultModelCalled = true;
          expect(request.config?['temperature'], 0.7);

          context.sendChunk(
            ModelResponseChunk(
              index: 0,
              content: [TextPart(text: 'Stream Chunk')],
            ),
          );

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Stream Chunk')],
            ),
          );
        },
      );

      final chunks = <GenerateResponseChunk>[];
      await genkit
          .generateStream(prompt: 'Hello')
          .listen(chunks.add)
          .asFuture();

      expect(defaultModelCalled, isTrue);
      expect(chunks.length, 1);
      expect(chunks[0].text, 'Stream Chunk');
    });
  });
}
