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
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_vertex_auth/genkit_vertex_auth.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'auth.dart';
import 'meta_model.dart';

@visibleForTesting
class VertexAiPluginImpl extends CommonGoogleGenPlugin {
  String? projectId;
  String? location;
  http.Client? authClient;

  VertexAiPluginImpl({this.projectId, this.location, this.authClient});

  String? _resolvedProjectId;
  String get _getResolvedProjectId =>
      _resolvedProjectId ??= resolveVertexProjectId(
        providerName: 'vertexai',
        configTypeName: 'plugin configuration',
        projectId: projectId,
        projectIdFromCredentials: null,
      );

  @override
  String get name => 'vertexai';

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    final validFormat = RegExp(r'^[a-z0-9-]+$');
    final resolvedProjectId = _getResolvedProjectId;
    final resolvedLocation = location ?? 'global';

    if (!validFormat.hasMatch(resolvedLocation) ||
        !validFormat.hasMatch(resolvedProjectId)) {
      throw ArgumentError('Invalid projectId or location format.');
    }
    final safeLocation = Uri.encodeComponent(resolvedLocation);
    final safeProjectId = Uri.encodeComponent(resolvedProjectId);

    final tokenProvider = createAdcAccessTokenProvider(baseClient: authClient);

    final baseUrl = safeLocation == 'global'
        ? 'https://aiplatform.googleapis.com/'
        : 'https://$safeLocation-aiplatform.googleapis.com/';
    final apiUrlPrefix =
        'v1beta1/projects/$safeProjectId/locations/$safeLocation/publishers/google/';

    final headers = {'X-Goog-Api-Client': googleApiClientHeaderValue()};
    final customClient = CustomClient(
      defaultHeaders: headers,
      inner: authClient,
    );
    final client = VertexAuthClient(tokenProvider, inner: customClient);

    return GenerativeLanguageBaseClient(
      baseUrl: baseUrl,
      client: client,
      apiUrlPrefix: apiUrlPrefix,
    );
  }

  Future<GenerativeLanguageBaseClient> getOpenModelApiClient() async {
    final validFormat = RegExp(r'^[a-z0-9-]+$');
    final resolvedProjectId = _getResolvedProjectId;
    final resolvedLocation = location ?? 'global';

    if (!validFormat.hasMatch(resolvedLocation) ||
        !validFormat.hasMatch(resolvedProjectId)) {
      throw ArgumentError('Invalid projectId or location format.');
    }
    final safeLocation = Uri.encodeComponent(resolvedLocation);
    final safeProjectId = Uri.encodeComponent(resolvedProjectId);

    final tokenProvider = createAdcAccessTokenProvider(baseClient: authClient);

    final baseUrl = safeLocation == 'global'
        ? 'https://aiplatform.googleapis.com/'
        : 'https://$safeLocation-aiplatform.googleapis.com/';
    final apiUrlPrefix =
        'v1beta1/projects/$safeProjectId/locations/$safeLocation/endpoints/openapi/';

    final headers = {'X-Goog-Api-Client': googleApiClientHeaderValue()};
    final customClient = CustomClient(
      defaultHeaders: headers,
      inner: authClient,
    );
    final client = VertexAuthClient(tokenProvider, inner: customClient);

    return GenerativeLanguageBaseClient(
      baseUrl: baseUrl,
      client: client,
      apiUrlPrefix: apiUrlPrefix,
    );
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final service = await getApiClient();
    try {
      final publisherModels = await _listPublisherModels(service, 'google');
      final metaPublisherModels = await _listPublisherModels(
        service,
        'meta',
        warnOnFailure: true,
      );

      final models = publisherModels
          .where((m) {
            final modelMap = m as Map<String, dynamic>;
            final name = modelMap['name'] as String?;
            return name != null && name.contains('gemini-');
          })
          .map((m) {
            final modelMap = m as Map<String, dynamic>;
            final modelName = (modelMap['name'] as String).split('/').last;
            final isTts = modelName.contains('-tts');
            return modelMetadata(
              '$name/$modelName',
              customOptions: isTts
                  ? GeminiTtsOptions.$schema
                  : GeminiOptions.$schema,
              modelInfo: commonModelInfo,
            );
          })
          .toList();

      final metaModels = metaPublisherModels
          .where((m) {
            final modelMap = m as Map<String, dynamic>;
            final name = modelMap['name'] as String?;
            return name != null && name.contains('llama-');
          })
          .map((m) {
            final modelMap = m as Map<String, dynamic>;
            final modelName = (modelMap['name'] as String).split('/').last;
            return modelMetadata(
              '$name/$modelName',
              customOptions: VertexAiMetaOptions.$schema,
              modelInfo: metaModelInfo,
            );
          })
          .toList();

      final embedders = publisherModels
          .where((m) {
            final modelMap = m as Map<String, dynamic>;
            final name = modelMap['name'] as String?;
            return name != null &&
                (name.contains('text-embedding-') ||
                    name.contains('embedding-'));
          })
          .map((m) {
            final modelMap = m as Map<String, dynamic>;
            final modelName = (modelMap['name'] as String).split('/').last;
            return embedderMetadata('$name/$modelName');
          })
          .toList();

      return [...models, ...metaModels, ...embedders];
    } catch (e, stack) {
      if (e is GenkitException) rethrow;
      logger.warning('Failed to list models: $e', e, stack);
      throw handleException(e, stack);
    } finally {
      if (authClient == null) {
        service.client.close();
      }
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

          final instances = req.input.map((doc) {
            final text = doc.content
                .where((p) => p.isText)
                .map((p) => p.text)
                .join('\n');
            return {'content': text};
          }).toList();

          final parameters = <String, dynamic>{};
          if (options?.outputDimensionality != null) {
            parameters['outputDimensionality'] = options!.outputDimensionality;
          }
          if (options?.taskType != null) {
            parameters['taskType'] = options!.taskType;
          }

          final res = await service.predict({
            'instances': instances,
            if (parameters.isNotEmpty) 'parameters': parameters,
          }, model: 'models/$embedderName');

          final predictions = res['predictions'] as List;
          final embeddings = predictions.map((p) {
            final emb =
                (p as Map<String, dynamic>)['embeddings']
                    as Map<String, dynamic>;
            final vals = emb['values'] as List;
            return Embedding(
              embedding: vals.map((e) => (e as num).toDouble()).toList(),
            );
          }).toList();
          return EmbedResponse(embeddings: embeddings);
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          if (authClient == null) {
            service.client.close();
          }
        }
      },
    );
  }

  Model createMetaModel(String modelName) {
    final actionModelName = modelName.startsWith('meta/')
        ? modelName.substring(5)
        : modelName;
    final resolvedModelName = 'meta/$actionModelName';

    return Model(
      name: '$name/$actionModelName',
      customOptions: VertexAiMetaOptions.$schema,
      metadata: {'model': metaModelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = modelRequest.config == null
            ? VertexAiMetaOptions()
            : VertexAiMetaOptions.$schema.parse(modelRequest.config!);
        final service = await getOpenModelApiClient();

        try {
          final request = toMetaChatCompletionRequest(
            modelRequest,
            resolvedModelName,
            options,
            stream: ctx.streamingRequested,
          );
          if (ctx.streamingRequested) {
            final chunks = <Map<String, dynamic>>[];
            await for (final chunk in service.streamChatCompletions(request)) {
              chunks.add(chunk);
              final choices = chunk['choices'] as List?;
              if (choices == null || choices.isEmpty) continue;
              final choice = choices.first as Map<String, dynamic>;
              final delta = choice['delta'] as Map<String, dynamic>?;
              final text = delta?['content'] as String?;
              if (text != null && text.isNotEmpty) {
                ctx.sendChunk(
                  ModelResponseChunk(index: 0, content: [TextPart(text: text)]),
                );
              }
            }
            return fromMetaChatCompletionChunks(chunks);
          }

          final response = await service.chatCompletions(request);
          return fromMetaChatCompletionResponse(response);
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          if (authClient == null) {
            service.client.close();
          }
        }
      },
    );
  }

  Future<List<dynamic>> _listPublisherModels(
    GenerativeLanguageBaseClient service,
    String publisher, {
    bool warnOnFailure = false,
  }) async {
    try {
      final res = await service.listPublisherModels(
        projectId: _getResolvedProjectId,
        publisher: publisher,
      );
      return (res['publisherModels'] as List?) ?? [];
    } catch (e, stack) {
      if (!warnOnFailure) rethrow;
      logger.warning('Failed to list $publisher models: $e', e, stack);
      return [];
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model' &&
        (name.startsWith('meta/') || name.startsWith('llama-'))) {
      return createMetaModel(name);
    }
    return super.resolve(actionType, name);
  }
}
