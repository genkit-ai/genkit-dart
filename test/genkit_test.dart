import 'dart:io';

import 'package:test/test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Genkit', () {
    test('should start reflection server in dev mode', () async {
      final genkit = Genkit(isDevEnv: true);
      try {
        final response = await http.get(
          Uri.parse('http://localhost:3110/api/__health'),
        );
        expect(response.statusCode, 200);
      } finally {
        await genkit.shutdown();
      }
    });

    test('should not start reflection server in non-dev mode', () async {
      final genkit = Genkit(isDevEnv: false);
      await expectLater(
        () => http.get(Uri.parse('http://localhost:3110/api/__health')),
        throwsA(isA<SocketException>()),
      );
      await genkit.shutdown();
    });

    test('should define and register a flow', () async {
      final genkit = Genkit(isDevEnv: false);
      const flowName = 'testFlow';

      final flow = genkit.defineFlow(
        name: flowName,
        fn: (String input, context) async => 'output: $input',
      );

      // Check if the returned flow is correct
      expect(flow, isA<Flow>());
      expect(flow.name, flowName);

      // Check if the flow is registered in the registry
      final retrievedAction = await genkit.registry.get('flow', flowName);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction, isA<Flow>());
      expect(retrievedAction!.name, flowName);

      // Check if the returned flow and the registered flow are the same instance
      expect(identical(flow, retrievedAction), isTrue);
    });

    test('should define and register a tool', () async {
      final genkit = Genkit(isDevEnv: false);
      const toolName = 'testTool';
      const toolDescription = 'A test tool.';

      final tool = genkit.defineTool(
        name: toolName,
        description: toolDescription,
        fn: (String input, context) async => 'output: $input',
      );

      // Check if the returned tool is correct
      expect(tool, isA<Tool>());
      expect(tool.name, toolName);
      expect(tool.description, toolDescription);

      // Check if the tool is registered in the registry
      final retrievedAction = await genkit.registry.get('tool', toolName);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction, isA<Tool>());
      expect(retrievedAction!.name, toolName);
      expect((retrievedAction as Tool).description, toolDescription);

      // Check if the returned tool and the registered tool are the same instance
      expect(identical(tool, retrievedAction), isTrue);
    });

    test('should call generate action with correct parameters', () async {
      final genkit = Genkit(isDevEnv: false);
      const modelName = 'testModel';
      const prompt = 'test prompt';
      final response = ModelResponse.from(
        finishReason: FinishReason.stop,
        message: Message.from(
          role: Role.model,
          content: [TextPart.from(text: 'test response')],
        ),
      );

      genkit.defineModel(
        name: modelName,
        fn: (request, context) async {
          return response;
        },
      );

      final result = await genkit.generate(model: modelName, prompt: prompt);

      expect(result.text, 'test response');
    });
  });
}
