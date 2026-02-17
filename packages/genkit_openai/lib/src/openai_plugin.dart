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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;

import '../genkit_openai.dart';

/// Internal tool call accumulator for streaming responses
class _ToolCallAccumulator {
  String id;
  String name;
  final StringBuffer arguments = StringBuffer();

  _ToolCallAccumulator(this.id, this.name);

  /// Update ID if a non-empty value is provided
  void updateId(String? newId) {
    if (newId != null && newId.isNotEmpty) {
      id = newId;
    }
  }

  /// Update name if a non-empty value is provided
  void updateName(String? newName) {
    if (newName != null && newName.isNotEmpty) {
      name = newName;
    }
  }

  /// Validate that the accumulator has valid ID and name before emitting
  bool isValid() {
    return id.isNotEmpty && name.isNotEmpty;
  }
}

/// Core plugin implementation
class OpenAIPlugin extends GenkitPlugin {
  @override
  String get name => 'openai';

  final String? apiKey;
  final String? baseUrl;
  final List<CustomModelDefinition> customModels;
  final Map<String, String>? headers;

  OpenAIPlugin({
    this.apiKey,
    this.baseUrl,
    this.customModels = const [],
    this.headers,
  });

  @override
  Future<List<Action>> init() async {
    final actions = <Action>[];

    // Fetch and register models from OpenAI API if using default baseUrl
    if (baseUrl == null) {
      try {
        final availableModelIds = await _fetchAvailableModels();

        for (final modelId in availableModelIds) {
          final modelType = getModelType(modelId);

          if (modelType != 'chat' && modelType != "unknown") {
            continue;
          }

          final info = _getModelInfo(modelId);
          actions.add(_createModel(modelId, info));
        }
      } catch (e) {
        throw GenkitException(
          'Error fetching available models from OpenAI: $e',
          underlyingException: e,
        );
      }
    }

    // Register custom models
    for (final model in customModels) {
      actions.add(_createModel(model.name, model.info));
    }

    return actions;
  }

  /// Determines the type of model based on its ID.
  ///
  /// Returns one of the following model types:
  /// - 'chat': Chat completion models (gpt-4, gpt-4o, o1, etc.)
  /// - 'embedding': Text embedding models
  /// - 'audio': Audio processing models (TTS, transcription, realtime)
  /// - 'image': Image generation models (DALL-E, gpt-image)
  /// - 'video': Video generation models (Sora)
  /// - 'moderation': Content moderation models
  /// - 'completion': Legacy text completion models (instruct, davinci, babbage)
  /// - 'code': Code generation models (codex)
  /// - 'search': Search-specific models (search, deep-research)
  /// - 'research': Research-specific models (research, deep-research)
  /// - 'unknown': Unknown or unrecognized model type
  String getModelType(String modelId) {
    final id = modelId.toLowerCase();

    // Video generation models
    if (id.contains('sora')) {
      return 'video';
    }

    // Image generation models
    if (id.contains('dall-e') || id.contains('image')) {
      return 'image';
    }

    // Embedding models
    if (id.contains('embedding')) {
      return 'embedding';
    }

    // Moderation models
    if (id.contains('moderation')) {
      return 'moderation';
    }

    // Code generation models
    if (id.contains('codex')) {
      return 'code';
    }

    // Audio models (TTS, transcription, realtime, speech-to-text)
    if (id.contains('tts') ||
        id.contains('audio') ||
        id.contains('realtime') ||
        id.contains('transcribe') ||
        id.contains('whisper')) {
      return 'audio';
    }

    // Legacy completion models (not chat)
    if (id.contains('instruct') ||
        id.contains('davinci') ||
        id.contains('babbage')) {
      return 'completion';
    }

    // Research-specific models
    if (id.contains('research')) {
      return 'research';
    }

    // Search-specific models
    if (id.contains('search')) {
      return 'search';
    }

    // GPT-N pattern: matches gpt-3, gpt-4, gpt-5, gpt-6, etc.
    // Also matches variants like gpt-4o, gpt-4-turbo, gpt-3.5-turbo
    final gptPattern = RegExp(r'^gpt-\d+(\.\d+)?(o)?(-|$)');
    if (gptPattern.hasMatch(id)) {
      return 'chat';
    }

    // O-series reasoning models: o1, o2, o3, o4, o5, etc.
    // Matches: o1, o1-preview, o3-mini, o4-mini-2025-01-01, etc.
    final oSeriesPattern = RegExp(r'^o\d+(-|$)');
    if (oSeriesPattern.hasMatch(id)) {
      return 'chat';
    }

    // ChatGPT-branded models
    // Matches: chatgpt-4o-latest, chatgpt-5-latest, chatgpt-image-latest, etc.
    if (id.startsWith('chatgpt-')) {
      // Special handling for non-chat ChatGPT variants
      if (id.contains('image')) {
        return 'image';
      }
      return 'chat';
    }

    // Unknown model type
    return 'unknown';
  }

  /// Fetch available model IDs from OpenAI API
  Future<List<String>> _fetchAvailableModels() async {
    if (apiKey == null) {
      throw GenkitException('API key is required to fetch models from OpenAI.');
    }

    final client = OpenAIClient(
      apiKey: apiKey!,
      baseUrl: baseUrl,
      headers: headers,
    );

    try {
      final response = await client.listModels();
      final modelIds = <String>[];

      // Collect all model IDs
      for (final model in response.data) {
        modelIds.add(model.id);
      }

      return modelIds;
    } finally {
      client.endSession();
    }
  }

  /// Get appropriate ModelInfo for a given model ID
  ModelInfo _getModelInfo(String modelId) {
    final id = modelId.toLowerCase();

    // O-series reasoning models (o1, o2, o3, o4, etc.) have different capabilities
    // Matches: o1, o1-preview, o2, o3-mini, o4-mini-2025-01-01, etc.
    final oSeriesPattern = RegExp(r'^o\d+(-|$)');
    if (oSeriesPattern.hasMatch(id)) {
      return oSeriesModelInfo(modelId);
    }

    return defaultModelInfo(modelId);
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    try {
      final modelIds = await _fetchAvailableModels();

      // Filter to only chat models and generate their metadata
      final modelMetadataList = modelIds
          .where(
            (modelId) =>
                getModelType(modelId) == 'chat' ||
                getModelType(modelId) == 'unknown',
          )
          .map((modelId) {
            final modelInfo = _getModelInfo(modelId);

            return modelMetadata(
              'openai/$modelId',
              modelInfo: modelInfo,
              customOptions: OpenAIOptionsSchema.$schema,
            );
          })
          .toList();

      return modelMetadataList;
    } catch (e, stackTrace) {
      throw GenkitException(
        'Error listing models from OpenAI: $e',
        underlyingException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model') {
      return _createModel(name, null);
    }
    return null;
  }

  Model _createModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? _getModelInfo(modelName);

    return Model(
      name: 'openai/$modelName',
      customOptions: OpenAIOptionsSchema.$schema,
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final options = req!.config != null
            ? OpenAIOptionsSchema.$schema.parse(req.config!)
            : OpenAIOptionsSchema();

        if (apiKey == null) {
          throw GenkitException(
            'API key is required. Provide it via the plugin constructor.',
          );
        }

        final client = OpenAIClient(
          apiKey: apiKey!,
          baseUrl: baseUrl,
          headers: headers,
        );

        try {
          final supports = modelInfo.supports;
          final supportsTools = supports?['tools'] == true;
          final request = CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(options.version ?? modelName),
            messages: GenkitConverter.toOpenAIMessages(
              req.messages,
              options.visualDetailLevel,
            ),
            tools: supportsTools
                ? req.tools?.map(GenkitConverter.toOpenAITool).toList()
                : null,
            temperature: options.temperature,
            topP: options.topP,
            maxTokens: options.maxTokens,
            stop: options.stop != null
                ? ChatCompletionStop.listString(options.stop!)
                : null,
            presencePenalty: options.presencePenalty,
            frequencyPenalty: options.frequencyPenalty,
            seed: options.seed,
            user: options.user,
            responseFormat: options.jsonMode == true
                ? const ResponseFormat.jsonObject()
                : null,
          );

          if (ctx.streamingRequested) {
            return await _handleStreaming(client, request, ctx);
          } else {
            return await _handleNonStreaming(client, request);
          }
        } catch (e, stackTrace) {
          if (e is GenkitException) {
            rethrow;
          }

          StatusCodes? status;
          String? details;

          if (e is OpenAIClientException) {
            status = e.code != null
                ? StatusCodes.fromHttpStatus(e.code!)
                : null;
            details = e.body?.toString();
          }

          throw GenkitException(
            'OpenAI API error: $e',
            status: status,
            details: details ?? e.toString(),
            underlyingException: e,
            stackTrace: stackTrace,
          );
        } finally {
          client.endSession();
        }
      },
    );
  }

  /// Handle streaming response
  Future<ModelResponse> _handleStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
    ({
      bool streamingRequested,
      void Function(ModelResponseChunk) sendChunk,
      Map<String, dynamic>? context,
      Stream<ModelRequest>? inputStream,
      void init,
    })
    ctx,
  ) async {
    final stream = client.createChatCompletionStream(request: request);

    final contentBuffer = StringBuffer();
    final toolCalls = <String, _ToolCallAccumulator>{};
    String? finishReason;

    try {
      await for (final chunk in stream) {
        final choice = (chunk.choices != null && chunk.choices!.isNotEmpty)
            ? chunk.choices!.first
            : null;
        final delta = choice?.delta;
        if (delta == null) continue;

        final parts = <Part>[];

        // Handle text content
        if (delta.content != null) {
          contentBuffer.write(delta.content);
          parts.add(TextPart(text: delta.content!));
        }

        // Handle tool calls (accumulated across chunks)
        if (delta.toolCalls != null) {
          for (final tc in delta.toolCalls!) {
            final index = tc.index.toString();
            final acc = toolCalls.putIfAbsent(
              index,
              () => _ToolCallAccumulator(tc.id ?? '', tc.function?.name ?? ''),
            );
            // Update ID and name if new values arrive
            acc.updateId(tc.id);
            acc.updateName(tc.function?.name);
            if (tc.function?.arguments != null) {
              acc.arguments.write(tc.function!.arguments);
            }
          }
        }

        if (parts.isNotEmpty) {
          ctx.sendChunk(ModelResponseChunk(index: 0, content: parts));
        }

        // Only update finishReason when a non-null/non-empty value appears
        final newFinishReason =
            chunk.choices != null && chunk.choices!.isNotEmpty
            ? chunk.choices!.first.finishReason?.name
            : null;
        if (newFinishReason != null && newFinishReason.isNotEmpty) {
          finishReason = newFinishReason;
        }
      }
    } catch (e) {
      if (e is GenkitException) rethrow;
      throw GenkitException('Error in streaming: $e', underlyingException: e);
    }

    // Build final message
    final finalParts = <Part>[];
    if (contentBuffer.isNotEmpty) {
      finalParts.add(TextPart(text: contentBuffer.toString()));
    }
    for (final tc in toolCalls.values) {
      // Validate that tool call has valid ID and name before emitting
      if (!tc.isValid()) {
        throw GenkitException(
          'Streaming tool call must have non-empty ID and name. Got: id="${tc.id}", name="${tc.name}"',
        );
      }
      final argumentsJson = tc.arguments.toString();
      final input = argumentsJson.isNotEmpty
          ? jsonDecode(argumentsJson) as Map<String, dynamic>?
          : null;
      finalParts.add(
        ToolRequestPart(
          toolRequest: ToolRequest(ref: tc.id, name: tc.name, input: input),
        ),
      );
    }

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(finishReason),
      message: Message(role: Role.model, content: finalParts),
    );
  }

  /// Handle non-streaming response
  Future<ModelResponse> _handleNonStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
  ) async {
    final response = await client.createChatCompletion(request: request);

    if (response.choices.isEmpty) {
      throw GenkitException('Model returned no choices.');
    }

    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(choice.message);

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(choice.finishReason?.name),
      message: message,
      raw: response.toJson(),
    );
  }
}
