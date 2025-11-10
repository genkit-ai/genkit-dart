import 'dart:io';

import 'package:test/test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:http/http.dart' as http;

void main() {
  group('Genkit', () {
    test('should start reflection server in dev mode', () async {
      final genkit = Genkit(isDevEnv: true);
      try {
        final response =
            await http.get(Uri.parse('http://localhost:3110/api/__health'));
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
  });
}
