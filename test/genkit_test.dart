import 'package:test/test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/core/flow.dart';

void main() {
  group('Genkit', () {
    test('should define and register a flow', () async {
      final genkit = Genkit();
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
  });
}
