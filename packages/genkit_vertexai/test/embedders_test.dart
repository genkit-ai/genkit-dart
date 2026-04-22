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
import 'package:test/test.dart';

import 'test_http_client.dart';

typedef _EmbedderAction = Action<EmbedRequest, EmbedResponse, void, void>;

_EmbedderAction _resolveEmbedder(VertexAiPluginImpl plugin, String name) {
  return plugin.resolve('embedder', name)! as _EmbedderAction;
}

void main() {
  group('Vertex AI Embedders', () {
    test('lists embedders with schemas and custom options', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final actions = await plugin.list();
      final embedder = actions.firstWhere(
        (action) => action.name == 'vertexai/text-embedding-005',
      );

      expect(embedder.name, 'vertexai/text-embedding-005');
      expect(embedder.inputSchema, same(EmbedRequest.$schema));
      expect(embedder.outputSchema, same(EmbedResponse.$schema));

      final modelMetadata = embedder.metadata['model'] as Map<String, dynamic>;
      final customOptions =
          modelMetadata['customOptions'] as Map<String, dynamic>;
      expect(customOptions['properties'], contains('outputDimensionality'));
      expect(customOptions['properties'], contains('taskType'));
    });

    test('uses embedContent for embedders', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'gemini-embedding-2-preview');
      final req = EmbedRequest(
        input: [
          DocumentData(content: [TextPart(text: 'hello')]),
        ],
      );

      final response = await embedder.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-embedding-2-preview:embedContent',
      );
      expect(response.result.embeddings, hasLength(1));
      expect(response.result.embeddings.first.embedding, [0.1, 0.2, 0.3]);
    });

    test('uses predict for gemini-embedding-001', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'gemini-embedding-001');
      final req = EmbedRequest(
        input: [
          DocumentData(content: [TextPart(text: 'hello')]),
        ],
      );

      final response = await embedder.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-embedding-001:predict',
      );
      expect(response.result.embeddings, hasLength(1));
      expect(response.result.embeddings.first.embedding, [0.4, 0.5, 0.6]);
    });

    test(
      'uses multimodal predict schema for multimodalembedding text input',
      () async {
        final mockClient = MockHttpClient();
        final plugin = VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'us-central1',
          authClient: mockClient,
        );

        final embedder = _resolveEmbedder(plugin, 'multimodalembedding');
        final req = EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
          ],
          options: {
            'outputDimensionality': 256,
            'taskType': 'RETRIEVAL_DOCUMENT',
          },
        );

        final response = await embedder.run(req);

        expect(mockClient.lastUrl, isNotNull);
        expect(
          mockClient.lastUrl.toString(),
          'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/multimodalembedding:predict',
        );

        final requestBody =
            jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
        final instances = requestBody['instances'] as List;
        expect(instances.single, {'text': 'hello'});
        expect(requestBody['parameters'], {'dimension': 256});
        expect(response.result.embeddings, hasLength(1));
        expect(response.result.embeddings.first.embedding, [0.7, 0.8, 0.9]);
      },
    );
  });
}
