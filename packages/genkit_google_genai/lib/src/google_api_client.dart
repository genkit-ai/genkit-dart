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
    try {
      final service = await getApiClient();
      final gcl.ListModelsResponse modelsResponse;
      try {
        modelsResponse = await service.listModels(pageSize: 1000);
      } finally {
        service.client.close();
      }
      final discoveredNames = <String>{};
      final models = (modelsResponse.models ?? [])
          .where((model) {
            final modelName = model.name;
            if (modelName == null ||
                (!modelName.startsWith('models/gemini-') &&
                    !modelName.startsWith('models/gemma-')) ||
                isEmbedderModelName(modelName)) {
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
            return modelMetadata(
              '$name/$bareName',
              customOptions: GeminiModelFamily.of(bareName).customOptions,
              info: modelInfoFor(bareName),
            );
          })
          .toList();

      final curated = curatedModelMetadata(discoveredNames: discoveredNames);

      final embedders = (modelsResponse.models ?? [])
          .where(
            (model) =>
                model.name != null &&
                isEmbedderModelName(model.name!) &&
                // An absent list admits the embedder, matching the model
                // filter above.
                (model.supportedGenerationMethods?.contains('embedContent') ??
                    true) &&
                !(model.description?.toLowerCase().contains('deprecated') ??
                    false),
          )
          .map((model) {
            return embedderMetadata('$name/${model.name!.split('/').last}');
          })
          .toList();
      return [...models, ...curated, ...embedders];
    } catch (e, stack) {
      logger.warning('Failed to list models: $e', e, stack);
      return curatedModelMetadata().toList();
    }
  }

  @override
  Embedder createEmbedder(String embedderName) {
    return Embedder(
      name: '$name/$embedderName',
      fn: (req, ctx) async {
        if (req.input.isEmpty) {
          return EmbedResponse(embeddings: []);
        }
        final service = await getApiClient();
        try {
          final options = req.options != null
              ? GoogleGenAiEmbedderOptions.fromJson(req.options!)
              : null;

          final contents = [
            for (final (index, doc) in req.input.indexed)
              gcl.Content(role: 'user', parts: _embedParts(index, doc)),
          ];

          final futures = contents.map((content) async {
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
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          service.client.close();
        }
      },
    );
  }
}

/// Converts text and media, ignoring other parts for backward compatibility.
/// Text-only and empty documents retain the legacy single-text-part shape.
/// Malformed media fails before any request is sent, without leaking its source.
List<gcl.Part> _embedParts(int index, DocumentData doc) {
  final parts = doc.content.where((p) => p.isText || p.isMedia).toList();
  if (!parts.any((p) => p.isMedia)) {
    return [gcl.Part(text: parts.map((p) => p.text).join('\n'))];
  }
  try {
    return parts.map(toGeminiPart).toList();
  } on FormatException catch (e) {
    // The parser's source can contain media payloads; keep only its message.
    throw GenkitException(
      'Cannot embed the document at index $index: ${e.message}',
      status: StatusCode.invalidArgument,
    );
  }
}
