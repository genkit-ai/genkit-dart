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
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Anthropic Vertex AI', () {
    test('builds ADC helper config', () {
      final config = AnthropicVertexConfig.adc(projectId: 'my-project');

      expect(config.projectId, 'my-project');
      expect(config.location, 'global');
      expect(config.accessToken, isNull);
      expect(config.accessTokenProvider, isNotNull);
    });

    test('builds service account helper config', () {
      final config = AnthropicVertexConfig.serviceAccount(
        credentialsJson: {
          'type': 'service_account',
          'project_id': 'my-project',
          'client_email': 'svc@project.iam.gserviceaccount.com',
          'client_id': '1234567890',
          'private_key':
              '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
        },
      );

      expect(config.projectId, isNull);
      expect(config.resolveProjectId(), 'my-project');
      expect(config.location, 'global');
      expect(config.accessToken, isNull);
      expect(config.accessTokenProvider, isNotNull);
    });

    test('prefers explicit projectId over service account project_id', () {
      final config = AnthropicVertexConfig.serviceAccount(
        projectId: 'my-explicit-project',
        credentialsJson: {
          'type': 'service_account',
          'project_id': 'my-inferred-project',
          'client_email': 'svc@project.iam.gserviceaccount.com',
          'client_id': '1234567890',
          'private_key':
              '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n',
        },
      );

      expect(config.projectId, 'my-explicit-project');
      expect(config.resolveProjectId(), 'my-explicit-project');
    });

    test('rejects conflicting plugin configuration', () {
      expect(
        () => anthropic(
          apiKey: 'anthropic-key',
          vertex: AnthropicVertexConfig(
            projectId: 'my-project',
            accessToken: 'ya29.token',
          ),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'Provide either apiKey or vertex configuration, not both.',
              ),
        ),
      );
    });

    test('rejects invalid vertex config with both token sources', () {
      expect(
        () => AnthropicPluginImpl(
          vertex: AnthropicVertexConfig(
            projectId: 'my-project',
            accessToken: 'ya29.token',
            accessTokenProvider: () async => 'ya29.provider',
          ),
          vertexHttpClient: _RecordingHttpClient((request) async {
            throw StateError('Should not send request for invalid config.');
          }),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'Provide either accessToken or accessTokenProvider, not both.',
              ),
        ),
      );
    });

    test('rejects invalid vertex config with empty projectId', () {
      expect(
        () => AnthropicPluginImpl(
          vertex: AnthropicVertexConfig(
            projectId: '   ',
            accessToken: 'ya29.token',
          ),
          vertexHttpClient: _RecordingHttpClient((request) async {
            throw StateError('Should not send request for invalid config.');
          }),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'Vertex Anthropic requires a non-empty projectId.',
              ),
        ),
      );
    });

    test('rejects invalid vertex config with unsafe location', () {
      expect(
        () => AnthropicPluginImpl(
          vertex: AnthropicVertexConfig(
            projectId: 'my-project',
            location: 'evil.com/path?',
            accessToken: 'ya29.token',
          ),
          vertexHttpClient: _RecordingHttpClient((request) async {
            throw StateError('Should not send request for invalid config.');
          }),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'Vertex Anthropic location may only contain letters, numbers, and hyphens.',
              ),
        ),
      );
    });

    test('sends Vertex unary request and parses response', () async {
      final client = _RecordingHttpClient((request) async {
        return _jsonStreamedResponse(200, {
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'model': 'claude-sonnet-4-5@20250929',
          'content': [
            {'type': 'text', 'text': 'Hello from Vertex'},
          ],
          'stop_reason': 'end_turn',
          'usage': {'input_tokens': 10, 'output_tokens': 4},
        });
      });

      var tokenProviderCalled = false;
      final plugin = AnthropicPluginImpl(
        vertex: AnthropicVertexConfig(
          projectId: 'my-project',
          location: 'global',
          accessTokenProvider: () async {
            tokenProviderCalled = true;
            return 'ya29.test-token';
          },
        ),
        vertexHttpClient: client,
      );

      final ai = Genkit(plugins: [plugin], isDevEnv: false);
      final result = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5@20250929'),
        prompt: 'Say hello',
      );

      expect(tokenProviderCalled, isTrue);
      expect(result.text, 'Hello from Vertex');

      expect(client.requests.length, 1);
      final request = client.requests.single;
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        contains(
          '/projects/my-project/locations/global/publishers/anthropic/models/claude-sonnet-4-5%4020250929:rawPredict',
        ),
      );
      expect(request.url.host, 'aiplatform.googleapis.com');
      expect(request.headers['authorization'], 'Bearer ya29.test-token');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['accept'], 'application/json');
      expect(request.headers['x-goog-api-client'], isNotNull);
      expect(request.headers['x-goog-api-client'], startsWith('genkit-dart/'));
      expect(request.headers['x-goog-api-client'], contains(' gl-dart/'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['anthropic_version'], 'vertex-2023-10-16');
      expect(body.containsKey('model'), isFalse);
      expect((body['messages'] as List).length, 1);
    });

    test('uses regional host for non-global locations', () async {
      final client = _RecordingHttpClient((request) async {
        return _jsonStreamedResponse(200, {
          'id': 'msg_region',
          'type': 'message',
          'role': 'assistant',
          'model': 'claude-sonnet-4-5',
          'content': [
            {'type': 'text', 'text': 'hello'},
          ],
          'stop_reason': 'end_turn',
          'usage': {'input_tokens': 2, 'output_tokens': 1},
        });
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              location: 'us-east5',
              accessToken: 'ya29.region-token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      final result = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'hello',
      );

      expect(result.text, 'hello');
      expect(client.requests.length, 1);
      final request = client.requests.single;
      expect(request.url.host, 'us-east5-aiplatform.googleapis.com');
      expect(
        request.url.toString(),
        contains(
          '/projects/my-project/locations/us-east5/publishers/anthropic/models/claude-sonnet-4-5:rawPredict',
        ),
      );
    });

    test('streams Vertex response chunks and final message', () async {
      final events = [
        {
          'type': 'message_start',
          'message': {
            'id': 'msg_2',
            'type': 'message',
            'role': 'assistant',
            'model': 'claude-sonnet-4-5',
            'content': <Map<String, dynamic>>[],
            'usage': {'input_tokens': 3, 'output_tokens': 0},
          },
        },
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hello'},
        },
        {
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
          'usage': {'output_tokens': 1},
        },
        {'type': 'message_stop'},
      ];

      final sse =
          '${events.map((e) => 'data: ${jsonEncode(e)}').join('\n\n')}\n\n';

      final client = _RecordingHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              accessToken: 'ya29.stream-token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      final stream = ai.generateStream(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'Say hello in stream',
      );

      final chunks = await stream.toList();
      final result = await stream.onResult;

      expect(chunks.map((c) => c.text).toList(), ['Hello']);
      expect(result.text, 'Hello');

      final request = client.requests.single;
      expect(
        request.url.toString(),
        contains(
          '/publishers/anthropic/models/claude-sonnet-4-5:streamRawPredict',
        ),
      );
      expect(request.headers['accept'], 'text/event-stream');

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['anthropic_version'], 'vertex-2023-10-16');
      expect(body.containsKey('model'), isFalse);
    });

    test('skips malformed Vertex streaming events', () async {
      final events = [
        {
          'type': 'message_start',
          'message': {
            'id': 'msg_3',
            'type': 'message',
            'role': 'assistant',
            'model': 'claude-sonnet-4-5',
            'content': <Map<String, dynamic>>[],
            'usage': {'input_tokens': 3, 'output_tokens': 0},
          },
        },
        {
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        },
        {
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hello'},
        },
        {
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
          'usage': {'output_tokens': 1},
        },
        {'type': 'message_stop'},
      ];

      const malformedSse = 'data: {"type": "content_block_delta"';
      final sseEvents = [
        'data: ${jsonEncode(events.first)}',
        malformedSse,
        ...events.skip(1).map((event) => 'data: ${jsonEncode(event)}'),
      ];
      final sse = '${sseEvents.join('\n\n')}\n\n';

      final client = _RecordingHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse)),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              accessToken: 'ya29.stream-token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      final stream = ai.generateStream(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'Say hello in stream',
      );

      final chunks = await stream.toList();
      final result = await stream.onResult;

      expect(chunks.map((c) => c.text).toList(), ['Hello']);
      expect(result.text, 'Hello');
    });

    test('maps Vertex HTTP errors to GenkitException', () async {
      final client = _RecordingHttpClient((request) async {
        return _jsonStreamedResponse(403, {
          'error': {'message': 'Permission denied by Vertex IAM'},
        });
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              accessToken: 'ya29.denied-token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      await expectLater(
        ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'This will fail',
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.PERMISSION_DENIED)
              .having(
                (e) => e.message,
                'message',
                'Permission denied by Vertex IAM',
              ),
        ),
      );
    });

    test('keeps fallback message concise for non-JSON error bodies', () async {
      final htmlBody = '''<!DOCTYPE html><html><body>Not Found</body></html>''';
      final client = _RecordingHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(htmlBody)),
          404,
          headers: {'content-type': 'text/html'},
        );
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              accessToken: 'ya29.not-found-token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      await expectLater(
        ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'This should return non-JSON error',
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.NOT_FOUND)
              .having(
                (e) => e.message,
                'message',
                'Vertex Anthropic request failed with status 404.',
              )
              .having((e) => e.details, 'details', contains('DOCTYPE html')),
        ),
      );
    });

    test('rejects per-request apiKey overrides in Vertex mode', () async {
      final client = _RecordingHttpClient((request) async {
        return _jsonStreamedResponse(200, {
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'model': 'claude-sonnet-4-5',
          'content': [
            {'type': 'text', 'text': 'not used'},
          ],
          'stop_reason': 'end_turn',
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        });
      });

      final ai = Genkit(
        plugins: [
          AnthropicPluginImpl(
            vertex: AnthropicVertexConfig(
              projectId: 'my-project',
              accessToken: 'ya29.token',
            ),
            vertexHttpClient: client,
          ),
        ],
        isDevEnv: false,
      );

      await expectLater(
        ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'hello',
          config: AnthropicOptions(apiKey: 'anthropic-key'),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'AnthropicOptions.apiKey is not supported when using Vertex configuration.',
              ),
        ),
      );

      expect(client.requests, isEmpty);
    });
  });
}

class _RecordingHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.Request request) _handler;
  final List<http.Request> requests = [];

  _RecordingHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is! http.Request) {
      throw StateError('Expected http.Request but got ${request.runtimeType}.');
    }
    requests.add(request);
    return _handler(request);
  }
}

http.StreamedResponse _jsonStreamedResponse(
  int statusCode,
  Map<String, dynamic> body,
) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
