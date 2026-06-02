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

const _mockAccessTokenJson =
    '{"access_token": "ya29.mock", "expires_in": 3600, "token_type": "Bearer"}';
const _mockClaudeMessageJson =
    '{"id":"msg_123","type":"message","role":"assistant","content":[{"type":"text","text":"response"}],"model":"claude-sonnet-4-6","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":1,"output_tokens":1}}';

bool _isAuthRequest(http.BaseRequest request) {
  return request.url.host == 'metadata.google.internal' ||
      request.url.host == 'oauth2.googleapis.com';
}

http.StreamedResponse _jsonResponse(String body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    200,
    headers: {'content-type': 'application/json'},
  );
}

Future<MockHttpClient> _runClaudeRequest(ModelRequest req) async {
  final mockClient = MockHttpClient()
    ..onSend = (request) async {
      if (_isAuthRequest(request)) {
        return _jsonResponse(_mockAccessTokenJson);
      }
      return _jsonResponse(_mockClaudeMessageJson);
    };

  final plugin = VertexAiPluginImpl(
    projectId: 'my-project',
    location: 'us-central1',
    authClient: mockClient,
  );

  final model = plugin.resolve('model', 'claude-sonnet-4-6') as Action;
  await model.run(req);
  return mockClient;
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

    test('uses namespaced structured output tool', () async {
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        output: OutputConfig(
          schema: {
            'properties': {
              'answer': {'type': 'string'},
            },
          },
        ),
      );

      final mockClient = await _runClaudeRequest(req);

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final tools = body['tools'] as List<dynamic>;
      final firstTool = tools.first as Map<String, dynamic>;
      final toolChoice = body['tool_choice'] as Map<String, dynamic>;

      expect(firstTool['name'], '__genkit_output__');
      expect(toolChoice['name'], '__genkit_output__');
    });

    test('passes string tool responses without JSON string encoding', () async {
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.tool,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(
                  ref: 'toolu_123',
                  name: 'lookup',
                  output: 'plain text',
                ),
              ),
            ],
          ),
        ],
      );

      final mockClient = await _runClaudeRequest(req);

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final firstMessage = messages.first as Map<String, dynamic>;
      final content = firstMessage['content'] as List<dynamic>;
      final toolResult = content.first as Map<String, dynamic>;
      final resultContent = toolResult['content'] as List<dynamic>;
      final textContent = resultContent.first as Map<String, dynamic>;

      expect(textContent['text'], 'plain text');
    });

    test('sends data URL images as base64', () async {
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  contentType: 'image/png',
                  url: 'data:image/png;base64,abc123',
                ),
              ),
            ],
          ),
        ],
      );

      final mockClient = await _runClaudeRequest(req);

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      final firstMessage = messages.first as Map<String, dynamic>;
      final content = firstMessage['content'] as List<dynamic>;
      final image = content.first as Map<String, dynamic>;
      final source = image['source'] as Map<String, dynamic>;

      expect(source['type'], 'base64');
      expect(source['media_type'], 'image/png');
      expect(source['data'], 'abc123');
    });

    test('rejects malformed data URL images without comma', () async {
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: MockHttpClient(),
      );

      final model = plugin.resolve('model', 'claude-sonnet-4-6') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              MediaPart(
                media: Media(
                  contentType: 'image/png',
                  url: 'data:image/png;base64nocomma',
                ),
              ),
            ],
          ),
        ],
      );

      await expectLater(
        model.run(req),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });

    test(
      'rejects image URLs because Vertex AI Claude requires base64',
      () async {
        final plugin = VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'us-central1',
          authClient: MockHttpClient(),
        );

        final model = plugin.resolve('model', 'claude-sonnet-4-6') as Action;
        final req = ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [
                MediaPart(
                  media: Media(
                    contentType: 'image/png',
                    url: 'https://example.com/image.png',
                  ),
                ),
              ],
            ),
          ],
        );

        await expectLater(
          model.run(req),
          throwsA(
            isA<GenkitException>().having(
              (error) => error.status,
              'status',
              StatusCodes.INVALID_ARGUMENT,
            ),
          ),
        );
      },
    );

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
