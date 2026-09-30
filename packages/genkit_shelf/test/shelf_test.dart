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

// The protocol itself is tested in package:genkit (test/server); these tests
// cover only the shelf translation.

import 'dart:convert';
import 'dart:io';

import 'package:genkit/client.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

Request _post(String path, Object? data, {Map<String, String>? headers}) =>
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode({'data': data}),
      headers: {'content-type': 'application/json', ...?headers},
    );

Future<Object?> _result(Response response) async =>
    (jsonDecode(await response.readAsString()) as Map)['result'];

void main() {
  late Genkit ai;
  late Flow<String, String, void, void> echo;
  HttpServer? server;

  setUp(() {
    ai = Genkit();
    echo = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputSchema: .string(),
      outputSchema: .string(),
    );
  });

  tearDown(() async => server?.close(force: true));

  group('shelfHandler', () {
    test('serves a single action', () async {
      final response = await shelfHandler(echo)(_post('/anything', 'direct'));

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/json');
      expect(await _result(response), 'Echo: direct');
    });

    test('passes headers to the context provider', () async {
      final whoami = ai.defineFlow(
        name: 'whoami',
        fn: (String _, ctx) async => '${ctx.context?['user']}',
        inputSchema: .string(),
        outputSchema: .string(),
      );
      final handler = shelfHandler(
        whoami,
        contextProvider: (request) => {
          'user': request.headers['authorization'] ?? 'anonymous',
        },
      );

      final response = await handler(
        _post('/whoami', '', headers: {'Authorization': 'alice'}),
      );

      expect(await _result(response), 'alice');
    });

    test('maps errors to status codes', () async {
      final handler = shelfHandler(
        echo,
        contextProvider: (_) => throw GenkitException(
          'Unauthorized',
          status: StatusCodes.UNAUTHENTICATED,
        ),
      );

      final response = await handler(_post('/echo', 'x'));

      expect(response.statusCode, 401);
      expect(jsonDecode(await response.readAsString()), {
        'code': 401,
        'status': 'UNAUTHENTICATED',
        'message': 'Unauthorized',
      });
    });
  });

  test('sendLegacyErrorFrame reaches the stream error frame', () async {
    final failing = ai.defineFlow(
      name: 'failing',
      fn: (String _, _) async =>
          throw GenkitException('nope', status: StatusCodes.NOT_FOUND),
      streamSchema: .string(),
    );
    Future<String> lastFrame(Handler handler) async {
      final response = await handler(_post('/failing?stream=true', 'x'));
      final frames = (await response.readAsString())
          .split('\n\n')
          .where((f) => f.trim().isNotEmpty);
      return frames.last;
    }

    expect(await lastFrame(shelfHandler(failing)), startsWith('data: '));
    expect(
      await lastFrame(shelfHandler(failing, sendLegacyErrorFrame: true)),
      startsWith('error: '),
    );
    final legacyRouter = GenkitRouter(sendLegacyErrorFrame: true)
      ..addAction(failing);
    expect(await lastFrame(legacyRouter.asShelfHandler), startsWith('error: '));
  });

  group('asShelfHandler', () {
    test('works when mounted under a prefix', () async {
      final genkit = GenkitRouter()..addAction(echo);
      final app = Router()
        ..get('/health', (Request _) => Response.ok('OK'))
        ..mount('/api/', genkit.asShelfHandler);

      final response = await app.call(_post('/api/echo', 'mounted'));

      expect(response.statusCode, 200);
      expect(await _result(response), 'Echo: mounted');
      expect((await app.call(_post('/echo', 'x'))).statusCode, 404);
    });

    test('404 falls through a Cascade', () async {
      final genkit = GenkitRouter()..addAction(echo);
      final handler = Cascade()
          .add(genkit.asShelfHandler)
          .add((Request _) => Response.ok('fallback'))
          .handler;

      expect(await _result(await handler(_post('/echo', 'x'))), 'Echo: x');
      final fallback = await handler(_post('/other', 'x'));
      expect(await fallback.readAsString(), 'fallback');
    });

    test('works with remote clients and keeps streams unbuffered', () async {
      final slow = ai.defineFlow(
        name: 'slow',
        fn: (String _, ctx) async {
          ctx.sendChunk('first');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          ctx.sendChunk('second');
          return 'done';
        },
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
      );
      final genkit = GenkitRouter()..addAction(slow);
      // Middleware that rebuilds the response must keep its context.
      final handler = const Pipeline()
          .addMiddleware(logRequests(logger: (_, _) {}))
          .addHandler(genkit.asShelfHandler);
      server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);

      final action = defineRemoteAction(
        url: 'http://127.0.0.1:${server!.port}/slow',
        outputSchema: .string(),
        streamSchema: .string(),
      );
      final stream = action.stream(input: 'go');
      expect(await stream.toList(), ['first', 'second']);
      expect(await stream.onResult, 'done');

      final response = await http.Client().send(
        http.Request(
            'POST',
            Uri.parse('http://127.0.0.1:${server!.port}/slow?stream=true'),
          )
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode({'data': 'go'}),
      );
      final start = DateTime.now();
      final arrivals = <int>[];
      await response.stream
          .listen(
            (_) =>
                arrivals.add(DateTime.now().difference(start).inMilliseconds),
          )
          .asFuture<void>();
      expect(arrivals.length, greaterThanOrEqualTo(2));
      expect(arrivals.first, lessThan(100));
    });
  });
}
