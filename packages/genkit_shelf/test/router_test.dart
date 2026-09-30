// Copyright 2026 Google LLC
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

import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
// The middleware is internal; tested directly to control the inner response.
import 'package:genkit_shelf/src/cors.dart' show corsMiddleware;
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
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

  setUp(() {
    ai = Genkit();
    echo = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputSchema: .string(),
      outputSchema: .string(),
    );
  });

  group('addAction', () {
    test('defaults the path to the action name', () async {
      final router = GenkitRouter()..addAction(echo);

      final response = await router.call(_post('/echo', 'hi'));

      expect(response.statusCode, 200);
      expect(await _result(response), 'Echo: hi');
    });

    test('serves at a custom path', () async {
      final router = GenkitRouter()..addAction(echo, path: '/v1/say');

      expect(
        await _result(await router.call(_post('/v1/say', 'x'))),
        'Echo: x',
      );
      expect((await router.call(_post('/echo', 'x'))).statusCode, 404);
    });

    test('serves action names that contain slashes', () async {
      final model = ai.defineModel(
        name: 'acme/fancy-model',
        fn: (request, _) async => ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'ok')],
          ),
        ),
      );
      final router = GenkitRouter()..addAction(model);

      final response = await router.call(
        _post(
          '/acme/fancy-model',
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hi')],
              ),
            ],
          ).toJson(),
        ),
      );

      expect(response.statusCode, 200);
    });

    test('applies the per-route context provider', () async {
      final whoami = ai.defineFlow(
        name: 'whoami',
        fn: (String _, ctx) async => '${ctx.context?['user']}',
        inputSchema: .string(),
        outputSchema: .string(),
      );
      final router = GenkitRouter()
        ..addAction(
          whoami,
          contextProvider: (request) => {
            'user': request.headers['authorization'] ?? 'anonymous',
          },
        )
        ..addAction(echo);

      final authed = await router.call(
        _post('/whoami', '', headers: {'authorization': 'alice'}),
      );
      expect(await _result(authed), 'alice');
      expect(
        await _result(await router.call(_post('/whoami', ''))),
        'anonymous',
      );
    });

    test('rejects the request when the context provider throws', () async {
      final router = GenkitRouter()
        ..addAction(echo, contextProvider: (_) => throw Exception('no token'));

      final response = await router.call(_post('/echo', 'hi'));

      expect(response.statusCode, 403);
    });

    test('throws on a duplicate path', () {
      final router = GenkitRouter()..addAction(echo);

      expect(() => router.addAction(echo), throwsArgumentError);
      expect(() => router.addAction(echo, path: '/echo'), throwsArgumentError);
      // A different path for the same action is fine.
      router.addAction(echo, path: '/echo2');
    });

    test('throws on a path without a leading slash', () {
      expect(
        () => GenkitRouter().addAction(echo, path: 'echo'),
        throwsArgumentError,
      );
    });

    test('throws on a path with a trailing slash', () {
      final router = GenkitRouter();

      expect(() => router.addAction(echo, path: '/echo/'), throwsArgumentError);
      // The root path is allowed (e.g. serving one action under a mount).
      router.addAction(echo, path: '/');
    });
  });

  group('call', () {
    test('returns 404 for unknown paths', () async {
      final router = GenkitRouter()..addAction(echo);

      final response = await router.call(_post('/nope', 'hi'));

      expect(response.statusCode, 404);
    });

    test('works when mounted under a prefix', () async {
      final genkit = GenkitRouter()..addAction(echo);
      final app = Router()
        ..get('/health', (Request _) => Response.ok('OK'))
        ..mount('/api/', genkit.call);

      final response = await app.call(_post('/api/echo', 'mounted'));

      expect(response.statusCode, 200);
      expect(await _result(response), 'Echo: mounted');
      expect((await app.call(_post('/echo', 'x'))).statusCode, 404);
    });

    test('picks up routes added after construction', () async {
      final router = GenkitRouter();
      expect((await router.call(_post('/echo', 'x'))).statusCode, 404);

      router.addAction(echo);

      expect((await router.call(_post('/echo', 'x'))).statusCode, 200);
    });
  });

  group('serve', () {
    HttpServer? server;
    tearDown(() async => server?.close(force: true));

    Future<http.Response> postEcho(String origin, {String? host}) => http.post(
      Uri.parse('http://${host ?? 'localhost'}:${server!.port}/echo'),
      headers: {'content-type': 'application/json', 'origin': origin},
      body: jsonEncode({'data': 'x'}),
    );

    Future<http.StreamedResponse> preflight(String origin) =>
        http.Client().send(
          http.Request(
              'OPTIONS',
              Uri.parse('http://localhost:${server!.port}/echo'),
            )
            ..headers['origin'] = origin
            ..headers['access-control-request-method'] = 'POST',
        );

    test('binds the requested host', () async {
      server = await (GenkitRouter()..addAction(echo)).serve(
        host: InternetAddress.loopbackIPv4,
        port: 0,
      );

      expect(server!.address, InternetAddress.loopbackIPv4);
      final response = await postEcho('https://a.dev', host: '127.0.0.1');
      expect(jsonDecode(response.body), {'result': 'Echo: x'});
    });

    test('sends no CORS headers without cors options', () async {
      server = await (GenkitRouter()..addAction(echo)).serve(port: 0);

      final response = await postEcho('https://a.dev');

      expect(response.headers['access-control-allow-origin'], isNull);
    });

    test('CorsOptions defaults allow any origin', () async {
      server = await (GenkitRouter()..addAction(echo)).serve(
        port: 0,
        cors: const CorsOptions(),
      );

      final pre = await preflight('https://a.dev');
      expect(pre.statusCode, 204);
      expect(pre.headers['access-control-allow-origin'], '*');
      expect(pre.headers['access-control-allow-methods'], 'POST, OPTIONS');
      expect(
        pre.headers['access-control-allow-headers'],
        'Content-Type, Authorization',
      );

      final response = await postEcho('https://a.dev');
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-expose-headers'],
        'x-genkit-trace-id, x-genkit-span-id',
      );
    });

    test('CorsOptions echoes an allowed origin and ignores others', () async {
      server = await (GenkitRouter()..addAction(echo)).serve(
        port: 0,
        cors: const CorsOptions(allowedOrigins: ['https://a.dev']),
      );

      final allowed = await preflight('https://a.dev');
      expect(allowed.headers['access-control-allow-origin'], 'https://a.dev');
      expect(allowed.headers['vary'], 'Origin');

      final denied = await preflight('https://evil.dev');
      expect(denied.headers['access-control-allow-origin'], isNull);
      expect(denied.headers['access-control-allow-methods'], isNull);
      final deniedPost = await postEcho('https://evil.dev');
      expect(deniedPost.headers['access-control-allow-origin'], isNull);
    });

    test('CORS appends to an existing Vary header', () async {
      Future<String?> varyFor(String innerVary) async {
        final handler = corsMiddleware(
          const CorsOptions(allowedOrigins: ['https://a.dev']),
        )((_) => Response.ok('', headers: {'Vary': innerVary}));
        final response = await handler(
          Request(
            'POST',
            Uri.parse('http://localhost/x'),
            headers: {'origin': 'https://a.dev'},
          ),
        );
        return response.headers['vary'];
      }

      expect(await varyFor('Accept-Encoding'), 'Accept-Encoding, Origin');
      expect(await varyFor('origin'), 'origin');
      expect(await varyFor('*'), '*');
    });

    test('CORS keeps streaming responses unbuffered', () async {
      final slow = ai.defineFlow(
        name: 'slow',
        fn: (String _, ctx) async {
          ctx.sendChunk('first');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return 'done';
        },
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
      );
      server = await (GenkitRouter()..addAction(slow)).serve(
        port: 0,
        cors: const CorsOptions(),
      );

      final response = await http.Client().send(
        http.Request(
            'POST',
            Uri.parse('http://localhost:${server!.port}/slow?stream=true'),
          )
          ..headers['content-type'] = 'application/json'
          ..headers['origin'] = 'https://a.dev'
          ..body = jsonEncode({'data': 'go'}),
      );
      expect(response.headers['access-control-allow-origin'], '*');

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
