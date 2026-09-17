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
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _model = 'claude-haiku-4-5';

http.Response _errorResponse(int statusCode, String type, String message) =>
    http.Response(
      jsonEncode({
        'type': 'error',
        'error': {'type': type, 'message': message},
      }),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

http.Response _successResponse() => http.Response(
  jsonEncode({
    'id': 'msg_test',
    'type': 'message',
    'role': 'assistant',
    'model': _model,
    'content': [
      {'type': 'text', 'text': 'ok'},
    ],
    'stop_reason': 'end_turn',
    'stop_sequence': null,
    'usage': {'input_tokens': 1, 'output_tokens': 1},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('Anthropic error mapping', () {
    test('a 529 overloaded response is retried by the default retry '
        'statuses', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        if (request.url.path != '/v1/messages') {
          return http.Response('not found', 404);
        }
        attempts++;
        return attempts == 1
            ? _errorResponse(529, 'overloaded_error', 'Overloaded')
            : _successResponse();
      });
      final genkit = Genkit(
        isDevEnv: false,
        plugins: [
          AnthropicPluginImpl(apiKey: 'test-key', httpClient: client),
          RetryPlugin(),
        ],
      );
      addTearDown(genkit.shutdown);

      final response = await genkit.generate(
        model: anthropic.model(_model),
        prompt: 'hello',
        use: [retry(maxRetries: 1, initialDelayMs: 1, noJitter: true)],
      );

      expect(attempts, 2);
      expect(response.text, 'ok');
    });

    test('a 529 overloaded response surfaces as UNAVAILABLE', () async {
      final client = MockClient(
        (request) async =>
            _errorResponse(529, 'overloaded_error', 'Overloaded'),
      );
      final plugin = AnthropicPluginImpl(
        apiKey: 'test-key',
        httpClient: client,
      );
      addTearDown(plugin.close);
      final action = plugin.resolve(.model, _model) as Model;

      await expectLater(
        action(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.UNAVAILABLE,
          ),
        ),
      );
    });

    test('other HTTP statuses keep the canonical mapping', () async {
      final client = MockClient(
        (request) async => _errorResponse(400, 'invalid_request_error', 'Bad'),
      );
      final plugin = AnthropicPluginImpl(
        apiKey: 'test-key',
        httpClient: client,
      );
      addTearDown(plugin.close);
      final action = plugin.resolve(.model, _model) as Model;

      await expectLater(
        action(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });
  });
}
