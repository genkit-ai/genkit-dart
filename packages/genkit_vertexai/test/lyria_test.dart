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
import 'package:genkit_vertexai/src/lyria.dart';
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
    if (request.url.path.endsWith('/interactions')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"status": "completed", "outputs": [{"type": "text", "text": "description"}, {"type": "audio", "mime_type": "audio/mpeg", "data": "SUQz"}]}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"predictions": [{"audioContent": "UklGRg==", "mimeType": "audio/wav"}]}',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('Vertex AI Lyria models', () {
    test('uses predict endpoint and returns audio media', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'lyria-002') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'calm acoustic folk song')],
          ),
        ],
        config: LyriaOptions(negativePrompt: 'drums', seed: 98765).toJson(),
      );

      final runResult = await model.run(req);
      final response = (runResult as dynamic).result as ModelResponse;

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1/projects/my-project/locations/us-central1/publishers/google/models/lyria-002:predict',
      );
      expect(mockClient.lastBody, {
        'instances': [
          {
            'prompt': 'calm acoustic folk song',
            'negative_prompt': 'drums',
            'seed': 98765,
          },
        ],
        'parameters': <String, dynamic>{},
      });
      final message = response.message!;
      final part = message.content.single;
      expect(part.isMedia, true);
      expect(part.media!.contentType, 'audio/wav');
      expect(part.media!.url, 'data:audio/wav;base64,UklGRg==');
    });

    test('uses interactions endpoint for Lyria 3 models', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'lyria-3-clip-preview') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'short electronic theme')],
          ),
        ],
      );

      final runResult = await model.run(req);
      final response = (runResult as dynamic).result as ModelResponse;

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/interactions',
      );
      expect(mockClient.lastBody, {
        'model': 'lyria-3-clip-preview',
        'input': [
          {'type': 'text', 'text': 'short electronic theme'},
        ],
      });
      final message = response.message!;
      expect(message.content.first.text, 'description');
      final part = message.content.last;
      expect(part.isMedia, true);
      expect(part.media!.contentType, 'audio/mpeg');
      expect(part.media!.url, 'data:audio/mpeg;base64,SUQz');
    });

    test('accepts nested bytesBase64Encoded audio content', () {
      final response = fromLyriaPredictResponse({
        'predictions': [
          {
            'audioContent': {'bytesBase64Encoded': 'UklGRg=='},
            'mimeType': 'audio/wav',
          },
        ],
      });

      final part = response.message!.content.single;
      expect(part.isMedia, true);
      expect(part.media!.url, 'data:audio/wav;base64,UklGRg==');
    });

    test('accepts top-level data audio content', () {
      final response = fromLyriaPredictResponse({
        'predictions': [
          {'data': 'UklGRg==', 'mimeType': 'audio/wav'},
        ],
      });

      final part = response.message!.content.single;
      expect(part.isMedia, true);
      expect(part.media!.url, 'data:audio/wav;base64,UklGRg==');
    });
  });
}
