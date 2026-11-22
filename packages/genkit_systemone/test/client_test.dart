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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/src/protocol/client.dart';
import 'package:genkit_systemone/src/protocol/questions.dart';
import 'package:genkit_systemone/src/protocol/state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http_parser/http_parser.dart' show formatHttpDate;
import 'package:test/test.dart';

const _answer =
    '{"model":"jev-1.13.0","answers":{"u":{"type":"noul","noul":0.5}},'
    '"usage":{"input_tokens":3,"output_tokens":1}}';

DecideRequest request({Map<String, Object?>? extra}) => DecideRequest(
  state: 'ticket',
  media: RequestMedia(),
  questions: {'u': WireQuestion(type: kindNoul, instructions: 'Urgent?')},
  extra: extra,
);

/// A client over [handler] that records the delays it would have slept.
(DecideClient, List<Duration>) clientFor(
  Future<http.Response> Function(http.Request) handler, {
  Endpoint? endpoint,
  Sleep? sleep,
}) {
  final delays = <Duration>[];
  final client = DecideClient(
    httpClient: MockClient(handler),
    baseUrl: 'https://decisions.test',
    apiKey: 'key',
    headers: {'X-Trace': 'abc'},
    endpoint:
        endpoint ??
        Endpoint(name: 'test', path: '/v1/systemone', modelsPath: '/models'),
    sleep:
        sleep ??
        (d) async {
          delays.add(d);
        },
  );
  return (client, delays);
}

void main() {
  test('posts the native body with the key and the headers', () async {
    late http.Request seen;
    final (client, _) = clientFor((req) async {
      seen = req;
      return http.Response(_answer, 200);
    });
    final resp = await client.decide(
      'jev-1.13.0',
      request(extra: {'session_id': 's1', 'model': 'other'}),
    );
    expect(seen.url.toString(), 'https://decisions.test/v1/systemone');
    expect(seen.headers['Authorization'], 'Bearer key');
    expect(seen.headers['X-Trace'], 'abc');
    expect(seen.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(seen.body), {
      'session_id': 's1',
      'model': 'jev-1.13.0',
      'state': 'ticket',
      'questions': {
        'u': {'type': 'noul', 'instructions': 'Urgent?'},
      },
    });
    expect(resp.model, 'jev-1.13.0');
    expect(resp.inputTokens, 3);
    expect(resp.answers['u'], {'type': 'noul', 'noul': 0.5});
  });

  test('retries a server error twice, honoring Retry-After', () async {
    var calls = 0;
    final (client, delays) = clientFor((req) async {
      calls++;
      if (calls == 1) {
        return http.Response('busy', 503, headers: {'retry-after': '3'});
      }
      if (calls == 2) return http.Response('', 429);
      return http.Response(_answer, 200);
    });
    await client.decide('m', request());
    expect(calls, 3);
    expect(delays[0], const Duration(seconds: 3));
    // The second backoff is a second, less up to a quarter of jitter.
    expect(delays[1].inMilliseconds, inInclusiveRange(750, 1000));
  });

  test('gives up after two retries with the last status', () async {
    var calls = 0;
    final (client, _) = clientFor((req) async {
      calls++;
      return http.Response('{"error":{"message":"down"}}', 502);
    });
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.unavailable)
            .having((e) => e.message, 'message', 'test: HTTP 502: down'),
      ),
    );
    expect(calls, 3);
  });

  test('a connection failure is retried as unavailable', () async {
    var calls = 0;
    final (client, _) = clientFor((req) async {
      calls++;
      throw http.ClientException('connection refused');
    });
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.unavailable,
        ),
      ),
    );
    expect(calls, 3);
  });

  test('a client error is not retried', () async {
    var calls = 0;
    final (client, _) = clientFor((req) async {
      calls++;
      return http.Response('{"message":"bad question"}', 400);
    });
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.invalidArgument)
            .having((e) => e.message, 'message', contains('bad question')),
      ),
    );
    expect(calls, 1);
  });

  test('a cancel during the wait stops the retries', () async {
    final controller = CancellationController();
    final wait = Completer<void>();
    var calls = 0;
    final (client, _) = clientFor((req) async {
      calls++;
      return http.Response('', 503);
    }, sleep: (_) => wait.future);
    final call = client.decide('m', request(), cancel: controller.token);
    await Future<void>.delayed(Duration.zero);
    controller.cancel('caller gave up');
    await expectLater(
      call,
      throwsA(
        isA<CancelledException>().having(
          (e) => e.message,
          'message',
          allOf(contains('caller gave up'), contains('HTTP 503')),
        ),
      ),
    );
    expect(calls, 1);
  });

  test('a cancel mid-request wins on a client that cannot abort', () async {
    final controller = CancellationController();
    final (client, _) = clientFor((req) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      return http.Response(_answer, 200);
    });
    final watch = Stopwatch()..start();
    final call = client.decide('m', request(), cancel: controller.token);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.cancel('caller gave up');
    await expectLater(
      call,
      throwsA(
        isA<CancelledException>().having(
          (e) => e.message,
          'message',
          'caller gave up',
        ),
      ),
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('a timeout bounds an attempt, and is retried', () async {
    var calls = 0;
    final client = DecideClient(
      httpClient: MockClient((req) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(_answer, 200);
      }),
      baseUrl: 'https://decisions.test',
      endpoint: Endpoint(name: 'test', path: ''),
      timeout: const Duration(milliseconds: 20),
      sleep: (_) async {},
    );
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.unavailable)
            .having((e) => e.message, 'message', contains('no response')),
      ),
    );
    expect(calls, 3);
  });

  test('Retry-After is capped at 30 seconds', () async {
    var calls = 0;
    final (client, delays) = clientFor((req) async {
      calls++;
      if (calls == 1) {
        return http.Response('', 503, headers: {'retry-after': '120'});
      }
      return http.Response(_answer, 200);
    });
    await client.decide('m', request());
    expect(delays, [const Duration(seconds: 30)]);
  });

  test('a usage count missing or not a number is null, not 0', () async {
    final (client, _) = clientFor(
      (req) async => http.Response(
        '{"model":"m","answers":{},"usage":{"input_tokens":"312","cost":"x"}}',
        200,
      ),
    );
    final resp = await client.decide('m', request());
    expect(resp.inputTokens, isNull);
    expect(resp.outputTokens, isNull);
    expect(resp.cost, isNull);
  });

  group('a response that is not an answer is INTERNAL', () {
    for (final (what, body, message) in [
      ('not JSON', 'oops', 'response is not a System One answer'),
      ('not an object', '[1, 2]', 'not an object'),
      (
        'answers not an object of objects',
        '{"answers": {"u": 1}}',
        'answers is not an object of answers',
      ),
    ]) {
      test(what, () async {
        final (client, _) = clientFor((req) async => http.Response(body, 200));
        await expectLater(
          client.decide('m', request()),
          throwsA(
            isA<GenkitException>()
                .having((e) => e.status, 'status', StatusCode.internal)
                .having((e) => e.message, 'message', contains(message)),
          ),
        );
      });
    }
  });

  test('a request with no JSON form is INVALID_ARGUMENT', () async {
    final cyclic = <String, Object?>{};
    cyclic['self'] = cyclic;
    for (final extra in <Map<String, Object?>>[
      {'trace': cyclic},
      {'trace': Object()},
    ]) {
      final (client, _) = clientFor((req) async => http.Response(_answer, 200));
      await expectLater(
        client.decide('m', request(extra: extra)),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.invalidArgument)
              .having((e) => e.message, 'message', contains('not JSON')),
        ),
      );
    }
  });

  group('a route', () {
    Future<void> expectRoute(
      RouteFn route,
      StatusCode status,
      Object message,
    ) async {
      var calls = 0;
      final (client, _) = clientFor((req) async {
        calls++;
        return http.Response(_answer, 200);
      }, endpoint: Endpoint(name: 'routed', path: '', route: route));
      await expectLater(
        client.decide('m', request()),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', status)
              .having((e) => e.message, 'message', message),
        ),
      );
      expect(calls, 0);
    }

    test('that throws a GenkitException is reported as it is', () async {
      await expectRoute(
        (_, _) => throw GenkitException('no', status: StatusCode.notFound),
        StatusCode.notFound,
        'no',
      );
    });

    test('that throws anything else is UNKNOWN under the provider', () async {
      await expectRoute(
        (_, _) => throw StateError('bad route'),
        StatusCode.unknown,
        allOf(startsWith('routed: '), contains('bad route')),
      );
    });

    test('that returns no body is INVALID_ARGUMENT', () async {
      await expectRoute(
        (_, _) => (path: '/x', body: null),
        StatusCode.invalidArgument,
        'routed: the route returned no body',
      );
    });
  });

  test('a server message is cut at 500 characters', () {
    final error = httpError('test', 400, jsonEncode({'message': 'z' * 900}));
    expect(error.message, 'test: HTTP 400: ${'z' * 500}...');
  });

  group('status mapping', () {
    for (final (code, status) in [
      (401, StatusCode.unauthenticated),
      (402, StatusCode.resourceExhausted),
      (404, StatusCode.notFound),
      (408, StatusCode.deadlineExceeded),
      (422, StatusCode.invalidArgument),
      (429, StatusCode.resourceExhausted),
      (500, StatusCode.internal),
      (501, StatusCode.unimplemented),
      (502, StatusCode.unavailable),
      (503, StatusCode.unavailable),
      (504, StatusCode.deadlineExceeded),
      (505, StatusCode.unimplemented),
      (524, StatusCode.deadlineExceeded),
    ]) {
      test('$code is ${status.wireName}', () {
        expect(httpError('test', code, '').status, status);
      });
    }

    for (final code in [501, 505]) {
      test('$code is not retried', () async {
        var calls = 0;
        final (client, _) = clientFor((req) async {
          calls++;
          return http.Response('', code);
        });
        await expectLater(
          client.decide('m', request()),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCode.unimplemented,
            ),
          ),
        );
        expect(calls, 1);
      });
    }
  });

  group('error messages', () {
    test('read every shape the endpoints use', () {
      expect(errorMessage('{"error":{"message":"nested"}}'), 'nested');
      expect(errorMessage('{"error":"flat"}'), 'flat');
      expect(errorMessage('{"message":"top"}'), 'top');
      expect(
        errorMessage('{"errors":[{"code":7000,"message":"No route"}]}'),
        'No route',
      );
      expect(
        errorMessage(
          '{"detail":[{"loc":["body","questions"],"msg":"field required"}]}',
        ),
        'body.questions: field required',
      );
      expect(
        errorMessage(
          '[{"path":["questions","u"],"message":"bad"},{"message":"worse"}]',
        ),
        'questions.u: bad; worse',
      );
      expect(errorMessage('{"detail":"just text"}'), 'just text');
      expect(errorMessage('plain text'), 'plain text');
      expect(errorMessage('x' * 300), '${'x' * 200}...');
      expect(errorMessage(''), '');
    });

    test('an empty body is named by its status', () {
      expect(httpError('test', 404, '').message, 'test: HTTP 404: Not Found');
    });
  });

  group('responses', () {
    test('a response with no answers is an internal error', () async {
      final (client, _) = clientFor(
        (req) async => http.Response('{"model":"m"}', 200),
      );
      await expectLater(
        client.decide('m', request()),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.internal)
              .having((e) => e.message, 'message', contains('no answers')),
        ),
      );
    });

    test('an unwrap error keeps its status, or is unknown', () async {
      Future<void> expectUnwrap(Object error, StatusCode status) async {
        final (client, _) = clientFor(
          (req) async => http.Response('{}', 200),
          endpoint: Endpoint(
            name: 'wrapped',
            path: '',
            // An unwrap hook may throw anything.
            // ignore: only_throw_errors
            unwrap: (_) => throw error,
          ),
        );
        await expectLater(
          client.decide('m', request()),
          throwsA(
            isA<GenkitException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.message, 'message', startsWith('wrapped: ')),
          ),
        );
      }

      await expectUnwrap(StateError('envelope'), StatusCode.unknown);
      await expectUnwrap(
        GenkitException('quota', status: StatusCode.resourceExhausted),
        StatusCode.resourceExhausted,
      );
    });

    test('a route builds the path and body', () async {
      late http.Request seen;
      final (client, _) = clientFor(
        (req) async {
          seen = req;
          return http.Response(_answer, 200);
        },
        endpoint: Endpoint(
          name: 'routed',
          path: '/run',
          route: (model, body) {
            body.remove('model');
            return (path: model, body: {'input': body});
          },
        ),
      );
      await client.decide('clef', request());
      expect(seen.url.path, '/run/clef');
      expect((jsonDecode(seen.body) as Map).keys, ['input']);
    });
  });

  group('listing', () {
    for (final (shape, body) in [
      ('bare array', '[{"name":"jev-1.13.0"},{"name":"jev-latest"}]'),
      (
        'models envelope',
        '{"models":[{"name":"jev-1.13.0"},{"id":"jev-latest","name":"Jev"}]}',
      ),
      ('data envelope', '{"data":[{"id":"jev-1.13.0"},{"id":"jev-latest"}]}'),
    ]) {
      test('reads a $shape', () async {
        final (client, _) = clientFor((req) async => http.Response(body, 200));
        final models = await client.listModels();
        expect(models.map((m) => m.model), ['jev-1.13.0', 'jev-latest']);
      });
    }

    test('fails once with no retries', () async {
      var calls = 0;
      final (client, _) = clientFor((req) async {
        calls++;
        return http.Response('', 503);
      });
      await expectLater(client.listModels(), throwsA(isA<GenkitException>()));
      expect(calls, 1);
    });
  });

  test('a redirect is not followed, and not retried', () async {
    var calls = 0;
    late http.BaseRequest seen;
    final (client, _) = clientFor((req) async {
      calls++;
      seen = req;
      return http.Response(
        '',
        302,
        headers: {'location': 'https://elsewhere.test'},
      );
    });
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.failedPrecondition)
            .having(
              (e) => e.message,
              'message',
              'test: HTTP 302: the server redirects, and redirects are not '
                  'followed; set the base URL to the final one',
            ),
      ),
    );
    expect(seen.followRedirects, isFalse);
    expect(calls, 1);
  });

  test('a response over 8 MiB is refused, not cut', () async {
    final (client, _) = clientFor(
      (req) async => http.Response('x' * ((8 << 20) + 1), 200),
    );
    await expectLater(
      client.decide('m', request()),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.internal)
            .having(
              (e) => e.message,
              'message',
              'test: response is larger than 8388608 bytes',
            ),
      ),
    );
  });

  test(
    'an Error in the client is a bug: not retried, not UNAVAILABLE',
    () async {
      var calls = 0;
      final (client, _) = clientFor((req) async {
        calls++;
        throw ArgumentError('broken client');
      });
      await expectLater(client.decide('m', request()), throwsArgumentError);
      expect(calls, 1);
    },
  );

  test('an error body is cut to 200 characters in details', () {
    final error = httpError('test', 400, 'y' * 500);
    expect(error.details, '${'y' * 200}...');
  });

  test('Retry-After reads seconds and dates', () {
    expect(parseRetryAfter('0'), Duration.zero);
    expect(parseRetryAfter('12'), const Duration(seconds: 12));
    expect(parseRetryAfter('Wed, 21 Oct 2015 07:28:00 GMT'), Duration.zero);
    expect(parseRetryAfter('soon'), isNull);
    expect(parseRetryAfter('-5'), isNull);
    expect(
      parseRetryAfter('99999999999999999999999'),
      const Duration(hours: 1),
    );
    final soon = formatHttpDate(DateTime.now().add(const Duration(seconds: 2)));
    expect(
      parseRetryAfter(soon),
      allOf(
        greaterThan(Duration.zero),
        lessThanOrEqualTo(const Duration(seconds: 3)),
      ),
    );
    expect(parseRetryAfter(null), isNull);
  });
}
