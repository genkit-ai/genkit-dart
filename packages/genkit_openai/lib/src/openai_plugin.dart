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
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart' as sdk;

import '../genkit_openai.dart';
import 'chat.dart' as chat;
import 'embed.dart' as embed;
// The compat variants and the embedder metadata are intentionally not part of
// the public surface.
import 'known_embedders.dart'
    show compatEmbedderInfo, embedderInfoFor, knownEmbedderModels;
import 'known_models.dart' show compatModelInfo;

final _logger = Logger('genkit_openai');

/// Core Genkit plugin implementation for OpenAI-compatible APIs.
///
/// Registers nothing up front beyond [customModels]: [resolve] builds a model
/// or an embedder on demand for any id. Discovery runs in [list], against
/// whichever host [baseUrl] names, and returns metadata rather than registered
/// actions.
class OpenAIPlugin extends GenkitPlugin {
  final String _pluginName;

  @override
  String get name => _pluginName;

  /// The static API key used to authenticate requests.
  final String? apiKey;

  /// An asynchronous callback that returns the API key on each request.
  final OpenAIApiKeyProvider? apiKeyProvider;

  /// Custom base URL for OpenAI-compatible APIs (e.g. Groq, DeepSeek).
  ///
  /// Streaming requests always send `stream_options.include_usage`; endpoints
  /// that reject unknown stream options will refuse streaming calls.
  final String? baseUrl;

  /// Additional models to register beyond those discovered from the API.
  final List<CustomModelDefinition> customModels;

  /// Extra HTTP headers sent with every request.
  final Map<String, String>? headers;

  /// Optional HTTP client for dependency injection and testing.
  final http.Client? httpClient;

  /// Looks up an environment variable, for the API key fallback.
  ///
  /// Injectable so a test can run against a known-empty environment: the
  /// package's own suite needs `OPENAI_API_KEY` exported for
  /// `integration_test.dart`, which would otherwise make the no-key tests
  /// pass or fail depending on the developer's shell.
  @visibleForTesting
  final String? Function(String name) configVar;

  /// Creates an [OpenAIPlugin].
  ///
  /// Provide either [apiKey] or [apiKeyProvider], but not both.
  OpenAIPlugin({
    String name = defaultOpenAINamespace,
    this.apiKey,
    this.apiKeyProvider,
    this.baseUrl,
    this.customModels = const [],
    this.headers,
    this.httpClient,
    this.configVar = getConfigVar,
  }) : _pluginName = name {
    if (name.isEmpty || name.contains('/')) {
      throw GenkitException(
        'Plugin name must be non-empty and must not contain "/". Got: "$name"',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    if (apiKey != null && apiKeyProvider != null) {
      throw GenkitException(
        'Provide either apiKey or apiKeyProvider, not both.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
  }

  /// Registers actions that need neither network access nor a key.
  ///
  /// Deliberately does no I/O. A throw here is not cached and is not caught
  /// per-plugin, so it fails every `listActions()` call for the whole
  /// registry - taking down the Dev UI, `/api/__health` included. Model
  /// discovery belongs in [list], where a failure degrades instead.
  ///
  /// Models are not registered up front: [resolve] builds them on demand for
  /// any id, so nothing is lost by staying offline here.
  @override
  Future<List<Action>> init() async => [
    for (final model in customModels) _createModel(model.name, model.info),
  ];

  /// Fetch available model IDs from OpenAI API
  Future<List<String>> _fetchAvailableModels(
    _ResolvedClientConfig resolvedConfig,
  ) async {
    final client = sdk.OpenAIClient.withApiKey(
      resolvedConfig.apiKey,
      baseUrl: resolvedConfig.baseUrl,
      defaultHeaders: resolvedConfig.headers,
      httpClient: httpClient,
    );

    try {
      final response = await client.models.list();
      final modelIds = <String>[];

      // Collect all model IDs
      for (final model in response.data) {
        modelIds.add(model.id);
      }

      return modelIds;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  Future<_ResolvedClientConfig> _resolveClientConfig() async {
    final config = await _resolveClientConfigOrNull();
    if (config == null) {
      throw GenkitException(
        '[$_pluginName] API key is required. Provide it via apiKey or apiKeyProvider '
        'in the plugin constructor, or set the $_apiKeyEnvVar environment variable.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return config;
  }

  /// Resolves the API key from, in order: [apiKeyProvider], [apiKey], then the
  /// `OPENAI_API_KEY` environment variable.
  ///
  /// Reads through [configVar] — `getConfigVar` by default — rather than
  /// `Platform.environment`, so the plugin stays usable on web and wasm,
  /// matching `genkit_google_genai`.
  Future<String?> _resolveApiKey() async {
    final configuredApiKeyProvider = apiKeyProvider;
    if (configuredApiKeyProvider != null) {
      return await configuredApiKeyProvider();
    }
    // A blank apiKey is treated as absent rather than short-circuiting the
    // fallback, so `apiKey: ''` still finds the environment variable.
    final configured = apiKey?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    final fromEnv = configVar(_apiKeyEnvVar)?.trim();
    return (fromEnv != null && fromEnv.isNotEmpty) ? fromEnv : null;
  }

  /// Client config for discovery, or null when no key is available.
  ///
  /// Lets [list] skip a request it knows would 401, without duplicating the
  /// key resolution that [_resolveClientConfig] does - notably without
  /// invoking [apiKeyProvider] twice for a single listing, which for a
  /// provider that mints a token per call would double its cost.
  Future<_ResolvedClientConfig?> _resolveClientConfigOrNull() async {
    final configuredApiKey = await _resolveApiKey();
    if (configuredApiKey == null || configuredApiKey.trim().isEmpty) {
      return null;
    }
    return _ResolvedClientConfig(
      apiKey: configuredApiKey.trim(),
      baseUrl: baseUrl,
      headers: headers,
    );
  }

  /// Lists the plugin's models and embedders, enriching the curated catalogs
  /// with whatever `GET /models` reports.
  ///
  /// Discovery is best-effort. Any failure - offline, bad key, a compatible
  /// host that does not serve `/models` - degrades to the curated catalog with
  /// a logged warning rather than throwing, so the Dev UI keeps working. A
  /// misconfigured key still fails loudly at generate time.
  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final discovered = <String>{};
    final discoveredEmbedders = <String>{};

    // Key resolution is inside the try on purpose: an apiKeyProvider that
    // throws must degrade like any other discovery failure, not take the
    // catalog down with it.
    try {
      // A keyless request is a guaranteed 401, so don't spend it.
      final config = await _resolveClientConfigOrNull();
      if (config != null) {
        for (final modelId in await _fetchAvailableModels(config)) {
          final modelType = getModelType(modelId);
          if (modelType == 'embedding') {
            discoveredEmbedders.add(modelId);
            continue;
          }
          if (modelType != 'chat' && modelType != 'unknown') {
            continue;
          }
          discovered.add(modelId);
        }
      }
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to list models from $_pluginName; '
        'falling back to the curated catalog: $e',
        e,
        stackTrace,
      );
    }

    // Curated models are listed even when discovery omits them, and custom
    // models are always listed - they need no discovery to be valid.
    //
    // The curated catalog is an OpenAI catalog, so it is withheld once a
    // baseUrl points somewhere else: a Groq or DeepSeek backend listing
    // `groq/gpt-5.5` and `groq/o3` offers the Dev UI a page of models that
    // host will 404 on. Compat backends are left with whatever `GET /models`
    // reports plus their own `models:`, and - as ever - resolve() still serves
    // any id named explicitly, so nothing becomes unreachable.
    final ids = <String>{
      ...discovered,
      if (baseUrl == null) ...knownChatModels,
      ...customModels.map((m) => m.name),
    };

    // Embedders follow the same rule for the same reason: discovery when
    // there is any, plus the curated catalog when the host is OpenAI itself.
    final embedderIds = <String>{
      ...discoveredEmbedders,
      if (baseUrl == null) ...knownEmbedderModels,
    };

    final infoOverrides = {
      for (final model in customModels)
        if (model.info != null) model.name: model.info!,
    };

    return [
      for (final id in ids)
        modelMetadata(
          '$_pluginName/$id',
          modelInfo: infoOverrides[id] ?? _infoFor(id),
          customOptions: chat.chatModelOptionsSchema(),
        ),
      for (final id in embedderIds) _embedderMetadata(id),
    ];
  }

  /// Listing metadata for the embedder [embedderName].
  ///
  /// Built from `embedderMetadata` rather than replacing it, so the label,
  /// description and options schema stay whatever core writes, and the
  /// curated entry only adds to them. The input and output schemas are named
  /// explicitly the way `genkit_vertexai` does; core's helper omits them.
  ActionMetadata<dynamic, dynamic, dynamic, dynamic> _embedderMetadata(
    String embedderName,
  ) {
    final base = embedderMetadata(
      '$_pluginName/$embedderName',
      customOptions: embed.embedderOptionsSchema(),
    );
    final metadata = {...base.metadata};
    metadata['model'] = <String, dynamic>{
      ...(metadata['model'] as Map).cast<String, dynamic>(),
      ..._embedderInfoFor(embedderName),
    };

    return ActionMetadata(
      name: base.name,
      description: base.description,
      actionType: base.actionType,
      inputSchema: EmbedRequest.$schema,
      outputSchema: EmbedResponse.$schema,
      metadata: metadata,
    );
  }

  /// Capability metadata for [modelName] on this plugin instance.
  ///
  /// A compat backend keeps the curated capabilities — a proxy serving
  /// `gpt-3.5-turbo` is serving that model, and calling it multimodal would
  /// invite image parts it rejects — but not OpenAI's deployment details. See
  /// `compatModelInfo` in `known_models.dart`.
  ModelInfo _infoFor(String modelName) =>
      baseUrl == null ? modelInfoFor(modelName) : compatModelInfo(modelName);

  /// Embedder metadata for [embedderName] on this plugin instance, split the
  /// same way [_infoFor] splits a model's.
  Map<String, dynamic> _embedderInfoFor(String embedderName) => baseUrl == null
      ? embedderInfoFor(embedderName)
      : compatEmbedderInfo(embedderName);

  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType == .model) {
      return _createModel(name, null);
    }
    if (actionType == .embedder) {
      return _createEmbedder(name);
    }
    return null;
  }

  /// Builds the embedder [embedderName] against `POST /v1/embeddings`.
  ///
  /// Like [_createModel], this resolves any name: an embedder released after
  /// this version of the plugin, or one a compatible host serves under a name
  /// OpenAI never used, works as soon as it is named.
  Embedder _createEmbedder(String embedderName) {
    return Embedder(
      name: '$_pluginName/$embedderName',
      customOptions: embed.embedderOptionsSchema(),
      metadata: {
        'model': {..._embedderInfoFor(embedderName)},
      },
      fn: (req, ctx) async {
        if (req == null || req.input.isEmpty) {
          // Nothing to embed, and an empty `input` is a 400. Answering
          // directly keeps `embedMany([])` from costing a request.
          return EmbedResponse(embeddings: []);
        }

        final options = embed.parseEmbedderOptions(req.options);
        embed.validateEmbedderDimensions(embedderName, options.dimensions);
        final inputs = embed.embeddingInputs(req.input);

        final resolvedConfig = await _resolveClientConfig();
        final client = sdk.OpenAIClient.withApiKey(
          resolvedConfig.apiKey,
          baseUrl: resolvedConfig.baseUrl,
          defaultHeaders: resolvedConfig.headers,
          httpClient: httpClient,
        );

        try {
          // Batches go out one at a time rather than in parallel: a corpus
          // large enough to need splitting is also large enough for a fan-out
          // to trip the account's rate limit.
          final embeddings = <Embedding>[];
          for (final batch in embed.embeddingBatches(inputs)) {
            final response = await client.embeddings.create(
              sdk.EmbeddingRequest(
                model: embedderName,
                input: sdk.EmbeddingInput.textList(batch),
                dimensions: options.dimensions,
                user: options.user,
              ),
            );
            embeddings.addAll(
              embed.toGenkitEmbeddings(response, expectedCount: batch.length),
            );
          }
          return EmbedResponse(embeddings: embeddings);
        } catch (e, stackTrace) {
          throw _toGenkitException(e, stackTrace);
        } finally {
          if (httpClient == null) {
            client.close();
          }
        }
      },
    );
  }

  Model _createModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? _infoFor(modelName);

    return Model(
      name: '$_pluginName/$modelName',
      customOptions: chat.chatModelOptionsSchema(),
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = chat.parseChatModelOptions(modelRequest.config);

        final resolvedConfig = await _resolveClientConfig();
        final client = sdk.OpenAIClient.withApiKey(
          resolvedConfig.apiKey,
          baseUrl: resolvedConfig.baseUrl,
          defaultHeaders: resolvedConfig.headers,
          httpClient: httpClient,
        );

        try {
          final tools = modelRequest.tools
              ?.map(GenkitConverter.toOpenAITool)
              .toList();

          final isJsonMode = chat.isJsonStructuredOutput(
            modelRequest.output?.format,
            modelRequest.output?.contentType,
          );
          final responseFormat = chat.buildOpenAIResponseFormat(
            modelRequest.output?.schema,
          );
          final request = sdk.ChatCompletionCreateRequest(
            model: options.version ?? modelName,
            messages: GenkitConverter.toOpenAIMessages(
              modelRequest.messages,
              options.visualDetailLevel,
            ),
            // Some OpenAI-compatible providers reject an empty tools array.
            tools: (tools == null || tools.isEmpty) ? null : tools,
            temperature: options.temperature,
            topP: options.topP,
            maxCompletionTokens: options.maxTokens,
            stop: options.stop,
            presencePenalty: options.presencePenalty,
            frequencyPenalty: options.frequencyPenalty,
            seed: options.seed,
            user: options.user,
            responseFormat: isJsonMode ? responseFormat : null,
          );
          if (ctx.streamingRequested) {
            return await _handleStreaming(client, request, ctx);
          } else {
            return await _handleNonStreaming(client, request);
          }
        } catch (e, stackTrace) {
          throw _toGenkitException(e, stackTrace);
        } finally {
          if (httpClient == null) {
            client.close();
          }
        }
      },
    );
  }

  /// Maps a failure from the OpenAI SDK onto a [GenkitException], preserving
  /// the HTTP status when there was one.
  ///
  /// Returned rather than thrown so the call sites keep their `throw`, which
  /// is what tells the analyzer control flow ends there.
  GenkitException _toGenkitException(Object e, StackTrace stackTrace) {
    if (e is GenkitException) return e;

    StatusCodes? status;
    String? details;

    if (e is sdk.ApiException) {
      status = StatusCodes.fromHttpStatus(e.statusCode);
      details = e.body?.toString();
    }

    return GenkitException(
      'OpenAI API error: $e',
      status: status,
      details: details ?? e.toString(),
      underlyingException: e,
      stackTrace: stackTrace,
    );
  }

  /// Handle streaming response
  Future<ModelResponse> _handleStreaming(
    sdk.OpenAIClient client,
    sdk.ChatCompletionCreateRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
  ) async {
    final streamRequest = request.copyWith(
      streamOptions: const sdk.StreamOptions(includeUsage: true),
    );
    final stream = client.chat.completions.createStream(streamRequest);
    final accumulator = sdk.ChatStreamAccumulator();

    try {
      await for (final chunk in stream) {
        accumulator.add(chunk);

        final textDelta = chunk.textDelta;
        if (textDelta != null) {
          ctx.sendChunk(
            ModelResponseChunk(index: 0, content: [TextPart(text: textDelta)]),
          );
        }
      }
    } catch (e, stackTrace) {
      if (e is GenkitException) rethrow;
      throw GenkitException(
        'Error in streaming: $e',
        underlyingException: e,
        stackTrace: stackTrace,
      );
    }

    final response = accumulator.toChatCompletion();
    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(choice.message);

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(choice.finishReason?.name),
      message: message,
      usage: GenkitConverter.mapUsage(response.usage),
      raw: response.toJson(),
    );
  }

  /// Handle non-streaming response
  Future<ModelResponse> _handleNonStreaming(
    sdk.OpenAIClient client,
    sdk.ChatCompletionCreateRequest request,
  ) async {
    final response = await client.chat.completions.create(request);

    if (response.choices.isEmpty) {
      throw GenkitException('Model returned no choices.');
    }

    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(choice.message);

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(choice.finishReason?.name),
      message: message,
      usage: GenkitConverter.mapUsage(response.usage),
      raw: response.toJson(),
    );
  }
}

/// Environment variable consulted for the API key.
const _apiKeyEnvVar = 'OPENAI_API_KEY';

final class _ResolvedClientConfig {
  final String apiKey;
  final String? baseUrl;
  final Map<String, String>? headers;

  const _ResolvedClientConfig({
    required this.apiKey,
    required this.baseUrl,
    required this.headers,
  });
}
