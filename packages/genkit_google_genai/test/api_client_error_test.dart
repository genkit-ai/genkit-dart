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
}
