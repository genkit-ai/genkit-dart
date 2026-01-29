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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  const port = 3110;
  final url = 'http://localhost:$port';

  group('ReflectionServer lifecycle', () {
    test('should create and clean up runtime file', () async {
      final registry = Registry();
      final server = ReflectionServer(registry, port: port);
      await server.start();

      expect(server.runtimeFilePath, isNotNull);
      final runtimeFile = File(server.runtimeFilePath!);
      expect(await runtimeFile.exists(), isTrue);

      final content = jsonDecode(await runtimeFile.readAsString());
      expect(content['pid'], isNotNull);
      expect(content['reflectionServerUrl'], url);

      await server.stop();

      expect(await runtimeFile.exists(), isFalse);
    });
  });

  group('ReflectionServer API', () {
    late Registry registry;
    late ReflectionServer server;

    setUp(() async {
      registry = Registry();
      final testAction = Action(
        actionType: 'test',
        inputSchema: stringType(),
        outputSchema: stringType(),
        streamSchema: stringType(),
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
          .map(jsonDecode)
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
