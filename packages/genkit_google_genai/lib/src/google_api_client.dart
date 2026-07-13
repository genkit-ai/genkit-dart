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

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'api_client.dart';
import 'common_plugin.dart';
import 'generated/generativelanguage.dart' as gcl;
import 'known_models.dart';
import 'model.dart';

@visibleForTesting
class GoogleGenAiPluginImpl extends CommonGoogleGenPlugin {
  String? apiKey;

  /// Test-only HTTP transport. When set it replaces the API-key client for
  /// every request (any per-request `apiKey` option is ignored) and is never
  /// closed by the plugin; the caller owns its lifecycle.
  @visibleForTesting
  final http.Client? httpClient;

  GoogleGenAiPluginImpl({this.apiKey, this.httpClient});

  @override
  String get name => 'googleai';

  @override
  final Map<String, ModelInfo> knownModels = knownGeminiModels;

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://generativelanguage.googleapis.com/',
      client: httpClient != null
          ? _NonClosingClient(httpClient!)
          : httpClientFromApiKey(requestApiKey ?? apiKey),
    );
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final service = await getApiClient();
    try {
      final gcl.ListModelsResponse modelsResponse;
      try {
        modelsResponse = await service.listModels(pageSize: 1000);
      } catch (e, stack) {
        logger.warning('Failed to list models: $e', e, stack);
        return knownModels.entries.map(_curatedModelMetadata).toList();
      }
      final discoveredNames = <String>{};
      final models = (modelsResponse.models ?? [])
          .where((model) {
            return model.name != null &&
                model.name!.startsWith('models/gemini-');
          })
          .map((model) {
            final bareName = model.name!.split('/').last;
            discoveredNames.add(bareName);
            final isTts = bareName.contains('-tts');
            return modelMetadata(
              '$name/$bareName',
              customOptions: isTts
                  ? GeminiTtsOptions.$schema
                  : GeminiOptions.$schema,
              modelInfo: modelInfoFor(bareName),
            );
          })
          .toList();

      // Curated models are listed even when model discovery omits them.
      final curated = knownModels.entries
          .where((entry) => !discoveredNames.contains(entry.key))
          .map(_curatedModelMetadata);

      final embedders = (modelsResponse.models ?? [])
          .where(
            (model) =>
                model.name != null &&
                (model.name!.startsWith('models/text-embedding-') ||
                    model.name!.startsWith('models/embedding-')),
          )
          .map((model) {
            return embedderMetadata('$name/${model.name!.split('/').last}');
          })
          .toList();
      return [...models, ...curated, ...embedders];
    } catch (e, stack) {
      if (e is GenkitException) rethrow;
      logger.warning('Failed to list models: $e', e, stack);
      throw handleException(e, stack);
    } finally {
      service.client.close();
    }
  }

  ActionMetadata<dynamic, dynamic, dynamic, dynamic> _curatedModelMetadata(
    MapEntry<String, ModelInfo> entry,
  ) {
    return modelMetadata(
      '$name/${entry.key}',
      customOptions: entry.key.contains('-tts')
          ? GeminiTtsOptions.$schema
          : GeminiOptions.$schema,
      modelInfo: entry.value,
    );
  }

  @override
  Embedder createEmbedder(String embedderName) {
    return Embedder(
      name: '$name/$embedderName',
      fn: (req, ctx) async {
        if (req == null || req.input.isEmpty) {
          return EmbedResponse(embeddings: []);
        }
        final service = await getApiClient();
        try {
          final options = req.options != null
              ? TextEmbedderOptions.fromJson(req.options!)
              : null;

          if (req.input.length == 1) {
            final doc = req.input.first;
            final text = doc.content
                .where((p) => p.isText)
                .map((p) => p.text)
                .join('\n');
            final content = gcl.Content(parts: [gcl.Part(text: text)]);
            final res = await service.embedContent(
              gcl.EmbedContentRequest(
                content: content,
                outputDimensionality: options?.outputDimensionality,
                taskType: options?.taskType,
                title: options?.title,
              ),
              model: 'models/$embedderName',
            );
            return EmbedResponse(
              embeddings: [Embedding(embedding: res.embedding?.values ?? [])],
            );
          } else {
            final futures = req.input.map((doc) async {
              final text = doc.content
                  .where((p) => p.isText)
                  .map((p) => p.text)
                  .join('\n');
              final content = gcl.Content(parts: [gcl.Part(text: text)]);
              final res = await service.embedContent(
                gcl.EmbedContentRequest(
                  content: content,
                  outputDimensionality: options?.outputDimensionality,
                  taskType: options?.taskType,
                  title: options?.title,
                ),
                model: 'models/$embedderName',
              );
              return Embedding(embedding: res.embedding?.values ?? []);
            });
            final embeddings = await Future.wait(futures);
            return EmbedResponse(embeddings: embeddings);
          }
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
    );
  }
}

/// Delegates to a caller-owned client but ignores `close()`, so the plugin's
/// per-call cleanup never tears down an injected transport.
class _NonClosingClient extends http.BaseClient {
  _NonClosingClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);
}
