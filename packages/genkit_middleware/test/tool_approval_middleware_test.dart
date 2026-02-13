import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/tool_approval.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('ToolApprovalMiddleware', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, plugins: [ToolApprovalPlugin()]);
      
      genkit.defineTool(
        name: 'dangerous_tool',
        description: 'Does something dangerous',
        inputSchema: mapSchema(stringSchema(), boolSchema()), // Input is Map<String, dynamic> at runtime
        fn: (input, context) async {
          return 'Dangerous action confirmed: $input';
        },
      );

      genkit.defineTool(
        name: 'safe_tool',
        description: 'Does something safe',
        inputSchema: mapSchema(stringSchema(), boolSchema()), // Input is Map<String, dynamic> at runtime
        fn: (input, context) async {
          return 'Safe action confirmed: $input';
        },
      );
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should allow approved tools to execute', () async {
      final mw = toolApproval(approved: ['safe_tool']);

      genkit.defineModel(
        name: 'approval-test-model-safe',
        fn: (req, ctx) async {
          if (!req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(name: 'safe_tool', input: {'test': true}),
                  )
                ],
              ),
            );
          }

          final toolResponse = req.messages.last.content.first.toolResponsePart!.toolResponse;
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Model: ${toolResponse.output}')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('approval-test-model-safe'),
        prompt: 'run safe tool',
        use: [mw],
      );

      expect(response.text, 'Model: Safe action confirmed: {test: true}');
    });

    test('should interrupt on unapproved tools', () async {
      final mw = toolApproval(approved: ['safe_tool']);

      genkit.defineModel(
        name: 'approval-test-model-dangerous',
        fn: (req, ctx) async {
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'dangerous_tool', input: {'test': true}),
                )
              ],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('approval-test-model-dangerous'),
        prompt: 'run dangerous tool',
        use: [mw],
      );

      expect(response.finishReason, FinishReason.interrupted);
      expect(response.interrupts.length, 1);
      final interrupt = response.interrupts.first;
      expect(interrupt.toolRequest.name, 'dangerous_tool');
      
      final part = response.message!.content.first;
      expect(part.toolRequestPart, isNotNull);
      expect(part.metadata?['interrupt'], 'Tool not in approved list');
    });

    test('should resume successfully with user approval via tool-approved metadata', () async {
      final mw = toolApproval(approved: ['safe_tool']);
      var modelCallCount = 0;

      genkit.defineModel(
        name: 'approval-test-model-resume',
        fn: (req, ctx) async {
          modelCallCount++;
          
          if (req.messages.last.role == Role.tool) {
            final toolResponse = req.messages.last.content.first.toolResponsePart!.toolResponse;
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Model: ${toolResponse.output}')],
              ),
            );
          }
          
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(name: 'dangerous_tool', input: {'test': true}),
                )
              ],
            ),
          );
        },
      );

      final response1 = await genkit.generate(
        model: modelRef('approval-test-model-resume'),
        prompt: 'run dangerous tool',
        use: [mw],
      );

      expect(response1.finishReason, FinishReason.interrupted);

      // User confirms execution by re-running and placing 'tool-approved': true
      // inside the interruptRestart configuration
      
      final response2 = await genkit.generate(
        model: modelRef('approval-test-model-resume'),
        messages: response1.messages,
        use: [mw],
        interruptRestart: [
           ToolRequestPart(
             toolRequest: response1.message!.content.first.toolRequestPart!.toolRequest,
             metadata: {'tool-approved': true},
           )
        ],
      );

      expect(modelCallCount, 2);
      expect(response2.text, 'Model: Dangerous action confirmed: {test: true}');
    });
  });
}
