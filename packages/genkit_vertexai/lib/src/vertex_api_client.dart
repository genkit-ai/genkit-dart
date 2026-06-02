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

const _vertexApiVersion = 'v1beta1';

@visibleForTesting
const vertexApiVersion = _vertexApiVersion;

@visibleForTesting
class VertexAiPluginImpl extends CommonGoogleGenPlugin {
  String? projectId;
  String? location;
  http.Client? authClient;
  List<String> tunedModelEndpoints;

  VertexAiPluginImpl({
    this.projectId,
    this.location,
    this.authClient,
    this.tunedModelEndpoints = const [],
  });

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

  Future<GenerativeLanguageBaseClient> _createVertexApiClient({
    String apiVersion = _vertexApiVersion,
    String pathSuffix = '',
  }) async {
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
        '$apiVersion/projects/$safeProjectId/locations/$safeLocation/$pathSuffix';

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
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return _createVertexApiClient(pathSuffix: 'publishers/google/');
  }

  Future<GenerativeLanguageBaseClient> getEndpointApiClient() async {
    return _createVertexApiClient();
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final service = await getApiClient();
    try {
      final res = await service.listPublisherModels(
        projectId: _getResolvedProjectId,
      );
      final publisherModels = (res['publisherModels'] as List?) ?? [];

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

      final tunedModels = tunedModelEndpoints
          .map(
            (endpointName) => modelMetadata(
              _endpointActionName(endpointName),
              customOptions: GeminiOptions.$schema,
              modelInfo: commonModelInfo,
            ),
          )
          .toList();

      return [...models, ...tunedModels, ...embedders];
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

  Model createTunedModel(String endpointName) {
    final endpointId = _endpointId(endpointName);
    final safeEndpointId = Uri.encodeComponent(endpointId);
    return createModel(
      endpointId,
      GeminiOptions.$schema,
      actionName: 'endpoints/$endpointId',
      apiModelName: 'endpoints/$safeEndpointId',
      getApiClientOverride: (_) => getEndpointApiClient(),
    );
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model' && name.startsWith('endpoints/')) {
      return createTunedModel(name);
    }
    return super.resolve(actionType, name);
  }
}

String _endpointId(String endpointName) {
  return endpointName.startsWith('endpoints/')
      ? endpointName.substring('endpoints/'.length)
      : endpointName;
}

String _endpointActionName(String endpointName) {
  return 'vertexai/endpoints/${_endpointId(endpointName)}';
}
