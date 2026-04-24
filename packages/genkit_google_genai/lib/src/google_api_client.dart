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
import 'imagen.dart';
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
      const predictMethods = ['predict', 'predictLongRunning'];
      final models = (modelsResponse.models ?? [])
          .where((model) {
            final n = model.name;
            if (n == null) return false;
            if (n.startsWith('models/gemini-')) return true;
            if (n.startsWith('models/imagen-')) {
              return (model.supportedGenerationMethods ?? const []).any(
                predictMethods.contains,
              );
            }
            return false;
          })
          .map((model) {
            final short = model.name!.split('/').last;
            if (isImagenModelName(short)) {
              return modelMetadata(
                '$name/$short',
                customOptions: ImagenOptions.$schema,
                modelInfo: imagenModelInfo,
              );
            }
            final isTts = short.contains('-tts');
            return modelMetadata(
              '$name/$short',
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
  Action? resolve(String actionType, String name) {
    if (actionType == 'model' && isImagenModelName(name)) {
      return createImagenModel(name);
    }
    return super.resolve(actionType, name);
  }

  Model createImagenModel(String modelName) {
    return Model(
      name: '$name/$modelName',
      customOptions: ImagenOptions.$schema,
      metadata: {'model': imagenModelInfo.toJson()},
      fn: (req, ctx) async {
        final options = req!.config == null
            ? ImagenOptions()
            : ImagenOptions.$schema.parse(req.config!);
        final service = await getApiClient(options.apiKey);
        try {
          final prompt = extractPrompt(req.messages);
          final image = extractImagenImage(req.messages);
          final body = <String, dynamic>{
            'instances': [
              {'prompt': prompt, 'image': ?image},
            ],
            'parameters': toImagenParameters(options),
          };
          final raw = await service.predict(body, model: 'models/$modelName');
          final predictions =
              (raw['predictions'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              const [];
          final parts = predictions
              .map(fromImagenPrediction)
              .whereType<MediaPart>()
              .toList();
          if (parts.isEmpty) {
            throw GenkitException(
              'Model returned no predictions. Possibly due to content filters.',
              status: StatusCodes.FAILED_PRECONDITION,
            );
          }
          return ModelResponse(
            finishReason: FinishReason('stop'),
            message: Message(role: Role.model, content: parts),
            raw: raw,
          );
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
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
