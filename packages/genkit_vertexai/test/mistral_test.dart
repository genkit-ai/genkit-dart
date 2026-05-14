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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  Uri? lastUrl;
  String? lastBody;
  bool isClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    if (request is http.Request) {
      lastBody = request.body;
    }

    if (request.url.host == 'metadata.google.internal' ||
        request.url.host == 'oauth2.googleapis.com') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"access_token": "ya29.mock", "expires_in": 3600, "token_type": "Bearer"}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path == '/v1beta1/publishers/google/models') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"publisherModels": [{"name": "publishers/google/models/gemini-1.5-pro"}]}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path == '/v1beta1/publishers/mistralai/models') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"publisherModels": [{"name": "publishers/mistralai/models/mistral-small-2503"}, {"name": "publishers/mistralai/models/mistral-ocr-2505"}]}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (request.url.path.endsWith(':rawPredict')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"choices": [{"message": {"role": "assistant", "content": "response"}, "finish_reason": "stop"}]}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }

  @override
  void close() {
    isClosed = true;
  }
}

void main() {
  group('Mistral Vertex AI support', () {
    test('uses correct endpoint for Mistral models', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'mistral-small-2503') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      await model.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1/projects/my-project/locations/us-central1/publishers/mistralai/models/mistral-small-2503:rawPredict',
      );
      expect(
        jsonDecode(mockClient.lastBody!) as Map<String, dynamic>,
        containsPair('model', 'mistral-small-2503'),
      );
      expect(mockClient.isClosed, isFalse);
    });

    test('passes through supported Mistral chat parameters', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'mistral-medium-3') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        config: {
          'temperature': 0.2,
          'topP': 0.9,
          'maxTokens': 256,
          'stop': 'END',
          'n': 2,
          'presencePenalty': 0.1,
          'frequencyPenalty': 0.2,
          'randomSeed': 7,
          'safePrompt': true,
          'toolChoice': {
            'type': 'function',
            'function': {'name': 'lookup'},
          },
          'parallelToolCalls': false,
          'prediction': {'type': 'content', 'content': 'expected completion'},
          'promptCacheKey': 'shared-prefix',
          'metadata': {'traceId': 'abc'},
          'guardrails': ['default'],
          'promptMode': 'reasoning',
          'reasoningEffort': 'high',
          'responseFormat': {'type': 'json_schema'},
        },
      );

      await model.run(req);

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      expect(body, containsPair('temperature', 0.2));
      expect(body, containsPair('top_p', 0.9));
      expect(body, containsPair('max_tokens', 256));
      expect(body, containsPair('stop', 'END'));
      expect(body, containsPair('n', 2));
      expect(body, containsPair('presence_penalty', 0.1));
      expect(body, containsPair('frequency_penalty', 0.2));
      expect(body, containsPair('random_seed', 7));
      expect(body, containsPair('safe_prompt', true));
      expect(
        body,
        containsPair('tool_choice', {
          'type': 'function',
          'function': {'name': 'lookup'},
        }),
      );
      expect(body, containsPair('parallel_tool_calls', false));
      expect(
        body,
        containsPair('prediction', {
          'type': 'content',
          'content': 'expected completion',
        }),
      );
      expect(body, containsPair('prompt_cache_key', 'shared-prefix'));
      expect(body, containsPair('metadata', {'traceId': 'abc'}));
      expect(body, containsPair('guardrails', ['default']));
      expect(body, containsPair('prompt_mode', 'reasoning'));
      expect(body, containsPair('reasoning_effort', 'high'));
      expect(body, containsPair('response_format', {'type': 'json_schema'}));
    });

    test('lists Mistral models dynamically', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final actions = await plugin.list();
      final actionNames = actions.map((action) => action.name);

      expect(actionNames, contains('vertexai/mistral-small-2503'));
      expect(actionNames, isNot(contains('vertexai/mistral-ocr-2505')));
      expect(actionNames, isNot(contains('vertexai/mistral-medium-3')));
    });
  });
}
