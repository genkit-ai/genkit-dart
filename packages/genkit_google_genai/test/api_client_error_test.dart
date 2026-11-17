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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A client whose every request fails with [httpStatus] and [body].
GenerativeLanguageBaseClient _failingClient(int httpStatus, String body) {
  return GenerativeLanguageBaseClient(
    baseUrl: 'https://example.test/',
    client: MockClient((_) async => http.Response(body, httpStatus)),
  );
}

String _googleError(String? status, {String message = 'boom'}) => jsonEncode({
  'error': {'code': 0, 'message': message, 'status': ?status},
});

Future<GenkitException> _errorFor(int httpStatus, String body) async {
  try {
    await _failingClient(httpStatus, body).listModels();
  } on GenkitException catch (e) {
    return e;
  }
  fail('expected a GenkitException');
}

Future<GenkitException> _streamErrorFor(int httpStatus, String body) async {
  try {
    await _failingClient(httpStatus, body)
        .streamGenerateContent(GenerateContentRequest(), model: 'models/m')
        .drain<void>();
  } on GenkitException catch (e) {
    return e;
  }
  fail('expected a GenkitException');
}

void main() {
  group('Google API error mapping', () {
    test('uses the gRPC status from the error body', () async {
      final e = await _errorFor(503, _googleError('UNAVAILABLE'));
      expect(e.status, StatusCode.unavailable);
      expect(e.message, 'Google AI Error: boom');
    });

    test('gRPC status wins over a shared HTTP status', () async {
      // 400 alone would map to invalidArgument.
      final e = await _errorFor(400, _googleError('FAILED_PRECONDITION'));
      expect(e.status, StatusCode.failedPrecondition);
    });

    test('falls back to the HTTP status without a gRPC status', () async {
      expect(
        (await _errorFor(429, _googleError(null))).status,
        StatusCode.resourceExhausted,
      );
      expect(
        (await _errorFor(504, _googleError(null))).status,
        StatusCode.deadlineExceeded,
      );
    });

    test(
      'falls back to the HTTP status for unrecognized gRPC status',
      () async {
        final e = await _errorFor(404, _googleError('SOMETHING_NEW'));
        expect(e.status, StatusCode.notFound);
      },
    );

    test('never reports ok or unknown for an error', () async {
      expect(
        (await _errorFor(502, _googleError('OK'))).status,
        StatusCode.internal,
      );
      expect(
        (await _errorFor(502, _googleError('UNKNOWN'))).status,
        StatusCode.internal,
      );
    });

    test('maps the HTTP status when the body is not a Google error', () async {
      final e = await _errorFor(503, '<html>Service Unavailable</html>');
      expect(e.status, StatusCode.unavailable);
      expect(e.message, startsWith('API Error 503'));
    });

    test('applies the same mapping to streaming calls', () async {
      final e = await _streamErrorFor(403, _googleError('PERMISSION_DENIED'));
      expect(e.status, StatusCode.permissionDenied);
    });
  });

  group('error details (JS detail: the whole error body)', () {
    final body = {
      'error': {
        'code': 400,
        'message': 'boom',
        'status': 'INVALID_ARGUMENT',
        'details': [
          {
            '@type': 'type.googleapis.com/google.rpc.BadRequest',
            'fieldViolations': [
              {'field': 'contents', 'description': 'empty'},
            ],
          },
        ],
      },
    };

    test('keeps a Google error body, including its details', () async {
      final e = await _errorFor(400, jsonEncode(body));
      expect(jsonDecode(e.details!), body);
    });

    test('drops the list wrapping of an Interactions error body', () async {
      final e = await _errorFor(400, jsonEncode([body]));
      expect(jsonDecode(e.details!), body);
    });

    test('has none when the body is not a Google error', () async {
      final e = await _errorFor(503, '<html>Service Unavailable</html>');
      expect(e.details, isNull);
      expect(e.message, contains('<html>'));
    });

    test('a streaming call keeps the body too', () async {
      final e = await _streamErrorFor(400, jsonEncode(body));
      expect(jsonDecode(e.details!), body);
    });

    test('an error body sent in a stream with a 200 keeps it too', () async {
      final e = await _streamErrorFor(200, jsonEncode(body));
      expect(e.status, StatusCode.invalidArgument);
      expect(jsonDecode(e.details!), body);
    });
  });

  group('streamGenerateContent body (as JS processStream)', () {
    /// Streams [body] (sent with a 200) and returns the chunks' text.
    Future<List<String?>> texts(String body) => _failingClient(200, body)
        .streamGenerateContent(GenerateContentRequest(), model: 'models/m')
        .map((r) => r.candidates?.first.content?.parts?.first.text)
        .toList();

    String chunk(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    });

    test('reads data: lines and skips blank lines, SSE fields and the '
        'array brackets', () async {
      expect(
        await texts(
          ': comment\nevent: message\nid: 1\nretry: 10\n[\n'
          'data: ${chunk('a')}\n\n,\ndata:${chunk('b')}\n\n]\n',
        ),
        ['a', 'b'],
      );
    });

    test('a data: line that is not JSON throws INTERNAL', () async {
      await expectLater(
        texts('data: ${chunk('a')}\n\ndata: {not json\n\n'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.internal)
              .having(
                (e) => e.message,
                'message',
                'Error parsing JSON response: "{not json"',
              ),
        ),
      );
    });

    test(
      'an error body sent with a 200 keeps its status and message',
      () async {
        // A plain JSON error instead of SSE (e.g. when the API is overloaded,
        // per JS parseStreamErrorText).
        final e = await _streamErrorFor(
          200,
          _googleError('UNAVAILABLE', message: 'The model is overloaded.'),
        );
        expect(e.status, StatusCode.unavailable);
        expect(e.message, 'Google AI Error: The model is overloaded.');
      },
    );

    test('an error body without a gRPC status uses its code', () async {
      final e = await _streamErrorFor(
        200,
        jsonEncode({
          'error': {'code': 429, 'message': 'slow down'},
        }),
      );
      expect(e.status, StatusCode.resourceExhausted);
    });

    test(
      'other leftover text throws INTERNAL, cut to 500 characters',
      () async {
        final page = '<html>${'x' * 600}</html>';
        final e = await _streamErrorFor(200, page);
        expect(e.status, StatusCode.internal);
        expect(
          e.message,
          'Failed to parse stream: ${page.substring(0, 500)}...',
        );
      },
    );
  });
}
