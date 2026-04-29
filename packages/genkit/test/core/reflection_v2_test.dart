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

// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:genkit/src/ai/generate_middleware.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/reflection/reflection_v2.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:test/test.dart';

void main() {
  group('ReflectionServerV2', () {
    late HttpServer server;
    late ReflectionServerV2 reflectionServer;
    late Registry registry;
    late int port;
    late Completer<WebSocket> wsConnection;

    setUp(() async {
      registry = Registry();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      port = server.port;
      wsConnection = Completer<WebSocket>();

      server.listen((HttpRequest req) async {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          final ws = await WebSocketTransformer.upgrade(req);
          wsConnection.complete(ws);
        }
      });
    });

    tearDown(() async {
      await reflectionServer.stop();
      await server.close();
    });

    test('should connect to the server and register', () async {
      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        name: 'test-app',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final msg = await ws.first;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;

      expect(decoded['method'], equals('register'));
      expect(decoded['params']['name'], equals('test-app'));
    });

    test('should handle listActions', () async {
      final testAction = Action(
        actionType: 'custom',
        inputSchema: .map(.string(), .string()),
        name: 'testAction',
        fn: (input, context) async => {'bar': input!['foo']},
        metadata: {'description': 'A test action'},
      );
      registry.register(testAction);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      var msg = await queue.next;
      var decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['method'], equals('register'));

      // Request listActions
      ws.add(
        jsonEncode({'jsonrpc': '2.0', 'method': 'listActions', 'id': '123'}),
      );

      // Response
      msg = await queue.next;
      decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('123'));
      expect(decoded['result']['actions']['/custom/testAction'], isNotNull);
      expect(
        decoded['result']['actions']['/custom/testAction']['name'],
        equals('testAction'),
      );
    });

    test('should handle listValues for middleware', () async {
      final def = defineMiddleware<dynamic>(
        name: 'retry',
        create: ([config]) => throw UnimplementedError(),
      );
      registry.registerValue('middleware', def.name, def);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request listValues for middleware
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'listValues',
          'params': {'type': 'middleware'},
          'id': 'list-middleware',
        }),
      );

      // Response for middleware
      final msg = await queue.next;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('list-middleware'));
      expect(decoded['result']['values']['/middleware/retry'], isNotNull);
      expect(
        decoded['result']['values']['/middleware/retry']['name'],
        equals('retry'),
      );
    });

    test('should skip non-conforming values in listValues', () async {
      registry.registerValue('middleware', 'not-a-middleware', 'just-a-string');

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request listValues for middleware
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'listValues',
          'params': {'type': 'middleware'},
          'id': 'list-skip',
        }),
      );

      // Response for middleware
      final msg = await queue.next;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('list-skip'));
      expect(
        decoded['result']['values']['/middleware/not-a-middleware'],
        isNull,
      );
    });

    test('should handle listValues for defaultModel', () async {
      final model = modelRef('test-model', config: {'temperature': 2});
      registry.registerValue('defaultModel', 'defaultModel', model);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request listValues for defaultModel
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'listValues',
          'params': {'type': 'defaultModel'},
          'id': 'list-model',
        }),
      );

      // Response for defaultModel
      final msg = await queue.next;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('list-model'));
      expect(
        decoded['result']['values']['/defaultModel/defaultModel'],
        isNotNull,
      );
      expect(
        decoded['result']['values']['/defaultModel/defaultModel']['name'],
        equals('test-model'),
      );
      expect(
        decoded['result']['values']['/defaultModel/defaultModel']['config']['temperature'],
        equals(2),
      );
    });

    test('should handle listValues for unsupported type', () async {
      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request listValues for unsupported type
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'listValues',
          'params': {'type': 'unsupported'},
          'id': 'list-err',
        }),
      );

      // Response for unsupported type
      final msg = await queue.next;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('list-err'));
      expect(decoded['error'], isNotNull);
      expect(decoded['error']['code'], equals(-32602));
      expect(
        decoded['error']['message'],
        contains('Unsupported type parameter'),
      );
    });

    test('should handle runAction', () async {
      final testAction = Action(
        actionType: 'custom',
        inputSchema: .map(.string(), .string()),
        name: 'testAction',
        fn: (input, context) async => {'bar': input!['foo']},
      );
      registry.register(testAction);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request runAction
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'runAction',
          'params': {
            'key': '/custom/testAction',
            'input': {'foo': 'baz'},
          },
          'id': '456',
        }),
      );

      // Notification
      var msg = await queue.next;
      var decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['method'], equals('runActionState'));

      // Response
      msg = await queue.next;
      decoded = jsonDecode(msg as String) as Map<String, dynamic>;

      expect(decoded['id'], equals('456'));
      expect(decoded['result']['result']['bar'], equals('baz'));
    });

    test('should handle streaming runAction', () async {
      final streamAction = Action(
        actionType: 'custom',
        name: 'streamAction',
        streamSchema: .string(),
        fn: (input, context) async {
          context.sendChunk('chunk1');
          context.sendChunk('chunk2');
          return 'done';
        },
      );
      registry.register(streamAction);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
        runtimeId: 'test-runtime-id',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request runAction with stream: true
      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'runAction',
          'params': {
            'key': '/custom/streamAction',
            'input': {'foo': 'baz'},
            'stream': true,
          },
          'id': '789',
        }),
      );

      // Should receive chunks then result
      // Note: chunks and result order is determined by implementation.
      // Implementation: await action.run(...) -> sends chunks during run -> then sends result.
      // So chunks come first.

      final chunks = [];
      var done = false;
      while (!done) {
        final msg = await queue.next;
        final decoded = jsonDecode(msg as String);
        if (decoded['method'] == 'streamChunk') {
          chunks.add(decoded['params']['chunk']);
        } else if (decoded['id'] == '789') {
          expect(decoded['result']['result'], equals('done'));
          done = true;
        }
      }
      expect(chunks, equals(['chunk1', 'chunk2']));
    });
  });
}
