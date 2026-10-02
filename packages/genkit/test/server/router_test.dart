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
import 'package:genkit/io.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

GenkitHttpRequest _post(
  String path,
  Object? data, {
  Map<String, String> headers = const {},
}) => GenkitHttpRequest(
  method: 'POST',
  path: path,
  headers: {'content-type': 'application/json', ...headers},
  body: Stream.value(utf8.encode(jsonEncode({'data': data}))),
);

Future<Object?> _result(GenkitHttpResponse? response) async =>
    (jsonDecode(await utf8.decodeStream(response!.body)) as Map)['result'];

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

      final response = await router.handle(_post('/echo', 'hi'));

      expect(response!.statusCode, 200);
      expect(await _result(response), 'Echo: hi');
    });

    test('serves at a custom path', () async {
      final router = GenkitRouter()..addAction(echo, path: '/v1/say');

      expect(
        await _result(await router.handle(_post('/v1/say', 'x'))),
        'Echo: x',
      );
      expect(await router.handle(_post('/echo', 'x')), isNull);
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

      final response = await router.handle(
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

      expect(response!.statusCode, 200);
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

      final authed = await router.handle(
        _post('/whoami', '', headers: {'authorization': 'alice'}),
      );
      expect(await _result(authed), 'alice');
      expect(
        await _result(await router.handle(_post('/whoami', ''))),
        'anonymous',
      );
    });

    test('rejects the request when the context provider throws', () async {
      final router = GenkitRouter()
        ..addAction(echo, contextProvider: (_) => throw Exception('no token'));

      final response = await router.handle(_post('/echo', 'hi'));

      expect(response!.statusCode, 403);
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

  group('handle', () {
    test('returns null for unknown paths', () async {
      final router = GenkitRouter()..addAction(echo);

      expect(await router.handle(_post('/nope', 'hi')), isNull);
    });

    test('picks up routes added after construction', () async {
      final router = GenkitRouter();
      expect(await router.handle(_post('/echo', 'x')), isNull);

      router.addAction(echo);

      expect((await router.handle(_post('/echo', 'x')))!.statusCode, 200);
    });
  });

  group('handleHttpRequest', () {
    HttpServer? server;
    tearDown(() async => server?.close(force: true));

    /// A raw dart:io server that tries [router] under [basePath] first and
    /// answers everything else itself.
    Future<String> serveRaw(
      GenkitRouter router, {
      String basePath = '',
      CorsOptions? cors,
    }) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen((request) async {
        if (await router.handleHttpRequest(
          request,
          basePath: basePath,
          cors: cors,
        )) {
          return;
        }
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('app 404');
        await request.response.close();
      });
      return 'http://127.0.0.1:${server!.port}';
    }

    Future<http.Response> post(String url, {Map<String, String>? headers}) =>
        http.post(
          Uri.parse(url),
          headers: {'content-type': 'application/json', ...?headers},
          body: jsonEncode({'data': 'x'}),
        );

    test('serves routes below basePath and falls through otherwise', () async {
      final base = await serveRaw(
        GenkitRouter()..addAction(echo),
        basePath: '/api',
      );

      final hit = await post('$base/api/echo');
      expect(hit.statusCode, 200);
      expect(jsonDecode(hit.body), {'result': 'Echo: x'});

      for (final path in ['/echo', '/api/nope', '/apiecho', '/api']) {
        final miss = await post('$base$path');
        expect(miss.statusCode, 404, reason: path);
        expect(miss.body, 'app 404', reason: path);
      }
    });

    test('maps basePath itself to the root route', () async {
      final base = await serveRaw(
        GenkitRouter()..addAction(echo, path: '/'),
        basePath: '/echo',
      );

      expect(jsonDecode((await post('$base/echo')).body), {
        'result': 'Echo: x',
      });
    });

    test('matches percent-encoded paths, basePath included', () async {
      final router = GenkitRouter()
        ..addAction(echo, path: '/acme/fancy-model')
        ..addAction(echo, path: '/with space');
      final base = await serveRaw(router, basePath: '/my api');

      for (final path in [
        '/my%20api/acme%2Ffancy-model',
        '/my%20api/acme/fancy-model',
        '/my%20api/with%20space',
      ]) {
        final response = await post('$base$path');
        expect(response.statusCode, 200, reason: path);
        expect(jsonDecode(response.body), {'result': 'Echo: x'});
      }
      // An invalid escape can't name a route, so the app gets it.
      final bad = await post('$base/my%20api/%FF');
      expect(bad.body, 'app 404');
    });

    test('applies CORS to its own routes only', () async {
      final base = await serveRaw(
        GenkitRouter()..addAction(echo),
        cors: const CorsOptions(),
      );

      final hit = await post(
        '$base/echo',
        headers: {'origin': 'https://a.dev'},
      );
      expect(hit.headers['access-control-allow-origin'], '*');
      final miss = await post(
        '$base/nope',
        headers: {'origin': 'https://a.dev'},
      );
      expect(miss.headers['access-control-allow-origin'], isNull);
    });

    test('throws on an invalid basePath', () async {
      final router = GenkitRouter()..addAction(echo);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final errors = <Object>[];
      server!.listen((request) async {
        for (final basePath in ['api', '/api/']) {
          try {
            await router.handleHttpRequest(request, basePath: basePath);
          } catch (e) {
            errors.add(e);
          }
        }
        await request.response.close();
      });

      await http.post(Uri.parse('http://127.0.0.1:${server!.port}/echo'));

      expect(errors, [isArgumentError, isArgumentError]);
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

    test('returns 404 for unknown paths', () async {
      server = await (GenkitRouter()..addAction(echo)).serve(port: 0);

      final response = await http.post(
        Uri.parse('http://localhost:${server!.port}/nope'),
      );

      expect(response.statusCode, 404);
    });

    test('matches percent-encoded paths', () async {
      server =
          await (GenkitRouter()..addAction(echo, path: '/acme/fancy-model'))
              .serve(port: 0);
      Future<http.Response> postPath(String path) => http.post(
        Uri.parse('http://localhost:${server!.port}$path'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'data': 'x'}),
      );

      final encoded = await postPath('/acme%2Ffancy-model');
      expect(jsonDecode(encoded.body), {'result': 'Echo: x'});
      expect((await postPath('/acme%2')).statusCode, 404);
      expect((await postPath('/%FF')).statusCode, 404);
    });

    test('restricted origins add Vary: Origin to every response', () async {
      const cors = CorsOptions(allowedOrigins: ['https://a.dev']);
      Future<GenkitHttpResponse> respond(String method, {String? origin}) =>
          withCors(
            cors,
            GenkitHttpRequest(
              method: method,
              path: '/x',
              headers: {'origin': ?origin},
            ),
            (_) async => GenkitHttpResponse(statusCode: 200),
          );

      // Without CORS headers too, so a cache never hands them to a.dev.
      for (final origin in [null, 'https://evil.dev', 'https://a.dev']) {
        expect(
          (await respond('POST', origin: origin)).headers['vary'],
          'Origin',
          reason: 'POST from $origin',
        );
        expect(
          (await respond('OPTIONS', origin: origin)).headers['vary'],
          'Origin',
          reason: 'OPTIONS from $origin',
        );
      }
      final denied = await respond('POST', origin: 'https://evil.dev');
      expect(denied.headers['access-control-allow-origin'], isNull);

      // Any origin gets the same response, so no Vary is needed.
      final open = await withCors(
        const CorsOptions(),
        GenkitHttpRequest(method: 'POST', path: '/x'),
        (_) async => GenkitHttpResponse(statusCode: 200),
      );
      expect(open.headers['vary'], isNull);
    });

    test('CORS appends to an existing Vary header', () async {
      Future<String?> varyFor(String innerVary) async {
        final response = await withCors(
          const CorsOptions(allowedOrigins: ['https://a.dev']),
          GenkitHttpRequest(
            method: 'POST',
            path: '/x',
            headers: {'origin': 'https://a.dev'},
          ),
          (_) async =>
              GenkitHttpResponse(statusCode: 200, headers: {'vary': innerVary}),
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
