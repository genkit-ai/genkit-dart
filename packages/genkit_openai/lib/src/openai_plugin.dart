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
import 'dart:typed_data';

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart' as sdk;

import '../genkit_openai.dart';
import 'chat.dart' as chat;
import 'speech.dart' as speech;
import 'transcription.dart' as transcription;

/// Core Genkit plugin implementation for OpenAI-compatible APIs.
///
/// Automatically discovers models from the OpenAI API (when no custom
/// [baseUrl] is set) and registers them in the Genkit action registry.
/// Additional models can be provided via [customModels].
class OpenAIPlugin extends GenkitPlugin {
  /// Base URL used when the plugin was not given one.
  static const String _defaultBaseUrl = 'https://api.openai.com/v1';

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

  @override
  Future<List<Action>> init() async {
    final actions = <Action>[];

    // Fetch and register models from OpenAI API only for default OpenAI host.
    if (baseUrl == null) {
      try {
        final availableModelIds = await _fetchAvailableModels();

        final registered = <String>{};

        for (final modelId in availableModelIds) {
          if (speech.isSpeechModel(modelId)) {
            registered.add(modelId);
            actions.add(
              _createSpeechModel(modelId, speech.speechModelInfo(modelId)),
            );
            continue;
          }

          if (transcription.isTranscriptionModel(modelId)) {
            registered.add(modelId);
            actions.add(
              _createTranscriptionModel(
                modelId,
                transcription.transcriptionModelInfo(modelId),
              ),
            );
            continue;
          }

          final modelType = getModelType(modelId);

          if (modelType != 'chat' && modelType != 'unknown') {
            continue;
          }

          final info = modelInfoFor(modelId);
          actions.add(_createModel(modelId, info));
        }

        // Speech models are not always advertised by GET /models, so register
        // the known ones regardless.
        for (final modelId in speech.knownSpeechModels) {
          if (registered.add(modelId)) {
            actions.add(
              _createSpeechModel(modelId, speech.speechModelInfo(modelId)),
            );
          }
        }

        for (final modelId in transcription.knownTranscriptionModels) {
          if (registered.add(modelId)) {
            actions.add(
              _createTranscriptionModel(
                modelId,
                transcription.transcriptionModelInfo(modelId),
              ),
            );
          }
        }
      } catch (e) {
        throw GenkitException(
          'Error fetching available models from $_pluginName: $e',
          underlyingException: e,
        );
      }
    }

    // Register custom models
    for (final model in customModels) {
      if (speech.isSpeechModel(model.name) ||
          speech.declaresMediaOutput(model.info)) {
        actions.add(_createSpeechModel(model.name, model.info));
      } else if (transcription.isTranscriptionModel(model.name) ||
          transcription.declaresMediaInput(model.info)) {
        actions.add(_createTranscriptionModel(model.name, model.info));
      } else {
        actions.add(_createModel(model.name, model.info));
      }
    }

    return actions;
  }

  /// Fetch available model IDs from OpenAI API
  Future<List<String>> _fetchAvailableModels() async {
    final resolvedConfig = await _resolveClientConfig();

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
    final configuredApiKey = await _resolveApiKey();
    if (configuredApiKey == null || configuredApiKey.trim().isEmpty) {
      throw GenkitException(
        '[$_pluginName] API key is required. Provide it via apiKey or apiKeyProvider in the plugin constructor.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    return _ResolvedClientConfig(
      apiKey: configuredApiKey.trim(),
      baseUrl: baseUrl,
      headers: headers,
    );
  }

  Future<String?> _resolveApiKey() async {
    final configuredApiKeyProvider = apiKeyProvider;
    if (configuredApiKeyProvider != null) {
      return await configuredApiKeyProvider();
    }
    return apiKey;
  }

  @override
  Future<List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>>
  list() async {
    try {
      final modelIds = await _fetchAvailableModels();
      final modelMetadataList =
          <ActionMetadata<dynamic, dynamic, dynamic, dynamic>>[];

      final listed = <String>{};

      for (final modelId in modelIds) {
        if (speech.isSpeechModel(modelId)) {
          listed.add(modelId);
          modelMetadataList.add(_speechModelMetadata(modelId));
          continue;
        }

        if (transcription.isTranscriptionModel(modelId)) {
          listed.add(modelId);
          modelMetadataList.add(_transcriptionModelMetadata(modelId));
          continue;
        }

        final modelType = getModelType(modelId);
        if (modelType != 'chat' && modelType != 'unknown') {
          continue;
        }

        modelMetadataList.add(
          modelMetadata(
            '$_pluginName/$modelId',
            modelInfo: modelInfoFor(modelId),
            customOptions: chat.chatModelOptionsSchema(),
          ),
        );
      }

      for (final modelId in speech.knownSpeechModels) {
        if (listed.add(modelId)) {
          modelMetadataList.add(_speechModelMetadata(modelId));
        }
      }

      for (final modelId in transcription.knownTranscriptionModels) {
        if (listed.add(modelId)) {
          modelMetadataList.add(_transcriptionModelMetadata(modelId));
        }
      }

      return modelMetadataList;
    } catch (e, stackTrace) {
      throw GenkitException(
        'Error listing models from $_pluginName: $e',
        underlyingException: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType == .model) {
      final info = _customModelInfo(name);
      if (speech.isSpeechModel(name) || speech.declaresMediaOutput(info)) {
        return _createSpeechModel(name, info);
      }
      if (transcription.isTranscriptionModel(name) ||
          transcription.declaresMediaInput(info)) {
        return _createTranscriptionModel(name, info);
      }
      return _createModel(name, info);
    }
    return null;
  }

  /// Metadata for [modelName] if the caller registered it as a custom model.
  ModelInfo? _customModelInfo(String modelName) {
    for (final model in customModels) {
      if (model.name == modelName) {
        return model.info;
      }
    }
    return null;
  }

  ActionMetadata<dynamic, dynamic, dynamic, dynamic> _speechModelMetadata(
    String modelId,
  ) {
    return modelMetadata(
      '$_pluginName/$modelId',
      modelInfo: speech.speechModelInfo(modelId),
      customOptions: speech.speechModelOptionsSchema(),
    );
  }

  ActionMetadata<dynamic, dynamic, dynamic, dynamic>
  _transcriptionModelMetadata(String modelId) {
    return modelMetadata(
      '$_pluginName/$modelId',
      modelInfo: transcription.transcriptionModelInfo(modelId),
      customOptions: transcription.transcriptionModelOptionsSchema(),
    );
  }

  Model _createModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? modelInfoFor(modelName);

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
          if (e is GenkitException) {
            rethrow;
          }

          StatusCodes? status;
          String? details;

          if (e is sdk.ApiException) {
            status = StatusCodes.fromHttpStatus(e.statusCode);
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
          if (httpClient == null) {
            client.close();
          }
        }
      },
    );
  }

  /// Handle streaming response
  Future<ModelResponse> _handleStreaming(
    sdk.OpenAIClient client,
    sdk.ChatCompletionCreateRequest request,
    ({
      bool streamingRequested,
      void Function(ModelResponseChunk) sendChunk,
      Map<String, dynamic>? context,
      Stream<ModelRequest>? inputStream,
      void init,
    })
    ctx,
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

  /// Builds a text-to-speech model action.
  ///
  /// Speech models take the prompt text and return a single audio
  /// [MediaPart] holding a base64 data URL. Streaming is not supported by the
  /// `/audio/speech` endpoint, so streaming requests are ignored.
  Model _createSpeechModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? speech.speechModelInfo(modelName);

    return Model(
      name: '$_pluginName/$modelName',
      customOptions: speech.speechModelOptionsSchema(),
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = speech.parseSpeechModelOptions(modelRequest.config);
        final input = _speechInputText(modelRequest);

        final resolvedConfig = await _resolveClientConfig();
        final client = sdk.OpenAIClient.withApiKey(
          resolvedConfig.apiKey,
          baseUrl: resolvedConfig.baseUrl,
          defaultHeaders: resolvedConfig.headers,
          httpClient: httpClient,
        );

        try {
          final format =
              options.responseFormat ?? speech.defaultSpeechResponseFormat;
          final resolvedModel = options.version ?? modelName;

          final body = _SpeechRequestBody(
            model: resolvedModel,
            input: input,
            voiceName: options.voice ?? speech.defaultSpeechVoice,
            instructions: options.instructions,
            responseFormat: options.responseFormat == null
                ? null
                : sdk.SpeechResponseFormat.fromJson(format),
            // gpt-4o-mini-tts rejects `speed` outright.
            speed: speech.speechModelRejectsSpeed(resolvedModel)
                ? null
                : options.speed,
          );

          final bytes = await client.audio.speech.create(body);
          final contentType =
              speech.speechResponseFormatMediaTypes[format] ?? 'audio/mpeg';

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                MediaPart(
                  media: Media(
                    contentType: contentType,
                    url: 'data:$contentType;base64,${base64Encode(bytes)}',
                  ),
                ),
              ],
            ),
          );
        } catch (e, stackTrace) {
          if (e is GenkitException) {
            rethrow;
          }

          StatusCodes? status;
          String? details;

          if (e is sdk.ApiException) {
            status = StatusCodes.fromHttpStatus(e.statusCode);
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
          if (httpClient == null) {
            client.close();
          }
        }
      },
    );
  }

  /// Extracts the text to synthesize: the first message only, matching the
  /// JS plugin's `toTTSRequest`.
  String _speechInputText(ModelRequest request) {
    if (request.messages.isEmpty) {
      throw GenkitException(
        'Speech models require a prompt, but no messages were provided.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final text = request.messages.first.text;
    if (text.trim().isEmpty) {
      throw GenkitException(
        'Speech models require non-empty prompt text.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    return text;
  }

  /// Builds a speech-to-text model action.
  ///
  /// Transcription models read an audio [MediaPart] out of the request and
  /// return the transcript as a single text part. The request is a
  /// hand-built multipart upload rather than an SDK call: the SDK's
  /// `TranscriptionRequest` cannot express `chunking_strategy` or `include`,
  /// and its `create()` always JSON-decodes the response, which breaks the
  /// `text`, `srt` and `vtt` formats.
  Model _createTranscriptionModel(String modelName, ModelInfo? info) {
    final modelInfo = info ?? transcription.transcriptionModelInfo(modelName);

    return Model(
      name: '$_pluginName/$modelName',
      customOptions: transcription.transcriptionModelOptionsSchema(),
      metadata: {'model': modelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = transcription.parseTranscriptionModelOptions(
          modelRequest.config,
        );

        if (modelRequest.output?.format == 'media') {
          throw GenkitException(
            'Transcription models return text; output format '
            "'media' is not supported.",
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }

        final audio = _transcriptionAudio(modelRequest);
        final resolvedModel = options.version ?? modelName;
        final format = _transcriptionResponseFormat(modelRequest, options);
        final translate =
            options.translate == true &&
            transcription.supportsTranslation(resolvedModel);

        final resolvedConfig = await _resolveClientConfig();
        final client = httpClient ?? http.Client();

        try {
          final endpoint = translate
              ? '/audio/translations'
              : '/audio/transcriptions';
          final url = Uri.parse(
            '${resolvedConfig.baseUrl ?? _defaultBaseUrl}$endpoint',
          );

          final request = http.MultipartRequest('POST', url)
            ..headers['Authorization'] = 'Bearer ${resolvedConfig.apiKey}';
          resolvedConfig.headers?.forEach((key, value) {
            request.headers[key] = value;
          });

          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              audio.bytes,
              filename: transcription.audioFilenameFor(audio.mimeType),
            ),
          );
          request.fields['model'] = resolvedModel;
          request.fields['response_format'] = format;

          final prompt = options.prompt ?? modelRequest.messages.first.text;
          if (prompt.trim().isNotEmpty) {
            request.fields['prompt'] = prompt;
          }
          if (options.temperature != null) {
            request.fields['temperature'] = '${options.temperature}';
          }

          // The translations endpoint only accepts file, model, prompt,
          // response_format and temperature.
          if (!translate) {
            if (options.language != null) {
              request.fields['language'] = options.language!;
            }
            final chunking = options.chunkingStrategy;
            if (chunking != null) {
              request.fields['chunking_strategy'] = chunking is String
                  ? chunking
                  : jsonEncode(chunking);
            }
            for (final value in options.include ?? const <String>[]) {
              _addRepeatedField(request, 'include[]', value);
            }
            for (final value
                in options.timestampGranularities ?? const <String>[]) {
              _addRepeatedField(request, 'timestamp_granularities[]', value);
            }
          }

          final response = await http.Response.fromStream(
            await client.send(request),
          );

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw GenkitException(
              'OpenAI API error: HTTP ${response.statusCode}',
              status: StatusCodes.fromHttpStatus(response.statusCode),
              details: response.body,
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: _transcriptText(response.body, format))],
            ),
          );
        } catch (e, stackTrace) {
          if (e is GenkitException) {
            rethrow;
          }

          throw GenkitException(
            'OpenAI API error: $e',
            details: e.toString(),
            underlyingException: e,
            stackTrace: stackTrace,
          );
        } finally {
          if (httpClient == null) {
            client.close();
          }
        }
      },
    );
  }

  /// Adds a repeated multipart field.
  ///
  /// `MultipartRequest.fields` is a plain map and cannot hold duplicate keys,
  /// but OpenAI expects array parameters as repeated fields.
  void _addRepeatedField(
    http.MultipartRequest request,
    String name,
    String value,
  ) {
    request.files.add(http.MultipartFile.fromString(name, value));
  }

  /// Extracts the audio to transcribe from the first message.
  ({Uint8List bytes, String mimeType}) _transcriptionAudio(
    ModelRequest request,
  ) {
    final media = request.messages.isEmpty
        ? null
        : request.messages.first.media;
    if (media == null) {
      throw GenkitException(
        'Transcription models require an audio media part in the request.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final uri = Uri.tryParse(media.url);
    final data = uri?.data;
    if (data == null) {
      throw GenkitException(
        'Transcription models require audio as a base64 data URL; '
        'got ${media.url.split(':').first}.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final mimeType = (media.contentType ?? data.mimeType)
        .split(';')
        .first
        .trim();
    return (bytes: data.contentAsBytes(), mimeType: mimeType);
  }

  /// Resolves the transcript format, rejecting combinations OpenAI cannot
  /// satisfy.
  String _transcriptionResponseFormat(
    ModelRequest request,
    transcription.OpenAITranscriptionOptions options,
  ) {
    final requested = options.responseFormat;
    final wantsJson = request.output?.format == 'json';

    if (wantsJson &&
        requested != null &&
        requested != 'json' &&
        requested != 'verbose_json') {
      throw GenkitException(
        "Response format '$requested' cannot satisfy output format 'json'.",
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    if (requested != null) {
      return requested;
    }
    return wantsJson
        ? 'json'
        : transcription.defaultTranscriptionResponseFormat;
  }

  /// Pulls the transcript out of a response body.
  ///
  /// `json` and `verbose_json` wrap it in an object; `text`, `srt` and `vtt`
  /// are already the transcript.
  String _transcriptText(String body, String format) {
    if (format != 'json' && format != 'verbose_json') {
      return body;
    }
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['text'] is String) {
      return decoded['text'] as String;
    }
    return body;
  }
}

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

/// Request body for `/audio/speech`.
///
/// The SDK's [sdk.SpeechRequest] caps `voice` at six legacy values and has no
/// `instructions` field, which is the whole point of `gpt-4o-mini-tts`.
/// The SDK's speech resource only ever calls `toJson()` on the request, so
/// overriding it here buys full API fidelity while keeping every call on the
/// SDK's transport (auth, retries, error mapping).
final class _SpeechRequestBody extends sdk.SpeechRequest {
  _SpeechRequestBody({
    required super.model,
    required super.input,
    required this.voiceName,
    this.instructions,
    super.responseFormat,
    super.speed,
  }) : super(voice: sdk.SpeechVoice.alloy); // Placeholder; replaced in toJson.

  /// Free-form voice name, unconstrained by [sdk.SpeechVoice].
  final String voiceName;

  /// Tone and delivery guidance for `gpt-4o-mini-tts`.
  final String? instructions;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'voice': voiceName,
    if (instructions != null) 'instructions': instructions,
  };
}
