import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/reflection_v2.dart';
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
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final msg = await ws.first;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;

      expect(decoded['method'], equals('register'));
      expect(decoded['params']['name'], equals('test-app'));
    });

    test('should handle listActions', () async {
      final testAction = Action<Map<String, dynamic>, dynamic, dynamic>(
        actionType: 'custom',
        name: 'testAction',
        fn: (input, context) async => {'bar': input['foo']},
        metadata: {'description': 'A test action'},
      );
      registry.register(testAction);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      var msg = await queue.next;
      var decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['method'], equals('register'));

      // Request listActions
      ws.add(jsonEncode({
        'jsonrpc': '2.0',
        'method': 'listActions',
        'id': '123',
      }));

      // Response
      msg = await queue.next;
      decoded = jsonDecode(msg as String) as Map<String, dynamic>;
      expect(decoded['id'], equals('123'));
      expect(decoded['result']['/custom/testAction'], isNotNull);
      expect(
        decoded['result']['/custom/testAction']['name'],
        equals('testAction'),
      );
    });

    test('should handle runAction', () async {
      final testAction = Action<Map<String, dynamic>, dynamic, dynamic>(
        actionType: 'custom',
        name: 'testAction',
        fn: (input, context) async => {'bar': input['foo']},
      );
      registry.register(testAction);

      reflectionServer = ReflectionServerV2(
        registry,
        url: 'ws://localhost:$port',
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request runAction
      ws.add(jsonEncode({
        'jsonrpc': '2.0',
        'method': 'runAction',
        'params': {
          'key': '/custom/testAction',
          'input': {'foo': 'baz'},
        },
        'id': '456',
      }));

      // Response
      final msg = await queue.next;
      final decoded = jsonDecode(msg as String) as Map<String, dynamic>;

      expect(decoded['id'], equals('456'));
      expect(decoded['result']['result']['bar'], equals('baz'));
    });

    test('should handle streaming runAction', () async {
      final streamAction = Action<dynamic, String, String>(
        actionType: 'custom',
        name: 'streamAction',
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
      );
      await reflectionServer.start();

      final ws = await wsConnection.future;
      final queue = StreamQueue(ws);

      // First message is register
      await queue.next;

      // Request runAction with stream: true
      ws.add(jsonEncode({
        'jsonrpc': '2.0',
        'method': 'runAction',
        'params': {
          'key': '/custom/streamAction',
          'input': {'foo': 'baz'},
          'stream': true,
        },
        'id': '789',
      }));

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