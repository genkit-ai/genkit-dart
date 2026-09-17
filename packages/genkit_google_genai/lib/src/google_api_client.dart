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
    final injected = httpClient;
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://generativelanguage.googleapis.com/',
      client: injected != null
          ? NonClosingClient(injected)
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
        // Any discovery failure (network, auth, quota) degrades to the curated
        // catalog rather than rethrowing; a misconfigured key still fails
        // loudly at generate time.
        logger.warning('Failed to list models: $e', e, stack);
        return curatedModelMetadata().toList();
      }
      final discoveredNames = <String>{};
      final models = (modelsResponse.models ?? [])
          .where((model) {
            final modelName = model.name;
            if (modelName == null ||
                (!modelName.startsWith('models/gemini-') &&
                    !modelName.startsWith('models/gemma-'))) {
              return false;
            }
            // An absent list is no claim either way, so it admits the model
            // rather than excluding it: a field the API stops sending must not
            // empty the catalogue.
            final methods = model.supportedGenerationMethods;
            return methods?.contains('generateContent') ?? true;
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

      final curated = curatedModelMetadata(discoveredNames: discoveredNames);

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
