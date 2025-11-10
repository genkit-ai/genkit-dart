import 'dart:convert';
import 'dart:io';

import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/core/action.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('ReflectionServer', () {
    late Registry registry;
    late ReflectionServer server;
    const port = 3200;
    final url = 'http://localhost:$port';

    setUp(() async {
      registry = Registry();
      final testAction = Action<String, String, String>(
        actionType: 'test',
        name: 'testAction',
        fn: (input, context) async {
          if (context.streamingRequested) {
            context.sendChunk('chunk1');
            context.sendChunk('chunk2');
          }
          return 'output for $input';
        },
      );
      registry.register(testAction);

      server = ReflectionServer(registry, port: port);
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('should create and clean up runtime file', () async {
      final runtimesDir = Directory('.genkit/runtimes');
      final files = await runtimesDir.list().toList();
      expect(files, isNotEmpty);
      final runtimeFile = File(files.first.path);
      final content = jsonDecode(await runtimeFile.readAsString());
      expect(content['pid'], isNotNull);
      expect(content['reflectionServerUrl'], url);

      await server.stop();

      expect(await runtimeFile.exists(), isFalse);

      // Restart server for other tests
      await server.start();
    });

    test('GET /api/actions', () async {
      final response = await http.get(Uri.parse('$url/api/actions'));
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body, contains('/test/testAction'));
      final action = body['/test/testAction'];
      expect(action['name'], 'testAction');
    });

    test('POST /api/runAction (non-streaming)', () async {
      final response = await http.post(
        Uri.parse('$url/api/runAction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': '/test/testAction', 'input': 'testInput'}),
      );
      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['result'], 'output for testInput');
      expect(body['telemetry'], isNotNull);
      expect(body['telemetry']['traceId'], isA<String>());
    });

    test('POST /api/runAction (streaming)', () async {
      final request = http.Request(
        'POST',
        Uri.parse('$url/api/runAction?stream=true'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'key': '/test/testAction',
        'input': 'testInput',
      });

      final response = await request.send();
      expect(response.statusCode, 200);

      final chunks = await response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => jsonDecode(line))
          .toList();

      expect(chunks.length, 3);
      expect(chunks[0], 'chunk1');
      expect(chunks[1], 'chunk2');
      final finalResponse = chunks[2] as Map<String, dynamic>;
      expect(finalResponse['result'], 'output for testInput');
      expect(finalResponse['telemetry'], isNotNull);
      expect(finalResponse['telemetry']['traceId'], isA<String>());
    });
  });
}
