// Copyright 2026 Google LLC
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
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/common_plugin.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Captures every embedContent request body the plugin puts on the wire and
/// serves a canned embedding response.
class _EmbedWirePlugin extends GoogleGenAiPluginImpl {
  final List<Map<String, dynamic>> captured;
  final List<Uri> urls;

  _EmbedWirePlugin(this.captured, this.urls) : super(apiKey: 'test-key');

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        urls.add(request.url);
        return http.Response(
          jsonEncode({
            'embedding': {
              'values': [0.1, 0.2, 0.3],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}

typedef _EmbedderAction = Action<EmbedRequest, EmbedResponse, void, void>;

GoogleGenAiPluginImpl _discoveryPlugin(List<Map<String, dynamic>> models) {
  return GoogleGenAiPluginImpl(
    apiKey: 'test-key',
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode({'models': models}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  group('isEmbedderModelName', () {
    test('classifies every embedding family, gemini-embedding included', () {
      expect(isEmbedderModelName('gemini-embedding-2'), isTrue);
      expect(isEmbedderModelName('gemini-embedding-2-preview'), isTrue);
      expect(isEmbedderModelName('gemini-embedding-001'), isTrue);
      expect(isEmbedderModelName('text-embedding-004'), isTrue);
      expect(isEmbedderModelName('embedding-gecko-001'), isTrue);
      expect(isEmbedderModelName('multimodalembedding'), isTrue);
    });

    test('leaves generative models unclassified', () {
      expect(isEmbedderModelName('gemini-2.0-flash'), isFalse);
      expect(isEmbedderModelName('gemini-2.5-pro'), isFalse);
      expect(isEmbedderModelName('gemma-3-27b-it'), isFalse);
    });
  });

  group('list() classification', () {
    final discovered = [
      {
        'name': 'models/gemini-2.0-flash',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-embedding-2',
        'supportedGenerationMethods': ['embedContent'],
      },
      {
        'name': 'models/text-embedding-004',
        'supportedGenerationMethods': ['embedContent'],
      },
      {
        'name': 'models/embedding-gecko-001',
        'supportedGenerationMethods': ['embedText'],
      },
      {
        'name': 'models/embedding-001',
        'description': 'A deprecated embedding model.',
        'supportedGenerationMethods': ['embedContent'],
      },
    ];

    test('routes gemini-embedding-* to the embedder path, not the model '
        'path', () async {
      final actions = await _discoveryPlugin(discovered).list();

      final embedders = actions
          .where((a) => a.actionType == 'embedder')
          .map((a) => a.name);
      final models = actions
          .where((a) => a.actionType == 'model')
          .map((a) => a.name);

      expect(embedders, contains('googleai/gemini-embedding-2'));
      expect(models, isNot(contains('googleai/gemini-embedding-2')));
      expect(models, contains('googleai/gemini-2.0-flash'));
    });

    test('lists only embedders that support embedContent', () async {
      final actions = await _discoveryPlugin(discovered).list();

      final embedders = actions
          .where((a) => a.actionType == 'embedder')
          .map((a) => a.name);
      final models = actions
          .where((a) => a.actionType == 'model')
          .map((a) => a.name);

      expect(embedders, contains('googleai/text-embedding-004'));
      expect(embedders, isNot(contains('googleai/embedding-gecko-001')));
      expect(models, isNot(contains('googleai/embedding-gecko-001')));
    });

    test('drops deprecated embedders', () async {
      final actions = await _discoveryPlugin(discovered).list();

      final embedders = actions
          .where((a) => a.actionType == 'embedder')
          .map((a) => a.name);
      expect(embedders, isNot(contains('googleai/embedding-001')));
    });
  });

  group('embedContent on the wire', () {
    test('maps media parts to inlineData alongside text', () async {
      final captured = <Map<String, dynamic>>[];
      final urls = <Uri>[];
      final plugin = _EmbedWirePlugin(captured, urls);
      final embedder =
          plugin.resolve('embedder', 'gemini-embedding-2')! as _EmbedderAction;

      final response = await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(
              content: [
                TextPart(text: 'hello'),
                MediaPart(media: Media(url: 'data:image/png;base64,AAAA')),
              ],
            ),
          ],
        ),
      );

      expect(
        urls.single.path,
        endsWith('models/gemini-embedding-2:embedContent'),
      );
      final content = captured.single['content'] as Map;
      expect(content['role'], 'user');
      final parts = content['parts'] as List;
      expect(parts, [
        {'text': 'hello'},
        {
          'inlineData': {'mimeType': 'image/png', 'data': 'AAAA'},
        },
      ]);
      expect(response.result.embeddings.single.embedding, [0.1, 0.2, 0.3]);
    });

    test('keeps contentType over the data-URI mime type', () async {
      final captured = <Map<String, dynamic>>[];
      final plugin = _EmbedWirePlugin(captured, <Uri>[]);
      final embedder =
          plugin.resolve('embedder', 'gemini-embedding-2')! as _EmbedderAction;

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(
              content: [
                MediaPart(
                  media: Media(
                    url: 'data:application/octet-stream;base64,AAAA',
                    contentType: 'video/mp4',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final parts = (captured.single['content'] as Map)['parts'] as List;
      expect(parts.single, {
        'inlineData': {'mimeType': 'video/mp4', 'data': 'AAAA'},
      });
    });

    test('sends one request per document and preserves order', () async {
      final captured = <Map<String, dynamic>>[];
      final plugin = _EmbedWirePlugin(captured, <Uri>[]);
      final embedder =
          plugin.resolve('embedder', 'gemini-embedding-2')! as _EmbedderAction;

      final response = await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'first')]),
            DocumentData(
              content: [
                MediaPart(media: Media(url: 'data:image/png;base64,AAAA')),
              ],
            ),
          ],
        ),
      );

      expect(captured, hasLength(2));
      expect((captured[0]['content'] as Map)['role'], 'user');
      expect(((captured[0]['content'] as Map)['parts'] as List).single, {
        'text': 'first',
      });
      expect(((captured[1]['content'] as Map)['parts'] as List).single, {
        'inlineData': {'mimeType': 'image/png', 'data': 'AAAA'},
      });
      expect(response.result.embeddings, hasLength(2));
    });

    test('still forwards embedder options on media requests', () async {
      final captured = <Map<String, dynamic>>[];
      final plugin = _EmbedWirePlugin(captured, <Uri>[]);
      final embedder =
          plugin.resolve('embedder', 'gemini-embedding-2')! as _EmbedderAction;

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(
              content: [
                MediaPart(media: Media(url: 'data:image/png;base64,AAAA')),
              ],
            ),
          ],
          options: {'outputDimensionality': 256, 'taskType': 'RETRIEVAL_QUERY'},
        ),
      );

      expect(captured.single['outputDimensionality'], 256);
      expect(captured.single['taskType'], 'RETRIEVAL_QUERY');
    });
  });
}
