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

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  group('Vertex AI Plugin', () {
    test('uses correct endpoint for regional location', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      await model.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-2.5-pro:generateContent',
      );
    });

    test('uses correct endpoint for global location', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        authClient: mockClient,
      );

      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      await model.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/publishers/google/models/gemini-2.5-pro:generateContent',
      );
    });
  });

  group('injected client lifecycle', () {
    VertexAiPluginImpl pluginWith(MockHttpClient client) => VertexAiPluginImpl(
      projectId: 'my-project',
      location: 'us-central1',
      authClient: client,
    );

    test('list does not close the injected client', () async {
      final mockClient = MockHttpClient();

      await pluginWith(mockClient).list();

      expect(mockClient.closed, isFalse);
    });

    test('embedder does not close the injected client', () async {
      final mockClient = MockHttpClient();
      final embedder =
          pluginWith(mockClient).resolve(.embedder, 'text-embedding-005')!
              as Action<EmbedRequest, EmbedResponse, void, void>;

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
          ],
        ),
      );

      expect(mockClient.closed, isFalse);
    });
  });
}
