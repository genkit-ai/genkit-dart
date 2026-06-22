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
import 'package:ollama_dart/ollama_dart.dart' as sdk;

import '../genkit_ollama.dart';
import 'chat.dart' as chat;

/// Default address of a local Ollama server.
const String defaultOllamaBaseUrl = 'http://localhost:11434';

/// Core Genkit plugin implementation for the Ollama API.
///
/// Models and embedders can be referenced directly (via [ollama]) and are
/// resolved on demand. Local models are also discoverable via [list], which
/// reads `/api/tags` and enriches each entry with accurate capability metadata
/// from `/api/show`.
class OllamaPlugin extends GenkitPlugin {
  final String _pluginName;

  @override
  String get name => _pluginName;

  /// Base URL of the Ollama server. Defaults to [defaultOllamaBaseUrl].
  final String baseUrl;

  /// Static headers sent with every request.
  final Map<String, String>? headers;

  /// Async callback returning headers (e.g. a bearer token) per request.
  final OllamaHeadersProvider? headersProvider;

  /// Models registered eagerly at init time, beyond on-demand resolution.
  final List<CustomModelDefinition> customModels;

  /// Embedders registered eagerly at init time.
  final List<OllamaEmbedderDefinition> customEmbedders;

  /// Optional HTTP client for dependency injection and testing.
  final http.Client? httpClient;

  /// Creates an [OllamaPlugin].
  OllamaPlugin({
    String name = defaultOllamaNamespace,
    String? baseUrl,
    this.headers,
    this.headersProvider,
    this.customModels = const [],
    this.customEmbedders = const [],
    this.httpClient,
  }) : _pluginName = name,
       baseUrl = baseUrl ?? defaultOllamaBaseUrl {
    if (name.isEmpty || name.contains('/')) {
      throw GenkitException(
        'Plugin name must be non-empty and must not contain "/". Got: "$name"',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
  }

  @override
  Future<List<Action>> init() async {
    final actions = <Action>[];
    for (final model in customModels) {
      actions.add(_createModel(model.name, model.info));
    }
    for (final embedder in customEmbedders) {
      actions.add(_createEmbedder(embedder.name, embedder.dimensions));
    }
    return actions;
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model') {
      return _createModel(name, null);
    }
    if (actionType == 'embedder') {
      return _createEmbedder(name, null);
    }
    return null;
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    final client = await _buildClient();
    try {
      final tags = await client.models.list();
      final summaries = tags.models ?? const [];

      final metadataResults = await Future.wait(
        summaries.map((summary) async {
          final modelId = summary.model;
          if (modelId == null || modelId.isEmpty) return null;
          try {
            final show = await client.models.show(
              request: sdk.ShowRequest(model: modelId),
            );
            if (isEmbedderShow(show)) {
              return _embedderMetadata(
                modelId,
                embeddingDimensionsFromShow(show),
              );
            }
            return modelMetadata(
              '$_pluginName/$modelId',
              modelInfo: modelInfoFromShow(modelId, show),
              customOptions: chat.chatModelOptionsSchema(),
            );
          } catch (_) {
            // Fall back to a generic profile when /api/show fails.
            return modelMetadata(
              '$_pluginName/$modelId',
              modelInfo: genericModelInfo(modelId),
              customOptions: chat.chatModelOptionsSchema(),
            );
          }
        }),
      );

      return metadataResults
          .whereType<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>()
          .toList();
    } catch (e, stackTrace) {
      throw GenkitException(
        'Error listing models from $_pluginName. '
        'Make sure the Ollama server is running at $baseUrl. ($e)',
        underlyingException: e,
        stackTrace: stackTrace,
      );
    } finally {
      if (httpClient == null) client.close();
    }
  }

  Future<sdk.OllamaClient> _buildClient() async {
    final resolvedHeaders = <String, String>{
      ...?headers,
      ...?(await headersProvider?.call()),
    };
    return sdk.OllamaClient(
      config: sdk.OllamaConfig(
        baseUrl: baseUrl,
        defaultHeaders: resolvedHeaders,
      ),
      httpClient: httpClient,
    );
  }

  /// Builds embedder discovery metadata, including the auto-detected embedding
  /// [dimensions] from `/api/show` when available.
  ActionMetadata<dynamic, dynamic, dynamic, dynamic> _embedderMetadata(
    String modelId,
    int? dimensions,
  ) {
    final name = '$_pluginName/$modelId';
    return ActionMetadata(
      name: name,
      description: name,
      actionType: 'embedder',
      metadata: {
        'label': name,
        'description': name,
        'model': {
          'label': name,
          'dimensions': ?dimensions,
          'supports': {
            'input': ['text'],
          },
        },
      },
    );
  }

  Model _createModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? genericModelInfo(modelName);

    return Model(
      name: '$_pluginName/$modelName',
      customOptions: chat.chatModelOptionsSchema(),
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = chat.parseChatModelOptions(modelRequest.config);
        final tools = modelRequest.tools;

        final request = sdk.ChatRequest(
          model: modelName,
          messages: GenkitConverter.toOllamaMessages(modelRequest.messages),
          tools: (tools != null && tools.isNotEmpty)
              ? tools.map(GenkitConverter.toOllamaTool).toList()
              : null,
          format: GenkitConverter.buildResponseFormat(modelRequest.output),
          options: GenkitConverter.buildModelOptions(options),
          keepAlive: GenkitConverter.buildKeepAlive(options.keepAlive),
          stream: ctx.streamingRequested,
        );

        final client = await _buildClient();
        try {
          if (ctx.streamingRequested) {
            return await _generateStream(client, request, ctx.sendChunk);
          }
          final response = await client.chat.create(request: request);
          return ModelResponse(
            finishReason: GenkitConverter.mapDoneReason(response.doneReason),
            message: GenkitConverter.fromOllamaMessage(response.message),
            raw: response.toJson(),
          );
        } catch (e, stackTrace) {
          throw _wrapError(
            e,
            stackTrace,
            'Ollama API error for model "$modelName". '
            'Make sure the Ollama server is running at $baseUrl '
            'and the model is pulled.',
          );
        } finally {
          if (httpClient == null) client.close();
        }
      },
    );
  }

  /// Wraps an arbitrary error into a [GenkitException], rethrowing existing
  /// ones and mapping the Ollama SDK's HTTP status onto a [StatusCodes].
  GenkitException _wrapError(Object e, StackTrace stackTrace, String message) {
    if (e is GenkitException) return e;
    StatusCodes? status;
    if (e is sdk.ApiException) {
      status = StatusCodes.fromHttpStatus(e.statusCode);
    }
    return GenkitException(
      '$message ($e)',
      status: status,
      underlyingException: e,
      stackTrace: stackTrace,
    );
  }

  Future<ModelResponse> _generateStream(
    sdk.OllamaClient client,
    sdk.ChatRequest request,
    void Function(ModelResponseChunk) sendChunk,
  ) async {
    final textBuffer = StringBuffer();
    sdk.ChatResponseMessage? lastMessage;
    sdk.DoneReason? doneReason;
    sdk.ChatStreamEvent? lastEvent;

    await for (final event in client.chat.createStream(request: request)) {
      lastEvent = event;
      final message = event.message;
      if (message != null) {
        lastMessage = message;
        final content = message.content;
        if (content != null && content.isNotEmpty) {
          textBuffer.write(content);
          sendChunk(
            ModelResponseChunk(index: 0, content: [TextPart(text: content)]),
          );
        }
      }
      if (event.doneReason != null) doneReason = event.doneReason;
    }

    // Reconstruct the aggregated message: streamed text plus any tool calls
    // surfaced on the final event.
    final aggregated = sdk.ChatResponseMessage(
      role: sdk.MessageRole.assistant,
      content: textBuffer.toString(),
      toolCalls: lastMessage?.toolCalls,
    );

    return ModelResponse(
      finishReason: GenkitConverter.mapDoneReason(doneReason),
      message: GenkitConverter.fromOllamaMessage(aggregated),
      raw: lastEvent?.toJson(),
    );
  }

  Embedder _createEmbedder(String embedderName, int? dimensions) {
    return Embedder(
      name: '$_pluginName/$embedderName',
      metadata: {
        'model': {
          'label': '$_pluginName/$embedderName',
          'dimensions': ?dimensions,
          'supports': {
            'input': ['text'],
          },
        },
      },
      fn: (req, ctx) async {
        final embedRequest = req!;
        final texts = embedRequest.input
            .map(GenkitConverter.documentText)
            .toList();

        final client = await _buildClient();
        try {
          final response = await client.embeddings.create(
            request: sdk.EmbedRequest(
              model: embedderName,
              input: sdk.EmbedInput.list(texts),
            ),
          );
          final vectors = response.embeddings ?? const [];
          return EmbedResponse(
            embeddings: vectors
                .map((vector) => Embedding(embedding: vector))
                .toList(),
          );
        } catch (e, stackTrace) {
          throw _wrapError(
            e,
            stackTrace,
            'Ollama embedding error for model "$embedderName". '
            'Make sure the Ollama server is running at $baseUrl '
            'and the model is pulled.',
          );
        } finally {
          if (httpClient == null) client.close();
        }
      },
    );
  }
}
