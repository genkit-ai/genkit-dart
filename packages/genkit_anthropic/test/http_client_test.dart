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

/// Delegates to a [MockClient] and records every request and [close] call.
class _TrackingClient extends http.BaseClient {
  final _inner = MockClient(
    (request) async => http.Response(
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
    ),
  );

  final requests = <http.BaseRequest>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return _inner.send(request);
  }

  @override
  void close() => closed = true;
}

ModelRequest _hello({Map<String, dynamic>? config}) => ModelRequest(
  messages: [
    Message(
      role: Role.user,
      content: [TextPart(text: 'hello')],
    ),
  ],
  config: config,
);

void main() {
  group('custom httpClient', () {
    test('the public handle routes requests through it', () async {
      final client = _TrackingClient();
      final genkit = Genkit(
        isDevEnv: false,
        plugins: [anthropic(apiKey: 'test-key', httpClient: client)],
      );
      addTearDown(genkit.shutdown);

      final response = await genkit.generate(
        model: anthropic.model(_model),
        prompt: 'hello',
      );

      expect(response.text, 'ok');
      expect(client.requests.map((r) => r.url.path), contains('/v1/messages'));
    });

    test('is not closed when the plugin is closed', () async {
      final client = _TrackingClient();
      final plugin = AnthropicPluginImpl(
        apiKey: 'test-key',
        httpClient: client,
      );
      final action = plugin.resolve(.model, _model) as Model;

      await action(_hello());
      plugin.close();

      expect(client.closed, isFalse);
    });

    test('is used and not closed for a per-request apiKey', () async {
      final client = _TrackingClient();
      final plugin = AnthropicPluginImpl(
        apiKey: 'test-key',
        httpClient: client,
      );
      addTearDown(plugin.close);
      final action = plugin.resolve(.model, _model) as Model;

      // A per-request key builds a throwaway SDK client that is closed in a
      // `finally`; the caller's http.Client must survive that.
      await action(_hello(config: {'apiKey': 'request-key'}));

      expect(client.requests.single.headers['x-api-key'], 'request-key');
      expect(client.closed, isFalse);
    });
  });
}
