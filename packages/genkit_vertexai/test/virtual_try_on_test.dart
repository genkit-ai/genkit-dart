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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    lastBody = await request.finalize().bytesToString();
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
          '{"predictions": [{"mimeType": "image/png", "bytesBase64Encoded": "b3V0cHV0"}]}',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('Virtual Try-On', () {
    test('creates a model ref', () {
      final modelRef = vertexAI.virtualTryOn();

      expect(modelRef.name, 'vertexai/virtual-try-on-001');
      expect(modelRef.config, isNull);
    });

    test('uses predict endpoint', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve('model', 'virtual-try-on-001') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'Try on this sweater'),
              MediaPart(
                media: Media(
                  contentType: 'image/png',
                  url: 'data:image/png;base64,cGVyc29u',
                ),
                metadata: {'type': 'personImage'},
              ),
              MediaPart(
                media: Media(
                  contentType: 'image/jpeg',
                  url: 'data:image/jpeg;base64,cHJvZHVjdA==',
                ),
                metadata: {'type': 'productImage'},
              ),
            ],
          ),
        ],
        config: VirtualTryOnOptions(
          sampleCount: 2,
          storageUri: 'gs://bucket/out',
        ).toJson(),
      );

      final result = await model.run(req);
      final response = result.result as ModelResponse;

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/virtual-try-on-001:predict',
      );
      expect(jsonDecode(mockClient.lastBody!), {
        'instances': [
          {
            'personImage': {
              'image': {
                'mimeType': 'image/png',
                'bytesBase64Encoded': 'cGVyc29u',
              },
            },
            'productImages': [
              {
                'image': {
                  'mimeType': 'image/jpeg',
                  'bytesBase64Encoded': 'cHJvZHVjdA==',
                },
              },
            ],
          },
        ],
        'parameters': {'sampleCount': 2, 'storageUri': 'gs://bucket/out'},
      });
      expect(response.media?.url, 'data:image/png;base64,b3V0cHV0');
      expect(response.usage?.outputImages, 1);
    });
  });
}
