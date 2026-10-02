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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:genkit/client.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
// resetInstrumentation is test-only and not part of the public telemetry API.
import 'package:genkit/src/o11y/instrumentation.dart' show resetInstrumentation;
import 'package:genkit/telemetry.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'action_handler_test.g.dart';

@Schema()
abstract class $HandlerTestOutput {
  String get greeting;
}

@Schema()
abstract class $HandlerTestStream {
  String get chunk;
}

/// Minimal [Instrumentation] that hands out fixed trace/span ids, so tests can
/// assert the handler surfaces them as `x-genkit-*` headers.
class _FakeInstrumentation implements Instrumentation {
  final String traceId;
  final String spanId;

  _FakeInstrumentation({required this.traceId, required this.spanId});

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) {
    return next(_FakeSpanContext(traceId, spanId));
  }
}

class _FakeSpanContext implements SpanContext {
  @override
  final String traceId;
  @override
  final String spanId;

  _FakeSpanContext(this.traceId, this.spanId);

  @override
  void setMetadata(Map<String, Object?> metadata) {}
}

/// An action whose [run] override never calls `onTraceStart`, so the streaming
/// handler must not wait for it before sending headers.
final class _NoTraceAction extends Action<String, String, String, void> {
  _NoTraceAction()
    : super(
        name: 'noTrace',
        actionType: ActionType.flow,
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
        fn: (input, _) async => throw UnimplementedError(),
      );

  @override
  Future<RunResult<String>> run(
    String? input, {
    StreamingCallback<String>? onChunk,
    Map<String, dynamic>? context,
    Stream<String>? inputStream,
    void init,
    TraceStartCallback? onTraceStart,
    CancellationToken? cancel,
  }) async {
    onChunk?.call('chunk');
    return RunResult(result: 'done $input', traceId: '', spanId: '');
  }
}

/// The `error` payload of the final frame of a streamed [body], which must be
/// a `data: {"error": ...}` frame, or `error: {"error": ...}` when [legacy].
Map<String, dynamic> _streamError(String body, {bool legacy = false}) {
  final prefix = legacy ? 'error: ' : 'data: ';
  final frames = body
      .split('\n\n')
      .map((f) => f.trim())
      .where((f) => f.isNotEmpty);
  final last = frames.last;
  expect(last, startsWith(prefix));
  final event =
      jsonDecode(last.substring(prefix.length)) as Map<String, dynamic>;
  expect(event.keys, ['error']);
  return event['error'] as Map<String, dynamic>;
}

void main() {
  late Genkit ai;
  HttpServer? server;
  late int port;

  setUp(() {
    ai = Genkit();
  });

  tearDown(() async {
    await server?.close(force: true);
    resetInstrumentation();
  });

  test('Unary flow', () async {
    final echoFlow = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(echoFlow)).serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/echo',
      fromResponse: (data) => data as String,
    );

    final result = await action(input: 'hello');
    expect(result, 'Echo: hello');
  });

  test('Streaming flow', () async {
    final streamFlow = ai.defineFlow(
      name: 'stream',
      fn: (input, ctx) async {
        ctx.sendChunk('Chunk 1');
        await Future.delayed(const Duration(milliseconds: 10));
        ctx.sendChunk('Chunk 2');
        return 'Done';
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(streamFlow)).serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/stream',
      fromResponse: (data) => data as String,
      fromStreamChunk: (data) => data as String,
    );

    final stream = action.stream(input: 'start');
    final chunks = <String>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    expect(chunks, ['Chunk 1', 'Chunk 2']);
    expect(await stream.onResult, 'Done');
  });

  test('Unary flow receives init', () async {
    final initFlow = ai.defineFlow<String, String, void, String>(
      name: 'unaryInit',
      fn: (input, ctx) async => 'input=$input init=${ctx.init}',
      inputSchema: .string(),
      outputSchema: .string(),
      initSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(initFlow)).serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction<String, String, void, String>(
      url: 'http://localhost:$port/unaryInit',
      fromResponse: (data) => data as String,
    );

    final result = await action.call(input: 'hello', init: 'config-1');
    expect(result, 'input=hello init=config-1');
  });

  test('Streaming flow receives init', () async {
    final initStreamFlow = ai.defineFlow<String, String, String, String>(
      name: 'streamInit',
      fn: (input, ctx) async {
        ctx.sendChunk('chunk init=${ctx.init}');
        return 'done init=${ctx.init}';
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
      initSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(initStreamFlow)).serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction<String, String, String, String>(
      url: 'http://localhost:$port/streamInit',
      fromResponse: (data) => data as String,
      fromStreamChunk: (data) => data as String,
    );

    final stream = action.stream(input: 'start', init: 'config-2');
    final chunks = <String>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    expect(chunks, ['chunk init=config-2']);
    expect(await stream.onResult, 'done init=config-2');
  });

  test('Context provider', () async {
    final authFlow = ai.defineFlow(
      name: 'auth',

      fn: (input, ctx) async {
        final user = ctx.context?['user'];
        if (user == null) {
          throw GenkitException(
            'Unauthorized',
            status: StatusCode.permissionDenied,
          );
        }
        return 'Hello $user';
      },
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server =
        await (GenkitRouter()..addAction(
              authFlow,
              contextProvider: (req) {
                final auth = req.headers['authorization'];
                if (auth == 'Bearer token') {
                  return {'user': 'Admin'};
                }
                return {};
              },
            ))
            .serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/auth',
      fromResponse: (data) => data as String,
      defaultHeaders: {'Authorization': 'Bearer token'},
    );

    final result = await action(input: 'hi');
    expect(result, 'Hello Admin');

    // Fail case
    final actionFail = defineRemoteAction(
      url: 'http://localhost:$port/auth',
      fromResponse: (data) => data as String,
    );

    try {
      await actionFail(input: 'hi');
      fail('Should have thrown');
    } catch (e) {
      // Expected
      expect(e.toString(), contains('Unauthorized'));
    }
  });

  test('Unary flow maps GenkitException status', () async {
    final deniedFlow = ai.defineFlow(
      name: 'denied',
      fn: (input, _) async {
        throw GenkitException(
          'You shall not pass',
          status: StatusCode.permissionDenied,
        );
      },
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(deniedFlow)).serve(port: 0);
    port = server!.port;

    final response = await http.post(
      Uri.parse('http://localhost:$port/denied'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': 'hello'}),
    );

    expect(response.statusCode, 403);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['code'], 403);
    expect(body['status'], 'PERMISSION_DENIED');
    expect(body['message'], 'You shall not pass');
  });

  test('Unary flow rejects a null input with 400', () async {
    final echoFlow = ai.defineFlow(
      name: 'echoNonNull',
      fn: (String input, _) async => input,
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(echoFlow)).serve(port: 0);
    port = server!.port;

    final response = await http.post(
      Uri.parse('http://localhost:$port/echoNonNull'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': null}),
    );

    expect(response.statusCode, 400);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['status'], 'INVALID_ARGUMENT');
    expect(body['message'], contains('non-null input'));
  });

  test('Streaming flow sends mapped SSE error payload', () async {
    final streamErrorFlow = ai.defineFlow(
      name: 'streamError',
      fn: (input, _) async {
        throw GenkitException(
          'Bad stream input',
          status: StatusCode.invalidArgument,
        );
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(streamErrorFlow)).serve(port: 0);
    port = server!.port;

    final client = http.Client();
    addTearDown(client.close);

    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:$port/streamError?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({'data': 'hello'});

    final response = await client.send(request);
    expect(response.statusCode, 200);

    final error = _streamError(await response.stream.bytesToString());

    expect(error['code'], 400);
    expect(error['status'], 'INVALID_ARGUMENT');
    expect(error['message'], 'Bad stream input');
  });

  group('stream error frames', () {
    late Flow<String, String, String, void> failing;
    setUp(() {
      failing = ai.defineFlow(
        name: 'failing',
        fn: (input, ctx) async {
          ctx.sendChunk('partial');
          throw GenkitException('Bad input', status: StatusCode.notFound);
        },
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
      );
    });

    Future<String> streamBody(String url) async {
      final response = await http.Client().send(
        http.Request('POST', Uri.parse('$url?stream=true'))
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode({'data': 'x'}),
      );
      return response.stream.bytesToString();
    }

    test('GenkitRouter(sendLegacyErrorFrame) sends the error: frame', () async {
      server = await (GenkitRouter(
        sendLegacyErrorFrame: true,
      )..addAction(failing)).serve(port: 0);

      final error = _streamError(
        await streamBody('http://127.0.0.1:${server!.port}/failing'),
        legacy: true,
      );
      expect(error['status'], 'NOT_FOUND');
      expect(error['message'], 'Bad input');
    });

    test('actionHandler and ioHandler take the flag too', () async {
      final legacy = await actionHandler(failing, sendLegacyErrorFrame: true)(
        GenkitHttpRequest(
          method: 'POST',
          path: '/failing',
          queryParameters: {'stream': 'true'},
          body: Stream.value(utf8.encode('{"data": "x"}')),
        ),
      );
      _streamError(await utf8.decodeStream(legacy.body), legacy: true);

      final handle = ioHandler(failing, sendLegacyErrorFrame: true);
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen(handle);
      _streamError(
        await streamBody('http://127.0.0.1:${server!.port}/failing'),
        legacy: true,
      );
    });

    for (final legacy in [false, true]) {
      test('the client reports the server error '
          '(${legacy ? 'legacy error:' : 'data:'} frame)', () async {
        server = await (GenkitRouter(
          sendLegacyErrorFrame: legacy,
        )..addAction(failing)).serve(port: 0);

        final action = defineRemoteAction(
          url: 'http://127.0.0.1:${server!.port}/failing',
          outputSchema: .string(),
          streamSchema: .string(),
        );
        final stream = action.stream(input: 'x');
        final chunks = <String>[];
        await expectLater(
          () async {
            await for (final chunk in stream) {
              chunks.add(chunk);
            }
          }(),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              'Bad input',
            ),
          ),
        );
        expect(chunks, ['partial']);
      });
    }

    test(
      'an `error` field in user data is not mistaken for an error',
      () async {
        final tricky = ai.defineFlow(
          name: 'tricky',
          fn: (String _, ctx) async {
            ctx.sendChunk({'error': 'chunk field'});
            return {'error': 'result field', 'ok': true};
          },
        );
        server = await (GenkitRouter()..addAction(tricky)).serve(port: 0);

        final action = defineRemoteAction(
          url: 'http://127.0.0.1:${server!.port}/tricky',
        );
        final stream = action.stream(input: 'x');
        expect(await stream.toList(), [
          {'error': 'chunk field'},
        ]);
        expect(await stream.onResult, {'error': 'result field', 'ok': true});
      },
    );
  });

  test('Unary flow hides non-Genkit exception details', () async {
    final hiddenErrorFlow = ai.defineFlow(
      name: 'hiddenUnaryError',
      fn: (input, _) async {
        throw Exception('sensitive: db-password');
      },
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(hiddenErrorFlow)).serve(port: 0);
    port = server!.port;

    final response = await http.post(
      Uri.parse('http://localhost:$port/hiddenUnaryError'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': 'hello'}),
    );

    expect(response.statusCode, 500);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['code'], 500);
    expect(body['status'], 'INTERNAL');
    expect(body['message'], 'Internal server error');
    expect(body['message'], isNot(contains('db-password')));
  });

  test('Streaming flow hides non-Genkit exception details', () async {
    final hiddenStreamErrorFlow = ai.defineFlow(
      name: 'hiddenStreamError',
      fn: (input, _) async {
        throw Exception('sensitive: service-account-key');
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(hiddenStreamErrorFlow)).serve(
      port: 0,
    );
    port = server!.port;

    final client = http.Client();
    addTearDown(client.close);

    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:$port/hiddenStreamError?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({'data': 'hello'});

    final response = await client.send(request);
    expect(response.statusCode, 200);

    final error = _streamError(await response.stream.bytesToString());

    expect(error['code'], 500);
    expect(error['status'], 'INTERNAL');
    expect(error['message'], 'Internal server error');
    expect(error['message'], isNot(contains('service-account-key')));
  });

  group('actionHandler', () {
    late Flow<String, String, void, void> echoFlow;
    setUp(() {
      echoFlow = ai.defineFlow(
        name: 'echo',
        fn: (input, _) async => 'Echo: $input',
        inputSchema: .string(),
        outputSchema: .string(),
      );
    });

    GenkitHttpRequest post(
      Object? data, {
      Map<String, String> headers = const {},
    }) => GenkitHttpRequest(
      method: 'POST',
      path: '/echo',
      headers: headers,
      body: Stream.value(utf8.encode(jsonEncode({'data': data}))),
    );

    test('runs without a server', () async {
      final response = await actionHandler(echoFlow)(post('direct'));

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/json');
      expect(
        await utf8.decodeStream(response.body),
        '{"result":"Echo: direct"}',
      );
    });

    test('rejects non-POST requests with 405', () async {
      final response = await actionHandler(echoFlow)(
        GenkitHttpRequest(method: 'GET', path: '/echo'),
      );

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'POST');
    });

    test('rejects a body without "data" with 400', () async {
      final response = await actionHandler(echoFlow)(
        GenkitHttpRequest(
          method: 'POST',
          path: '/echo',
          body: Stream.value(utf8.encode('{"input": "x"}')),
        ),
      );

      expect(response.statusCode, 400);
      final body =
          jsonDecode(await utf8.decodeStream(response.body))
              as Map<String, dynamic>;
      expect(body['status'], 'INVALID_ARGUMENT');
    });

    test(
      'hands the context provider lowercased headers and parsed input',
      () async {
        RequestData? seen;
        final handler = actionHandler(
          echoFlow,
          contextProvider: (request) {
            seen = request;
            return {};
          },
        );

        await handler(post('hi', headers: {'Authorization': 'Bearer x'}));

        expect(seen!.method, 'POST');
        expect(seen!.headers['authorization'], 'Bearer x');
        expect(seen!.input, 'hi');
      },
    );

    test(
      'maps a GenkitException from the context provider to its status',
      () async {
        final handler = actionHandler(
          echoFlow,
          contextProvider: (_) => throw GenkitException(
            'Unauthorized',
            status: StatusCode.unauthenticated,
          ),
        );

        final response = await handler(post('hi'));

        expect(response.statusCode, 401);
        final body = jsonDecode(await utf8.decodeStream(response.body));
        expect(body, {
          'code': 401,
          'status': 'UNAUTHENTICATED',
          'message': 'Unauthorized',
        });
      },
    );

    test('maps any other context provider error to 403', () async {
      final handler = actionHandler(
        echoFlow,
        contextProvider: (_) => throw Exception('no token'),
      );

      expect((await handler(post('hi'))).statusCode, 403);
    });

    test('hides non-Genkit context provider error details', () async {
      final handler = actionHandler(
        echoFlow,
        contextProvider: (_) =>
            throw Exception('JWKS fetch failed for kid=abc123 at db.internal'),
      );

      final response = await handler(post('hi'));

      expect(jsonDecode(await utf8.decodeStream(response.body)), {
        'code': 403,
        'status': 'PERMISSION_DENIED',
        'message': 'Permission denied',
      });
    });

    test('cancels a streaming run when the client goes away', () async {
      final started = Completer<void>();
      final cancelled = Completer<Object?>();
      final endless = ai.defineFlow(
        name: 'endless',
        fn: (String _, ctx) async {
          ctx.cancel!.onCancel(() => cancelled.complete(ctx.cancel!.reason));
          ctx.sendChunk('tick');
          started.complete();
          await ctx.cancel!.whenCancelled;
          ctx.cancel!.throwIfCancelled();
          return 'unreachable';
        },
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
      );

      final response = await actionHandler(endless)(
        GenkitHttpRequest(
          method: 'POST',
          path: '/endless',
          queryParameters: {'stream': 'true'},
          body: Stream.value(utf8.encode(jsonEncode({'data': 'go'}))),
        ),
      );
      // What an adapter does when the client disconnects: drop the body.
      final subscription = response.body.listen((_) {});
      await started.future;
      await subscription.cancel();

      expect(
        await cancelled.future.timeout(const Duration(seconds: 5)),
        'Client disconnected',
      );
    });
  });

  test('a dropped dart:io connection cancels the streaming run', () async {
    final started = Completer<void>();
    final cancelled = Completer<void>();
    final endless = ai.defineFlow(
      name: 'endless',
      fn: (String _, ctx) async {
        ctx.cancel!.onCancel(cancelled.complete);
        // Keep chunks flowing so the server notices the closed socket.
        while (!ctx.cancel!.isCancelled) {
          ctx.sendChunk('tick');
          if (!started.isCompleted) started.complete();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        ctx.cancel!.throwIfCancelled();
        return 'unreachable';
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );
    server = await (GenkitRouter()..addAction(endless)).serve(
      host: InternetAddress.loopbackIPv4,
      port: 0,
    );

    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server!.port}/endless?stream=true'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'data': 'go'}));
    final response = await request.close();
    response.listen((_) {});
    await started.future;
    client.close(force: true);

    await cancelled.future.timeout(const Duration(seconds: 5));
  });

  test('ioHandler serves a single action on a raw dart:io server', () async {
    final echoFlow = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputSchema: .string(),
      outputSchema: .string(),
    );
    final handleEcho = ioHandler(echoFlow);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((request) async {
      if (request.uri.path == '/custom/echo') {
        await handleEcho(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://127.0.0.1:$port/custom/echo',
      outputSchema: .string(),
    );
    expect(await action(input: 'io'), 'Echo: io');
    final missing = await http.post(Uri.parse('http://127.0.0.1:$port/echo'));
    expect(missing.statusCode, 404);
  });

  test('Client using SchemanticType', () async {
    final echoFlow = ai.defineFlow(
      name: 'echoType',
      fn: (input, _) async => 'Echo: $input',
      inputSchema: .string(),
      outputSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(echoFlow)).serve(port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/echoType',
      outputSchema: .string(),
    );

    final result = await action(input: 'typed');
    expect(result, 'Echo: typed');
  });

  test('Client using Schema types and Streaming', () async {
    final complexStreamFlow = ai.defineFlow(
      name: 'complexStream',
      fn: (input, ctx) async {
        ctx.sendChunk(HandlerTestStream(chunk: 'chunk1'));
        await Future.delayed(const Duration(milliseconds: 10));
        ctx.sendChunk(HandlerTestStream(chunk: 'chunk2'));
        return HandlerTestOutput(greeting: 'done');
      },
      inputSchema: .string(),
      outputSchema: HandlerTestOutput.$schema,
      streamSchema: HandlerTestStream.$schema,
    );

    server = await (GenkitRouter()..addAction(complexStreamFlow)).serve(
      port: 0,
    );
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/complexStream',
      outputSchema: HandlerTestOutput.$schema,
      streamSchema: HandlerTestStream.$schema,
    );

    final stream = action.stream(input: 'start');
    final chunks = <HandlerTestStream>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    final result = await stream.onResult;

    expect(chunks.length, 2);
    expect(chunks[0].chunk, 'chunk1');
    expect(chunks[1].chunk, 'chunk2');

    expect(result.greeting, 'done');
  });

  test('Streaming flow headers and timing', () async {
    final streamFlow = ai.defineFlow(
      name: 'streamHeaders',
      fn: (input, ctx) async {
        ctx.sendChunk('Chunk 1');
        await Future.delayed(const Duration(milliseconds: 100));
        ctx.sendChunk('Chunk 2');
        return 'Done';
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(streamFlow)).serve(port: 0);
    port = server!.port;

    final client = http.Client();
    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:$port/streamHeaders?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = '{"data": "start"}';

    final response = await client.send(request);

    final chunks = <int>[];
    final start = DateTime.now();
    await response.stream.listen((chunk) {
      chunks.add(DateTime.now().difference(start).inMilliseconds);
    }).asFuture();

    // First chunk should be fast, next should be after ~100ms
    // We expect at least some delay between chunks if streaming works.
    // If buffering, all chunks might arrive at same time > 100ms.
    // Actually, response.stream gives bytes.
    // Let's decode to ensure we get distinctive data chunks.
    // But raw byte chunks arrival time is enough.

    // If buffered, we likely get one big chunk after 100ms.
    // If streaming, we get one chunk immediately (or very fast), then another.

    expect(
      chunks.length,
      greaterThanOrEqualTo(2),
      reason: 'Should receive multiple chunks',
    );
    expect(
      chunks.last,
      greaterThan(80),
      reason: 'Total time should be around 100ms',
    );
    // If buffering happened, chunks.first would probably be ~100ms too (depending on implementation).
    // Better check:
    // If we receive multiple chunks, and the first one is fast (< 50ms) and last is slow (> 80ms), then we streamed.
    // If we receive only 1 chunk, or all chunks > 80ms, then we buffered.

    // Headers may arrive before the body.
    // checking first chunk time.
    expect(
      chunks.first,
      lessThan(80),
      reason: 'First chunk should arrive quickly',
    );
  });

  test(
    'Streaming flow surfaces trace/span headers when instrumented',
    () async {
      configureInstrumentation(
        _FakeInstrumentation(traceId: 'trace-abc', spanId: 'span-xyz'),
      );

      final streamFlow = ai.defineFlow(
        name: 'streamTraced',
        fn: (input, ctx) async {
          ctx.sendChunk('Chunk 1');
          return 'Done';
        },
        inputSchema: .string(),
        outputSchema: .string(),
        streamSchema: .string(),
      );

      server = await (GenkitRouter()..addAction(streamFlow)).serve(port: 0);
      port = server!.port;

      final client = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse('http://localhost:$port/streamTraced?stream=true'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = '{"data": "start"}';

      final response = await client.send(request);
      // Drain the stream so the server can complete cleanly.
      await response.stream.drain<void>();

      expect(response.headers['x-genkit-trace-id'], 'trace-abc');
      expect(response.headers['x-genkit-span-id'], 'span-xyz');
    },
  );

  test('Streaming flow omits trace headers when uninstrumented', () async {
    final streamFlow = ai.defineFlow(
      name: 'streamUntraced',
      fn: (input, ctx) async {
        ctx.sendChunk('Chunk 1');
        return 'Done';
      },
      inputSchema: .string(),
      outputSchema: .string(),
      streamSchema: .string(),
    );

    server = await (GenkitRouter()..addAction(streamFlow)).serve(port: 0);
    port = server!.port;

    final client = http.Client();
    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:$port/streamUntraced?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = '{"data": "start"}';

    final response = await client.send(request);
    await response.stream.drain<void>();

    expect(response.headers.containsKey('x-genkit-trace-id'), isFalse);
    expect(response.headers.containsKey('x-genkit-span-id'), isFalse);
    // Same as Go and Python servers.
    expect(response.headers['content-type'], 'text/event-stream');
    expect(response.headers['cache-control'], 'no-cache');
  });

  test(
    'Streaming does not wait for onTraceStart when it never fires',
    () async {
      server = await (GenkitRouter()..addAction(_NoTraceAction())).serve(
        port: 0,
      );
      port = server!.port;

      final action = defineRemoteAction(
        url: 'http://localhost:$port/noTrace',
        fromResponse: (data) => data as String,
        fromStreamChunk: (data) => data as String,
      );

      final stream = action.stream(input: 'x');
      expect(await stream.toList(), ['chunk']);
      expect(await stream.onResult, 'done x');
    },
    timeout: const Timeout(Duration(seconds: 5)),
  );

  test('Remote model', () async {
    final myModel = ai.defineModel(
      name: 'my-model',
      fn: (request, context) async {
        if (context.streamingRequested) {
          context.sendChunk(
            ModelResponseChunk(content: [TextPart(text: 'remote chunk')]),
          );
        }
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'hello from model')],
          ),
        );
      },
    );

    server = await (GenkitRouter()..addAction(myModel)).serve(port: 0);
    port = server!.port;

    final remoteModel = ai.defineRemoteModel(
      name: 'remote-model',
      url: 'http://localhost:$port/my-model',
    );

    // Unary
    final response = await ai.generate(model: remoteModel, prompt: 'hi');
    expect(response.text, 'hello from model');

    // Streaming
    final receivedChunks = <String>[];
    final streamResponse = await ai.generate(
      model: remoteModel,
      prompt: 'hi',
      onChunk: (c) => receivedChunks.add(c.text),
    );

    expect(receivedChunks, ['remote chunk']);
    expect(streamResponse.text, 'hello from model');
  });
}
