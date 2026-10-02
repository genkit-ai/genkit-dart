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
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_google_genai/src/api_client.dart' show parseGoogleError;
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

String _errorBody(int code, String status, {List<Object>? details}) =>
    jsonEncode({
      'error': {
        'code': code,
        'message': 'boom',
        'status': status,
        'details': ?details,
      },
    });

const _retryInfo = {
  '@type': 'type.googleapis.com/google.rpc.RetryInfo',
  'retryDelay': '37s',
};

/// Serves every generateContent call from [handler].
class _ErrorPlugin extends GoogleGenAiPluginImpl {
  _ErrorPlugin(this.handler) : super(apiKey: 'test-key');

  final Future<http.Response> Function(http.Request) handler;

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async => GenerativeLanguageBaseClient(
    baseUrl: 'https://example.test/',
    client: MockClient(handler),
  );
}

void main() {
  group('parseGoogleError', () {
    test('reads retryAfter from google.rpc.RetryInfo', () {
      final e = parseGoogleError(
        429,
        _errorBody(429, 'RESOURCE_EXHAUSTED', details: [_retryInfo]),
      );
      expect(e.status, StatusCode.resourceExhausted);
      expect(e.retryAfter, const Duration(seconds: 37));
    });

    test('parses fractional RetryInfo delays', () {
      final e = parseGoogleError(
        429,
        _errorBody(
          429,
          'RESOURCE_EXHAUSTED',
          details: [
            {..._retryInfo, 'retryDelay': '1.25s'},
          ],
        ),
      );
      expect(e.retryAfter, const Duration(milliseconds: 1250));
    });

    test('prefers the Retry-After header over RetryInfo', () {
      final e = parseGoogleError(
        429,
        _errorBody(429, 'RESOURCE_EXHAUSTED', details: [_retryInfo]),
        {'retry-after': '5'},
      );
      expect(e.retryAfter, const Duration(seconds: 5));
    });

    test('matches the Retry-After header case-insensitively', () {
      final e = parseGoogleError(503, 'Service Unavailable', {
        'Retry-After': '4',
      });
      expect(e.retryAfter, const Duration(seconds: 4));
    });

    test('reads Retry-After for a non-JSON body', () {
      final e = parseGoogleError(503, 'Service Unavailable', {
        'retry-after': '2',
      });
      expect(e.status, StatusCode.unavailable);
      expect(e.retryAfter, const Duration(seconds: 2));
    });

    test('no hint means no retryAfter', () {
      final e = parseGoogleError(
        429,
        _errorBody(
          429,
          'RESOURCE_EXHAUSTED',
          details: [
            {'@type': 'type.googleapis.com/google.rpc.Help', 'links': []},
          ],
        ),
      );
      expect(e.retryAfter, isNull);
    });

    test('maps 503 and 504 to retryable statuses', () {
      expect(
        parseGoogleError(503, _errorBody(503, 'UNAVAILABLE')).status,
        StatusCode.unavailable,
      );
      expect(
        parseGoogleError(504, _errorBody(504, 'DEADLINE_EXCEEDED')).status,
        StatusCode.deadlineExceeded,
      );
      // HTTP code alone, no status string in the body.
      expect(
        parseGoogleError(503, '{"error": {"message": "x"}}').status,
        StatusCode.unavailable,
      );
    });

    test('keeps the existing mappings', () {
      expect(
        parseGoogleError(400, _errorBody(400, 'INVALID_ARGUMENT')).status,
        StatusCode.invalidArgument,
      );
      expect(
        parseGoogleError(403, _errorBody(403, 'PERMISSION_DENIED')).status,
        StatusCode.permissionDenied,
      );
      expect(
        parseGoogleError(500, _errorBody(500, 'INTERNAL')).status,
        StatusCode.internal,
      );
    });
  });

  test('a 429 with a retry hint reaches the model caller', () async {
    final plugin = _ErrorPlugin(
      (request) async => http.Response(
        _errorBody(429, 'RESOURCE_EXHAUSTED'),
        429,
        headers: {'content-type': 'application/json', 'retry-after': '3'},
      ),
    );
    final model = plugin.resolve(.model, 'gemini-flash-latest') as Model;

    await expectLater(
      model(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hi')],
            ),
          ],
        ),
      ),
      throwsA(
        isA<GenkitException>()
            .having((e) => e.status, 'status', StatusCode.resourceExhausted)
            .having(
              (e) => e.retryAfter,
              'retryAfter',
              const Duration(seconds: 3),
            ),
      ),
    );
  });
}
