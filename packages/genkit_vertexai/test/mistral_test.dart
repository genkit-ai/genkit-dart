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
import 'package:genkit_vertexai/genkit_vertexai.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  Uri? lastUrl;
  String? lastBody;
  final streamRawPredictBodies = <Map<String, dynamic>>[];
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

    if (request.url.path.endsWith(':streamRawPredict')) {
      final body =
          jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      streamRawPredictBodies.add(body);

      if (streamRawPredictBodies.length == 1) {
        return _streamResponse([
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call_123',
                      'type': 'function',
                      'function': {'name': 'calculator', 'arguments': '{"a":'},
                    },
                  ],
                },
              },
            ],
          },
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'function': {'arguments': '123,"b":456}'},
                    },
                  ],
                },
                'finish_reason': 'tool_calls',
              },
            ],
          },
        ]);
      }

      return _streamResponse([
        {
          'choices': [
            {
              'delta': {'content': '560'},
            },
          ],
        },
        {
          'choices': [
            {
              'delta': {'content': '88'},
              'finish_reason': 'stop',
            },
          ],
        },
      ]);
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

  http.StreamedResponse _streamResponse(List<Map<String, dynamic>> chunks) {
    return http.StreamedResponse(
      Stream.fromIterable([
        for (final chunk in chunks)
          utf8.encode('data: ${jsonEncode(chunk)}\n\n'),
        utf8.encode('data: [DONE]\n\n'),
      ]),
      200,
      headers: {'content-type': 'text/event-stream'},
    );
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

    test('streams tool calls through the Genkit tool loop', () async {
      final mockClient = MockHttpClient();
      final ai = Genkit(
        plugins: [
          vertexAI(
            projectId: 'my-project',
            location: 'us-central1',
            authClient: mockClient,
          ),
        ],
      );

      Map<String, dynamic>? toolInput;
      final tool = ai.defineTool<Map<String, dynamic>, int>(
        name: 'calculator',
        description: 'Multiplies two numbers',
        fn: (input, _) async {
          toolInput = input;
          return (input['a'] as int) * (input['b'] as int);
        },
      );

      final stream = ai.generateStream(
        model: vertexAI.mistral('mistral-small-2503'),
        prompt: 'What is 123 * 456?',
        tools: [tool],
        config: MistralOptions(toolChoice: 'any'),
        maxTurns: 3,
      );

      final chunks = await stream.toList();
      final response = await stream.onResult;

      expect(chunks.map((chunk) => chunk.text).join(), '56088');
      expect(response.text, '56088');
      expect(toolInput, {'a': 123, 'b': 456});
      expect(mockClient.streamRawPredictBodies, hasLength(2));

      final messages = mockClient.streamRawPredictBodies[1]['messages'] as List;
      expect(messages.map((m) => (m as Map)['role']).toList(), [
        'user',
        'assistant',
        'tool',
      ]);

      final assistantMessage = messages[1] as Map<String, dynamic>;
      final toolCalls = assistantMessage['tool_calls'] as List;
      final toolCall = toolCalls.single as Map<String, dynamic>;
      expect(toolCall['id'], 'call_123');
      expect(toolCall['type'], 'function');
      expect((toolCall['function'] as Map)['name'], 'calculator');
      expect(jsonDecode((toolCall['function'] as Map)['arguments'] as String), {
        'a': 123,
        'b': 456,
      });

      expect(messages[2], {
        'role': 'tool',
        'tool_call_id': 'call_123',
        'name': 'calculator',
        'content': '56088',
      });
    });
  });
}
