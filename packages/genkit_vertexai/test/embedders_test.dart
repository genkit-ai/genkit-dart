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
import 'package:genkit_google_genai/common.dart'
    show resetDroppedConfigFieldWarnings;
import 'package:genkit_vertexai/src/known_models.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

typedef _EmbedderAction = Action<EmbedRequest, EmbedResponse, void, void>;

_EmbedderAction _resolveEmbedder(VertexAiPluginImpl plugin, String name) {
  return plugin.resolve(.embedder, name)! as _EmbedderAction;
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
      // Curated info (JS vertexai embedder.ts).
      expect(modelMetadata['dimensions'], 768);
      expect(modelMetadata['supports'], {
        'input': ['text'],
      });
    });

    test('the curated list matches JS, and curated embedders stay listed '
        'once', () async {
      expect(vertexAiKnownEmbedders.keys, [
        'text-embedding-005',
        'text-multilingual-embedding-002',
        'multimodalembedding@001',
        'gemini-embedding-001',
        'gemini-embedding-2',
        'text-embedding-004',
      ]);
      expect(vertexAiKnownEmbedders['gemini-embedding-2'], {
        'label': 'Gemini Embedding 2',
        'dimensions': 3072,
        'supports': {
          'input': ['text', 'image', 'video'],
        },
      });
      expect(
        vertexAiKnownEmbedders['multimodalembedding@001']?['dimensions'],
        1408,
      );

      // Discovery returns text-embedding-005 and multimodalembedding (see
      // MockHttpClient): every curated one is listed exactly once.
      final names = (await VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: MockHttpClient(),
      ).list()).map((a) => a.name).toList();
      for (final id in vertexAiKnownEmbedders.keys) {
        expect(
          names.where((n) => n == 'vertexai/$id'),
          hasLength(1),
          reason: id,
        );
      }
      expect(names, contains('vertexai/multimodalembedding'));
    });

    test('a resolved curated embedder carries its info', () {
      final embedder = _resolveEmbedder(
        VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'us-central1',
          authClient: MockHttpClient(),
        ),
        'gemini-embedding-2',
      );
      expect(
        embedder.metadata['model'],
        vertexAiKnownEmbedders['gemini-embedding-2'],
      );
    });

    test('uses embedContent for gemini-embedding-2, one request per '
        'document with its text and media parts (as JS)', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'gemini-embedding-2');
      final response = await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
            DocumentData(
              content: [
                TextPart(text: 'a cat'),
                MediaPart(
                  media: Media(
                    url: 'data:image/png;base64,iVBORw0KGgo=',
                    contentType: 'image/png',
                  ),
                ),
              ],
            ),
          ],
          options: {'outputDimensionality': 128},
        ),
      );

      expect(
        mockClient.requestUrls
            .where((url) => url.host.contains('aiplatform'))
            .map((url) => url.toString()),
        everyElement(
          'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-embedding-2:embedContent',
        ),
      );
      // The other requests are the ADC token requests.
      final bodies = [
        for (final (i, url) in mockClient.requestUrls.indexed)
          if (url.path.endsWith(':embedContent'))
            jsonDecode(mockClient.requestBodies[i]) as Map<String, dynamic>,
      ];
      expect(bodies, hasLength(2));
      expect(bodies.first, {
        'content': {
          'role': 'user',
          'parts': [
            {'text': 'hello'},
          ],
        },
        'outputDimensionality': 128,
      });
      final mediaParts = (bodies.last['content'] as Map)['parts'] as List;
      expect(mediaParts, hasLength(2));
      expect((mediaParts.last as Map)['inlineData'], {
        'mimeType': 'image/png',
        'data': 'iVBORw0KGgo=',
      });
      // One embedding per document, in order.
      expect(response.result.embeddings.map((e) => e.embedding), [
        [1.1, 1.2],
        [2.1, 2.2],
      ]);
    });

    test('embedContent drops taskType and title with a warning', () async {
      resetDroppedConfigFieldWarnings();
      final warnings = <String>[];
      final subscription = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(subscription.cancel);
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      await _resolveEmbedder(plugin, 'gemini-embedding-2').run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
          ],
          options: {'taskType': 'RETRIEVAL_DOCUMENT', 'title': 'doc'},
        ),
      );

      final body = jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      expect(body, isNot(contains('taskType')));
      expect(body, isNot(contains('title')));
      expect(warnings, [
        "taskType is not supported by 'gemini-embedding-2' and was ignored.",
        "title is not supported by 'gemini-embedding-2' and was ignored.",
      ]);
    });

    test('newer and unlisted gemini-embedding-* names use embedContent; '
        'gemini-embedding-001 and the others use predict', () {
      for (final name in [
        'gemini-embedding-2',
        'gemini-embedding-2-preview',
        'gemini-embedding-3',
      ]) {
        expect(vertexUsesEmbedContent(name), isTrue, reason: name);
      }
      for (final name in [
        'gemini-embedding-001',
        'text-embedding-005',
        'text-embedding-004',
        'text-multilingual-embedding-002',
        'multimodalembedding@001',
      ]) {
        expect(vertexUsesEmbedContent(name), isFalse, reason: name);
      }
    });

    test(
      'uses predict directly for legacy gemini-embedding-001 inputs',
      () async {
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
            DocumentData(content: [TextPart(text: 'world')]),
          ],
        );

        final response = await embedder.run(req);

        expect(mockClient.lastUrl, isNotNull);
        expect(
          mockClient.lastUrl.toString(),
          'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-embedding-001:predict',
        );
        expect(
          mockClient.requestUrls.where(
            (url) => url.path.endsWith('gemini-embedding-001:embedContent'),
          ),
          isEmpty,
        );
        final requestBody =
            jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
        final instances = requestBody['instances'] as List;
        expect(instances, hasLength(2));
        expect(response.result.embeddings, hasLength(2));
        expect(response.result.embeddings[0].embedding, [0.4, 0.5, 0.6]);
        expect(response.result.embeddings[1].embedding, [1.4, 1.5, 1.6]);
      },
    );

    test('uses text predict REST option schema', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'text-embedding-005');
      final req = EmbedRequest(
        input: [
          DocumentData(content: [TextPart(text: 'hello')]),
        ],
        options: {
          'outputDimensionality': 256,
          'taskType': 'RETRIEVAL_DOCUMENT',
          'title': 'document title',
        },
      );

      await embedder.run(req);

      final requestBody =
          jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final instances = requestBody['instances'] as List;
      expect(instances.single, {
        'content': 'hello',
        'task_type': 'RETRIEVAL_DOCUMENT',
        'title': 'document title',
      });
      expect(requestBody['parameters'], {'outputDimensionality': 256});
    });

    test('throws when a text prediction omits embedding values', () async {
      final mockClient = MockHttpClient(returnInvalidTextPrediction: true);
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'text-embedding-005');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(content: [TextPart(text: 'hello')]),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains('Vertex AI returned an invalid prediction payload.'),
          ),
        ),
      );
    });

    test(
      'uses multimodal predict schema for text-only multimodal inputs',
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
        expect(response.result.embeddings.first.metadata, {
          'documentIndex': 0,
          'modality': 'text',
          'partIndices': [0],
        });
      },
    );

    test('flattens mixed multimodal outputs with source metadata', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');
      final req = EmbedRequest(
        input: [
          DocumentData(
            content: [
              TextPart(text: 'hello'),
              MediaPart(media: Media(url: 'data:image/png;base64,AA==')),
              MediaPart(media: Media(url: 'data:video/mp4;base64,AA==')),
            ],
          ),
          DocumentData(content: [TextPart(text: 'world')]),
        ],
      );

      final response = await embedder.run(req);

      final requestBody =
          jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final instances = requestBody['instances'] as List;
      expect(instances, hasLength(2));
      expect(instances.first, {
        'text': 'hello',
        'image': {'bytesBase64Encoded': 'AA==', 'mimeType': 'image/png'},
        'video': {'bytesBase64Encoded': 'AA==', 'mimeType': 'video/mp4'},
      });
      expect(instances[1], {'text': 'world'});

      final embeddings = response.result.embeddings;
      expect(embeddings, hasLength(4));
      expect(embeddings[0].embedding, [0.7, 0.8, 0.9]);
      expect(embeddings[0].metadata, {
        'documentIndex': 0,
        'modality': 'text',
        'partIndices': [0],
      });
      expect(embeddings[1].embedding, [1.7, 1.8, 1.9]);
      expect(embeddings[1].metadata, {
        'documentIndex': 0,
        'modality': 'image',
        'partIndex': 1,
      });
      expect(embeddings[2].embedding, [2.7, 2.8, 2.9]);
      expect(embeddings[2].metadata, {
        'documentIndex': 0,
        'modality': 'video',
        'partIndex': 2,
        'segmentIndex': 0,
        'startOffsetSec': 0,
        'endOffsetSec': 16,
      });
      expect(embeddings[3].embedding, [1.7, 1.8, 1.9]);
      expect(embeddings[3].metadata, {
        'documentIndex': 1,
        'modality': 'text',
        'partIndices': [0],
      });
    });

    test('uses data URI image inputs in multimodal predict requests', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(
              content: [
                MediaPart(media: Media(url: 'data:image/png;base64,AA==')),
              ],
            ),
          ],
        ),
      );

      final requestBody =
          jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final instances = requestBody['instances'] as List;
      expect(instances.single, {
        'image': {'bytesBase64Encoded': 'AA==', 'mimeType': 'image/png'},
      });
    });

    test('uses gs image inputs in multimodal predict requests', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(
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
        ),
      );

      final requestBody =
          jsonDecode(mockClient.lastBody!) as Map<String, dynamic>;
      final instances = requestBody['instances'] as List;
      expect(instances.single, {
        'image': {
          'gcsUri': 'gs://my-bucket/image.png',
          'mimeType': 'image/png',
        },
      });
    });

    test('throws when a multimodal data URI is malformed', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(
                content: [
                  MediaPart(
                    media: Media(
                      url: 'data:image/png;base64,%',
                      contentType: 'image/png',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains(
              'Vertex multimodalembedding media inputs require a valid data URI.',
            ),
          ),
        ),
      );
    });

    test('throws when a multimodal data URI MIME cannot be parsed', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(
                content: [
                  MediaPart(media: Media(url: 'data:image/png;base64,%')),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains(
              'Vertex multimodalembedding media inputs require a MIME type.',
            ),
          ),
        ),
      );
    });

    test('throws when a multimodal document has multiple images', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(
                content: [
                  MediaPart(media: Media(url: 'data:image/png;base64,AA==')),
                  MediaPart(media: Media(url: 'data:image/jpeg;base64,AA==')),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains(
              'Vertex multimodalembedding supports at most one image part per input document.',
            ),
          ),
        ),
      );
    });

    test('throws when multimodal media has an unsupported MIME type', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(
                content: [
                  MediaPart(media: Media(url: 'data:audio/wav;base64,AA==')),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains(
              'Unsupported Vertex multimodalembedding media MIME type: audio/wav',
            ),
          ),
        ),
      );
    });

    test('throws when multimodal media is missing a MIME type', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

      await expectLater(
        () => embedder.run(
          EmbedRequest(
            input: [
              DocumentData(
                content: [
                  MediaPart(media: Media(url: 'gs://my-bucket/image.png')),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (error) => error.message,
            'message',
            contains(
              'Vertex multimodalembedding media inputs require a MIME type.',
            ),
          ),
        ),
      );
    });

    test(
      'throws a descriptive error when Vertex returns no predictions',
      () async {
        final mockClient = MockHttpClient(returnEmptyPredictions: true);
        final plugin = VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'us-central1',
          authClient: mockClient,
        );

        final embedder = _resolveEmbedder(plugin, 'gemini-embedding-001');

        await expectLater(
          () => embedder.run(
            EmbedRequest(
              input: [
                DocumentData(content: [TextPart(text: 'hello')]),
              ],
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (error) => error.message,
              'message',
              contains('Vertex AI returned no predictions.'),
            ),
          ),
        );
      },
    );

    test(
      'throws when a multimodal response omits the expected embedding field',
      () async {
        final mockClient = MockHttpClient(
          returnMissingMultimodalEmbedding: true,
        );
        final plugin = VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'us-central1',
          authClient: mockClient,
        );

        final embedder = _resolveEmbedder(plugin, 'multimodalembedding');

        await expectLater(
          () => embedder.run(
            EmbedRequest(
              input: [
                DocumentData(content: [TextPart(text: 'hello')]),
              ],
            ),
          ),
          throwsA(
            isA<GenkitException>().having(
              (error) => error.message,
              'message',
              contains('did not return a text embedding'),
            ),
          ),
        );
      },
    );
  });
}
