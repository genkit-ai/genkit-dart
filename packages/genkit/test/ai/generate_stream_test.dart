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
        tools: [toolName],
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
