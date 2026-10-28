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
import 'embedders.dart';
import 'known_models.dart';

/// The request headers for the `payGo` option (JS vertexai defineModel):
/// the "-only" values use only PayGo (no Provisioned Throughput).
@visibleForTesting
Map<String, String> payGoHeaders(String? payGo) => switch (payGo) {
  'priority' => {'X-Vertex-AI-LLM-Shared-Request-Type': 'priority'},
  'priority-only' => {
    'X-Vertex-AI-LLM-Request-Type': 'shared',
    'X-Vertex-AI-LLM-Shared-Request-Type': 'priority',
  },
  'flex' => {'X-Vertex-AI-LLM-Shared-Request-Type': 'flex'},
  'flex-only' => {
    'X-Vertex-AI-LLM-Request-Type': 'shared',
    'X-Vertex-AI-LLM-Shared-Request-Type': 'flex',
  },
  _ => const {},
};

/// The API base URL for [location] (see `vertexApiHostForLocation`: global,
/// `us` / `eu` multi-regional and regional hosts, as in the JS plugin).
@visibleForTesting
String vertexBaseUrl(String location) =>
    'https://${vertexApiHostForLocation(location)}/';

@visibleForTesting
class VertexAiPluginImpl extends CommonGoogleGenPlugin {
  String? projectId;
  String? location;

  /// HTTP transport for credential and API calls. It is never closed by the
  /// plugin; the caller owns its lifecycle. Because close() is suppressed,
  /// cancellation cannot abort an in-flight request on an injected client.
  http.Client? authClient;

  /// Whether interactions are stored when a request doesn't set `store`;
  /// null when not set (= not stored). Only used by models on the
  /// Interactions API (the platform's generateContent has no `store`).
  @override
  final bool? store;

  VertexAiPluginImpl({
    this.projectId,
    this.location,
    this.authClient,
    this.store,
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

  @override
  final Map<String, ModelInfo> knownModels = vertexAiKnownModels;

  /// Known models pinned to generateContent stay there; other names use the
  /// Interactions API, except image and TTS models (see
  /// [vertexUsesInteractions]).
  @override
  bool usesInteractions(String modelName) => vertexUsesInteractions(modelName);

  /// Routes Lyria names to the Lyria model (as the JS vertexAI resolver
  /// does); everything else is a Gemini model.
  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType == .model && isLyriaModelName(name)) {
      return _lyriaModel(name);
    }
    return super.resolve(actionType, name);
  }

  /// No default response format: the platform returns the lyrics, caption
  /// and audio, and rejects an audio entry without a `bit_rate`.
  Model _lyriaModel(String modelName) => createLyriaModel(
    this,
    modelName,
    info: vertexLyriaModelInfo(modelName),
    defaultModalities: null,
  );

  ActionMetadata<dynamic, dynamic, dynamic, dynamic> _lyriaMetadata(
    String modelName,
  ) => modelMetadata(
    '$name/$modelName',
    customOptions: LyriaOptions.$schema,
    info: vertexLyriaModelInfo(modelName),
  );

  /// Metadata for the curated Lyria models not in [discovered].
  Iterable<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>
  _curatedLyriaMetadata({Set<String> discovered = const {}}) => [
    for (final modelName in vertexAiKnownLyriaModels.keys)
      if (!discovered.contains(modelName)) _lyriaMetadata(modelName),
  ];

  /// The platform accepts `safety_settings` on the Interactions API.
  @override
  bool get supportsInteractionSafetySettings => true;

  /// `location`, `labels`, `vertexRetrieval`, `payGo` and
  /// `videoFormat.gcsUri` are this plugin's options.
  @override
  bool get supportsVertexOptions => true;

  /// Server-side tool step types that are intentionally NOT sent back in a
  /// stateless history (`input`) on this platform (JS vertexai
  /// `UNSUPPORTED_RESENT_STEP_TYPES`).
  ///
  /// Resending them makes the platform return 501 "Operation is not
  /// implemented, or supported, or enabled" (seen live by the JS plugin, Oct
  /// 2026, whatever the step order, arguments or signature), while the
  /// Gemini API (googleAI) accepts the same history. `store: true`
  /// conversations work, because the steps stay on the server. Without them
  /// the model loses the earlier tool results (it may call the tool again).
  /// Only step types seen working are resent; code execution steps are
  /// accepted and are not listed here. Remove an entry once the platform
  /// accepts it.
  @override
  Set<String> get unsupportedResentStepTypes => const {
    // Rejected with 501 (seen live).
    'google_search_call',
    'google_search_result',
    'url_context_call',
    'url_context_result',
    'google_maps_call',
    'google_maps_result',
    // Not seen working here (untestable or not available for models).
    'file_search_call',
    'file_search_result',
    'mcp_server_tool_call',
    'mcp_server_tool_result',
  };

  /// TTS models use generateContent here, so nothing asks for audio by
  /// default on the Interactions API.
  @override
  bool get defaultsTtsToAudio => false;

  /// TTS models use generateContent here: `audioFormat` is sent as its
  /// `responseFormat` and streamed audio is joined (JS vertexAI).
  @override
  bool get generateContentTtsFormats => true;

  /// The plugin location, `global` when not set.
  String get _resolvedLocation => location ?? 'global';

  /// Applies the request's `location` (overrides the plugin location) and
  /// `payGo` (consumption headers, JS vertexai defineModel).
  @override
  Future<GenerativeLanguageBaseClient> getApiClientForRequest(
    Map<String, dynamic>? config,
  ) {
    final options = config == null ? null : GeminiOptions.$schema.parse(config);
    final requestLocation = options?.location;
    return _apiClient(
      location: requestLocation == null || requestLocation.isEmpty
          ? null
          : requestLocation,
      headers: payGoHeaders(options?.payGo),
    );
  }

  /// The data store path, filled in from the plugin project and location
  /// when the request doesn't set them (JS vertexai
  /// toVertexAISearchDatastore). A per-request `location` isn't used (same
  /// as JS).
  // TODO: Regional locations (e.g. us-central1) aren't data store locations
  // (those are global, us and eu); falling back to one probably fails on the
  // server. Kept as in JS until checked live.
  @override
  String vertexSearchDatastore(GeminiVertexDatastore datastore) {
    final projectId = datastore.projectId?.isNotEmpty ?? false
        ? datastore.projectId!
        : _getResolvedProjectId;
    final location = datastore.location?.isNotEmpty ?? false
        ? datastore.location!
        : _resolvedLocation;
    if (datastore.dataStoreId.isEmpty) {
      throw GenkitException(
        'projectId, location and datastoreId are required for '
        'vertexRetrieval and could not be determined from configuration',
        status: StatusCode.invalidArgument,
      );
    }
    return 'projects/$projectId/locations/$location/collections/'
        'default_collection/dataStores/${datastore.dataStoreId}';
  }

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([String? requestApiKey]) =>
      _apiClient();

  Future<GenerativeLanguageBaseClient> _apiClient({
    String? location,
    Map<String, String> headers = const {},
  }) async {
    final validFormat = RegExp(r'^[a-z0-9-]+$');
    final resolvedProjectId = _getResolvedProjectId;
    final resolvedLocation = location ?? _resolvedLocation;

    if (!validFormat.hasMatch(resolvedLocation) ||
        !validFormat.hasMatch(resolvedProjectId)) {
      throw ArgumentError('Invalid projectId or location format.');
    }
    final safeLocation = Uri.encodeComponent(resolvedLocation);
    final safeProjectId = Uri.encodeComponent(resolvedProjectId);

    final caller = authClient;
    final injected = caller == null ? null : NonClosingClient(caller);

    final tokenProvider = createAdcAccessTokenProvider(baseClient: injected);

    final baseUrl = vertexBaseUrl(safeLocation);
    final parent = 'v1beta1/projects/$safeProjectId/locations/$safeLocation/';
    final apiUrlPrefix = '${parent}publishers/google/';

    final customClient = CustomClient(
      defaultHeaders: {
        'X-Goog-Api-Client': googleApiClientHeaderValue(),
        ...headers,
      },
      inner: injected,
    );
    final client = VertexAuthClient(tokenProvider, inner: customClient);

    return GenerativeLanguageBaseClient(
      baseUrl: baseUrl,
      client: client,
      apiUrlPrefix: apiUrlPrefix,
      // Under the project and location, not under the publisher models
      // (JS vertexai getInteractionsResourcePath).
      interactionsPath: '${parent}interactions',
    );
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    try {
      final service = await getApiClient();
      final Map<String, dynamic> res;
      try {
        res = await service.listPublisherModels(
          projectId: _getResolvedProjectId,
        );
      } finally {
        service.client.close();
      }
      final publisherModels = (res['publisherModels'] as List?) ?? [];

      final discoveredNames = <String>{};
      final models = publisherModels
          .where((m) {
            final modelMap = m as Map<String, dynamic>;
            final name = modelMap['name'] as String?;
            return name != null && name.contains('gemini-');
          })
          .map((m) {
            final modelMap = m as Map<String, dynamic>;
            final modelName = (modelMap['name'] as String).split('/').last;
            discoveredNames.add(modelName);
            return modelMetadata(
              '$name/$modelName',
              customOptions: GeminiModelFamily.of(modelName).customOptions,
              info: modelInfoFor(modelName),
            );
          })
          .toList();

      final curated = curatedModelMetadata(discoveredNames: discoveredNames);

      // lyria-002 (`:predict`) isn't supported, so it isn't listed.
      final discoveredLyria = <String>{
        for (final m in publisherModels.whereType<Map>())
          if (m['name'] case final String fullName)
            if (fullName.split('/').last case final modelName
                when isLyriaModelName(modelName) && modelName != 'lyria-002')
              modelName,
      };
      final lyria = [
        ...discoveredLyria.map(_lyriaMetadata),
        ..._curatedLyriaMetadata(discovered: discoveredLyria),
      ];

      final embedders = listVertexEmbedders(
        pluginName: name,
        publisherModels: publisherModels,
      );

      return [...models, ...curated, ...lyria, ...embedders];
    } catch (e, stack) {
      logger.warning('Failed to list models: $e', e, stack);
      return [
        ...curatedModelMetadata(),
        ..._curatedLyriaMetadata(),
        ...listVertexEmbedders(pluginName: name),
      ];
    }
  }

  @override
  Embedder createEmbedder(String embedderName) {
    return createVertexEmbedder(
      pluginName: name,
      embedderName: embedderName,
      getApiClient: getApiClient,
      handleException: handleException,
    );
  }
}
