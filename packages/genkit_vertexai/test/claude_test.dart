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
  Future<http.StreamedResponse> Function(http.BaseRequest request)? onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    if (request is http.Request) {
      lastBody = request.body;
    }
    if (onSend != null) {
      return onSend!(request);
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
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"candidates": [{"content": {"parts": [{"text": "response"}], "role": "model"}, "finishReason": "STOP"}]} ',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('Vertex AI Plugin (Claude)', () {
    test('routes Claude models through Vertex rawPredict', () async {
      final mockClient = MockHttpClient()
        ..onSend = (request) async {
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

          return http.StreamedResponse(
            Stream.value(
              utf8.encode(
                '{"id":"msg_123","type":"message","role":"assistant","content":[{"type":"text","text":"response"}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}',
              ),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        };

      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'claude-sonnet-4-6') as Action;
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
        'https://us-central1-aiplatform.googleapis.com/v1/projects/my-project/locations/us-central1/publishers/anthropic/models/claude-sonnet-4-6:rawPredict',
      );

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final firstMessage = messages.first as Map<String, dynamic>;
      expect(body['anthropic_version'], 'vertex-2023-10-16');
      expect(body.containsKey('model'), isFalse);
      expect(messages, hasLength(1));
      expect(firstMessage['role'], 'user');
    });

    test('lists Gemini, Claude, and embedders from Model Garden', () async {
      final mockClient = MockHttpClient()
        ..onSend = (request) async {
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

          if (request.url.path.endsWith('/publishers/google/models')) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  '{"publisherModels":[{"name":"publishers/google/models/gemini-2.5-flash"},{"name":"publishers/google/models/text-embedding-004"}]}',
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith('/publishers/anthropic/models')) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  '{"publisherModels":[{"name":"publishers/anthropic/models/claude-sonnet-4-6"}]}',
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.StreamedResponse(
            Stream.value(utf8.encode('{}')),
            200,
            headers: {'content-type': 'application/json'},
          );
        };

      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        authClient: mockClient,
      );

      final actions = await plugin.list();
      final actionNames = actions.map((action) => action.name).toList();

      expect(actionNames, contains('vertexai/gemini-2.5-flash'));
      expect(actionNames, contains('vertexai/claude-sonnet-4-6'));
      expect(actionNames, contains('vertexai/text-embedding-004'));
    });
  });
}
