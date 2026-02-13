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
import 'package:schemantic/schemantic.dart';
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
              ModelResponseChunk(
                index: 0,
                content: [TextPart(text: 'Calling tool...')],
              ),
            );
            context.sendChunk(
              ModelResponseChunk(
                index: 0,
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
              ModelResponseChunk(index: 0, content: [TextPart(text: 'Done')]),
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
        inputSchema: mapSchema(stringSchema(), dynamicSchema()),
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

      expect(chunks.length, 3);

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
      expect(chunks[2].index, 1, reason: 'Chunk of second turn should be 1');
    });
  });
}
