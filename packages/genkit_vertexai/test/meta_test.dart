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

import 'package:genkit_vertexai/src/meta_model.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  Uri? lastUrl;
  Map<String, dynamic>? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
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
    if (request is http.Request && request.body.isNotEmpty) {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"choices": [{"message": {"content": "response", "role": "assistant"}, "finish_reason": "stop", "index": 0}], "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('Vertex AI Meta models', () {
    test('uses OpenAI-compatible endpoint for Meta models', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model =
          plugin.resolve('model', 'llama-3.3-70b-instruct-maas') as Action;
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
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/endpoints/openapi/chat/completions',
      );
      expect(mockClient.lastBody?['model'], 'meta/llama-3.3-70b-instruct-maas');
      expect(mockClient.lastBody?['stream'], false);
      expect(mockClient.lastBody?['messages'], [
        {'role': 'user', 'content': 'hello'},
      ]);
    });

    test('rejects gs:// media URLs', () {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  url: 'gs://my-bucket/image.png',
                  contentType: 'image/png',
                ),
              ),
            ],
          ),
        ],
      );

      expect(
        () => toMetaChatCompletionRequest(
          request,
          'meta/llama-4-maverick-17b-128e-instruct-maas',
          VertexAiMetaOptions(),
          stream: false,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('gs:// media URLs'),
          ),
        ),
      );
    });

    test('uses JSON object response format without schema', () {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'return json')],
          ),
        ],
        output: OutputConfig(format: 'json'),
      );

      final body = toMetaChatCompletionRequest(
        request,
        'meta/llama-4-maverick-17b-128e-instruct-maas',
        VertexAiMetaOptions(),
        stream: false,
      );

      expect(body['response_format'], {'type': 'json_object'});
    });

    test('passes supported OpenAI-compatible options', () {
      final request = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        tools: [
          ToolDefinition(
            name: 'getWeather',
            description: 'Get weather for a location',
            inputSchema: {
              'type': 'object',
              'properties': {
                'location': {'type': 'string'},
              },
              'required': ['location'],
            },
          ),
        ],
        toolChoice: 'any',
      );

      final body = toMetaChatCompletionRequest(
        request,
        'meta/llama-4-maverick-17b-128e-instruct-maas',
        VertexAiMetaOptions(
          temperature: 0.2,
          topP: 0.9,
          maxTokens: 128,
          stop: ['done'],
          presencePenalty: 0.1,
          frequencyPenalty: 0.2,
          logprobs: true,
          topLogprobs: 3,
          seed: 7,
          user: 'user-1',
          llamaGuard: true,
        ),
        stream: false,
      );

      expect(body['temperature'], 0.2);
      expect(body['top_p'], 0.9);
      expect(body['max_tokens'], 128);
      expect(body['stop'], ['done']);
      expect(body['presence_penalty'], 0.1);
      expect(body['frequency_penalty'], 0.2);
      expect(body['logprobs'], true);
      expect(body['top_logprobs'], 3);
      expect(body['seed'], 7);
      expect(body['user'], 'user-1');
      expect(body['tool_choice'], 'required');
      expect(body['tools'], hasLength(1));
      expect(body['extra_body'], {
        'google': {
          'model_safety_settings': {
            'enabled': true,
            'llama_guard_settings': <String, dynamic>{},
          },
        },
      });
    });

    test('aggregates streamed tool call chunks', () {
      final response = fromMetaChatCompletionChunks([
        {
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call_weather',
                    'type': 'function',
                    'function': {'name': 'getWeather', 'arguments': '{"loc'},
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
                    'function': {'arguments': 'ation":"Boston"}'},
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
          'usage': {
            'prompt_tokens': 3,
            'completion_tokens': 2,
            'total_tokens': 5,
          },
        },
      ]);

      final content = response.message!.content;
      expect(response.finishReason, FinishReason.stop);
      expect(content, hasLength(1));
      expect(content.first.isToolRequest, true);

      final toolRequest = content.first.toolRequest!;
      expect(toolRequest.ref, 'call_weather');
      expect(toolRequest.name, 'getWeather');
      expect(toolRequest.input, {'location': 'Boston'});
      expect(response.usage?.totalTokens, 5);
    });
  });
}
