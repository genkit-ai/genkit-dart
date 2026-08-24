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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// TODO(#366): consolidate with the wire harness in other wire tests once the
// shared fake-server harness lands.
/// Captures every chat-completions request body the plugin puts on the wire
/// and serves canned OpenAI responses (JSON or SSE for streaming requests).
MockClient wireClient(List<Map<String, dynamic>> capturedBodies) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/chat/completions')) {
      final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
      capturedBodies.add(body);
      if (body['stream'] == true) {
        return http.Response(
          '''
data: {"id":"c1","object":"chat.completion.chunk","created":0,"model":"gpt-4o","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"}}]}

data: {"id":"c1","object":"chat.completion.chunk","created":0,"model":"gpt-4o","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}

data: {"id":"c1","object":"chat.completion.chunk","created":0,"model":"gpt-4o","choices":[],"usage":{"prompt_tokens":15,"completion_tokens":7,"total_tokens":22}}

data: [DONE]

''',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }
      return http.Response(
        jsonEncode({
          'id': 'chatcmpl-test',
          'object': 'chat.completion',
          'created': 0,
          'model': 'gpt-4o',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 15,
            'completion_tokens': 7,
            'total_tokens': 22,
            'prompt_tokens_details': {'cached_tokens': 5},
            'completion_tokens_details': {'reasoning_tokens': 3},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  group('usage metadata on the wire', () {
    test('non-streaming response populates usage', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Say hello.',
      );

      expect(response.usage, isNotNull);
      expect(response.usage?.inputTokens, 15);
      expect(response.usage?.outputTokens, 7);
      expect(response.usage?.totalTokens, 22);
      expect(response.usage?.thoughtsTokens, 3);
      expect(response.usage?.cachedContentTokens, 5);

      await ai.shutdown();
    });

    test('streaming request opts into usage reporting', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );

      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'Say hello.',
      );
      await for (final _ in stream) {}

      expect(captured.single['stream_options'], {'include_usage': true});

      await ai.shutdown();
    });

    test('streaming response populates usage from the final chunk', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'test-key', httpClient: wireClient(captured))],
      );

      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'Say hello.',
      );
      await for (final _ in stream) {}
      final result = await stream.onResult;

      expect(result.usage, isNotNull);
      expect(result.usage?.inputTokens, 15);
      expect(result.usage?.outputTokens, 7);
      expect(result.usage?.totalTokens, 22);

      await ai.shutdown();
    });
  });
}
