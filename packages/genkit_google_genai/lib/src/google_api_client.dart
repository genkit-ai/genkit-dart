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
import 'package:meta/meta.dart';

import 'api_client.dart';
import 'common_plugin.dart';
import 'generated/generativelanguage.dart' as gcl;
import 'model.dart';

@visibleForTesting
class GoogleGenAiPluginImpl extends CommonGoogleGenPlugin {
  String? apiKey;

  GoogleGenAiPluginImpl({this.apiKey});

  @override
  String get name => 'googleai';

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://generativelanguage.googleapis.com/',
      client: httpClientFromApiKey(requestApiKey ?? apiKey),
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
        throw handleException(e, stack);
      }
      final models = (modelsResponse.models ?? [])
          .where((model) {
            return model.name != null &&
                model.name!.startsWith('models/gemini-');
          })
          .map((model) {
            final isTts = model.name!.contains('-tts');
            return modelMetadata(
              '$name/${model.name!.split('/').last}',
              customOptions: isTts
                  ? GeminiTtsOptions.$schema
                  : GeminiOptions.$schema,
              modelInfo: commonModelInfo,
            );
          })
          .toList();
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
      return [...models, ...embedders];
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
              final text = doc.content
                  .where((p) => p.isText)
                  .map((p) => p.text)
                  .join('\n');
                  .map((p) => p.toJson()['text'] as String?)
                  .nonNulls
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
