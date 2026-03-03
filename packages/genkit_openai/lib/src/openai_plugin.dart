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

import 'package:genkit/plugin.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;
// ignore: implementation_imports
import 'package:openai_dart/src/generated/client.dart' as openai_generated;
import 'package:schemantic/schemantic.dart';

import '../genkit_openai.dart';
import 'aggregation.dart';

/// Returns true when the output config indicates JSON-structured output
/// (format is 'json' or contentType is 'application/json').
bool isJsonStructuredOutput(String? format, String? contentType) {
  return format == 'json' || contentType == 'application/json';
}

/// Builds an OpenAI [ResponseFormat] from a Genkit output schema.
/// Flattens `$ref`/`$defs` since OpenAI requires `type` at the top level.
/// Returns null if [schema] is null.
ResponseFormat? buildOpenAIResponseFormat(Map<String, dynamic>? schema) {
  if (schema == null) return null;
  final flattened = Schema.fromMap(schema).flatten().value;
  return ResponseFormat.jsonSchema(
    jsonSchema: JsonSchemaObject(
      name: 'output',
      schema: {...flattened, 'additionalProperties': false},
      strict: true,
    ),
  );
}

/// Resolves and normalizes OpenAI chat completion modalities.
///
/// OpenAI currently accepts only:
/// - `['text']`
/// - `['text', 'audio']`
///
/// If audio is requested, this function always includes `text`.
List<ChatCompletionModality>? resolveOpenAIModalities({
  required String modelType,
  required List<String>? configured,
}) {
  final requested = configured ?? (modelType == 'audio' ? ['audio'] : null);
  if (requested == null || requested.isEmpty) {
    return null;
  }

  final parsed = <ChatCompletionModality>{};
  for (final modality in requested) {
    parsed.add(_parseOpenAIModality(modality));
  }

  if (parsed.contains(ChatCompletionModality.audio)) {
    return [ChatCompletionModality.text, ChatCompletionModality.audio];
  }

  return [ChatCompletionModality.text];
}

/// Returns true if [modelId] refers to a dedicated speech synthesis model.
bool isSpeechSynthesisModel(String modelId) {
  final id = modelId.toLowerCase();
  return id.contains('tts') &&
      !id.contains('audio') &&
      !id.contains('realtime');
}

ChatCompletionModality _parseOpenAIModality(String modality) {
  return switch (modality.toLowerCase()) {
    'text' => ChatCompletionModality.text,
    'audio' => ChatCompletionModality.audio,
    _ => throw GenkitException(
      'Unsupported response modality "$modality". OpenAI chat completions support only "text" and "audio".',
      status: StatusCodes.INVALID_ARGUMENT,
    ),
  };
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

          if (modelType != 'chat' &&
              modelType != 'audio' &&
              modelType != 'tts' &&
              modelType != "unknown") {
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
  /// - 'tts': Text-to-speech models (TTS)
  /// - 'stt': Speech-to-text models (STT)
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
    if (id.contains('audio') || id.contains('realtime')) {
      return 'audio';
    }

    if (id.contains('tts')) {
      return 'tts';
    }

    if (id.contains('transcribe') || id.contains('whisper')) {
      return 'stt';
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
    final modelType = getModelType(modelId);

    if (modelType == 'audio') {
      return audioModelInfo(modelId);
    }

    if (modelType == 'tts') {
      return ttsModelInfo(modelId);
    }
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
                getModelType(modelId) == 'audio' ||
                getModelType(modelId) == 'tts' ||
                getModelType(modelId) == 'unknown',
          )
          .map((modelId) {
            final modelInfo = _getModelInfo(modelId);

            return modelMetadata(
              'openai/$modelId',
              modelInfo: modelInfo,
              customOptions: OpenAIOptions.$schema,
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
      customOptions: OpenAIOptions.$schema,
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final requestInput = req!;
        final options = requestInput.config != null
            ? OpenAIOptions.$schema.parse(requestInput.config!)
            : OpenAIOptions();

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
          final resolvedModelId = options.version ?? modelName;
          if (getModelType(resolvedModelId) == 'tts') {
            return await _handleSpeechSynthesis(
              client,
              requestInput,
              modelId: resolvedModelId,
              options: options,
            );
          }

          final modelType = getModelType(resolvedModelId);
          final modalities = resolveOpenAIModalities(
            modelType: modelType,
            configured: options.responseModalities,
          );

          final audioOptions =
              modalities != null &&
                  modalities.contains(ChatCompletionModality.audio)
              ? ChatCompletionAudioOptions(
                  voice: ChatCompletionAudioVoice.values.byName(
                    options.audioVoice ?? 'alloy',
                  ),
                  format: ChatCompletionAudioFormat.values.byName(
                    options.audioFormat ?? 'mp3',
                  ),
                )
              : null;

          final isJsonMode = isJsonStructuredOutput(
            requestInput.output?.format,
            requestInput.output?.contentType,
          );
          final responseFormat = buildOpenAIResponseFormat(
            requestInput.output?.schema,
          );
          final request = CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(resolvedModelId),
            messages: GenkitConverter.toOpenAIMessages(
              requestInput.messages,
              options.visualDetailLevel,
            ),
            tools: supportsTools
                ? requestInput.tools?.map(GenkitConverter.toOpenAITool).toList()
                : null,
            modalities: modalities,
            audio: audioOptions,
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
            responseFormat: isJsonMode ? responseFormat : null,
          );
          if (ctx.streamingRequested) {
            return await _handleStreaming(
              client,
              request,
              request.audio?.format,
              ctx,
            );
          } else {
            return await _handleNonStreaming(
              client,
              request,
              request.audio?.format,
            );
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

  Future<ModelResponse> _handleSpeechSynthesis(
    OpenAIClient client,
    ModelRequest requestInput, {
    required String modelId,
    required OpenAIOptions options,
  }) async {
    final textInput = _extractSpeechInputText(requestInput.messages);
    final voice = options.audioVoice ?? 'alloy';
    final format = (options.audioFormat ?? 'mp3').toLowerCase();
    final responseFormat = _speechFormatToApiValue(format);
    final requestedMimeType = _speechFormatToMimeType(format);
    final speechEndpoint = _resolveSpeechEndpoint();

    // ignore: invalid_use_of_protected_member
    final response = await client.makeRequest(
      baseUrl: speechEndpoint.baseUrl,
      path: speechEndpoint.path,
      method: openai_generated.HttpMethod.post,
      requestType: 'application/json',
      responseType: requestedMimeType,
      body: {
        'model': modelId,
        'input': textInput,
        'voice': voice,
        'response_format': responseFormat,
      },
    );

    final mimeType = _resolveSpeechContentType(
      response.headers['content-type'],
      fallbackFormat: format,
    );
    final audioData = base64Encode(response.bodyBytes);

    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [
          MediaPart(
            media: Media(
              url: 'data:$mimeType;base64,$audioData',
              contentType: mimeType,
            ),
            metadata: {
              'audio': {
                'model': modelId,
                'voice': voice,
                'format': responseFormat,
              },
            },
          ),
        ],
      ),
      raw: {
        'endpoint': speechEndpoint.path,
        'model': modelId,
        'contentType': mimeType,
      },
    );
  }

  /// Handle streaming response
  Future<ModelResponse> _handleStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
    ChatCompletionAudioFormat? audioFormat,
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
    final chunks = <CreateChatCompletionStreamResponse>[];

    try {
      await for (final chunk in stream) {
        chunks.add(chunk);

        final choice = (chunk.choices != null && chunk.choices!.isNotEmpty)
            ? chunk.choices!.first
            : null;
        final delta = choice?.delta;
        if (delta == null) continue;

        if (delta.content != null) {
          ctx.sendChunk(
            ModelResponseChunk(
              index: 0,
              content: [TextPart(text: delta.content!)],
            ),
          );
        }

        if (delta.audio?.transcript != null &&
            delta.audio!.transcript!.isNotEmpty) {
          ctx.sendChunk(
            ModelResponseChunk(
              index: 0,
              content: [TextPart(text: delta.audio!.transcript!)],
            ),
          );
        }
      }
    } catch (e) {
      if (e is GenkitException) rethrow;
      throw GenkitException('Error in streaming: $e', underlyingException: e);
    }

    final response = aggregateStreamResponses(chunks);
    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(
      choice.message,
      audioFormat: audioFormat,
    );

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(choice.finishReason?.name),
      message: message,
      raw: response.toJson(),
    );
  }

  /// Handle non-streaming response
  Future<ModelResponse> _handleNonStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
    ChatCompletionAudioFormat? audioFormat,
  ) async {
    final response = await client.createChatCompletion(request: request);

    if (response.choices.isEmpty) {
      throw GenkitException('Model returned no choices.');
    }

    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(
      choice.message,
      audioFormat: audioFormat,
    );

    return ModelResponse(
      finishReason: GenkitConverter.mapFinishReason(choice.finishReason?.name),
      message: message,
      raw: response.toJson(),
    );
  }

  String _extractSpeechInputText(List<Message> messages) {
    String? lastNonEmptyText;
    for (final message in messages.reversed) {
      final text = message.text.trim();
      if (text.isEmpty) continue;

      if (message.role == Role.user) {
        return text;
      }

      lastNonEmptyText ??= text;
    }

    if (lastNonEmptyText != null) {
      return lastNonEmptyText;
    }

    throw GenkitException(
      'Speech synthesis models require non-empty text input.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  ({String baseUrl, String path}) _resolveSpeechEndpoint() {
    if (baseUrl == null) {
      return (baseUrl: 'https://api.openai.com', path: '/v1/audio/speech');
    }

    final normalizedPath = Uri.parse(baseUrl!).path.toLowerCase();
    final includesVersionPrefix = RegExp(
      r'(^|/)v\d+(/|$)',
    ).hasMatch(normalizedPath);

    return (
      baseUrl: baseUrl!,
      path: includesVersionPrefix ? '/audio/speech' : '/v1/audio/speech',
    );
  }

  String _speechFormatToApiValue(String format) {
    return switch (format) {
      'wav' || 'mp3' || 'flac' || 'opus' => format,
      'pcm16' || 'pcm' => 'pcm',
      _ => throw GenkitException(
        'Unsupported audio format "$format".',
        status: StatusCodes.INVALID_ARGUMENT,
      ),
    };
  }

  String _speechFormatToMimeType(String format) {
    return switch (format) {
      'wav' => 'audio/wav',
      'mp3' || 'mpeg' => 'audio/mpeg',
      'flac' => 'audio/flac',
      'opus' => 'audio/opus',
      'pcm16' || 'pcm' => 'audio/pcm',
      _ => throw GenkitException(
        'Unsupported audio format "$format".',
        status: StatusCodes.INVALID_ARGUMENT,
      ),
    };
  }

  String _resolveSpeechContentType(
    String? headerValue, {
    required String fallbackFormat,
  }) {
    if (headerValue == null || headerValue.trim().isEmpty) {
      return _speechFormatToMimeType(fallbackFormat);
    }

    final normalized = headerValue.split(';').first.trim().toLowerCase();
    if (normalized.startsWith('audio/')) {
      return normalized;
    }
    if (normalized.contains('/')) {
      return _speechFormatToMimeType(fallbackFormat);
    }

    try {
      return _speechFormatToMimeType(normalized);
    } on GenkitException {
      return _speechFormatToMimeType(fallbackFormat);
    }
  }
}
