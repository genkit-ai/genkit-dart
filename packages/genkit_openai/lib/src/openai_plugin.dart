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
import 'dart:io';

import 'package:genkit/plugin.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;
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
  final flattened = schema.flatten();
  return ResponseFormat.jsonSchema(
    jsonSchema: JsonSchemaObject(
      name: 'output',
      schema: {...flattened, 'additionalProperties': false},
      strict: true,
    ),
  );
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

<<<<<<< openai-add-whisper
          if (modelType != 'chat' &&
              modelType != 'unknown' &&
              !isTranscriptionModel(modelId)) {
=======
          if (modelType != 'chat' && modelType != 'unknown') {
>>>>>>> main
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

    // Whisper/GPT transcription models accept audio input and return text.
    if (isTranscriptionModel(id)) {
      return transcriptionModelInfo(modelId);
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

      // Filter to chat/unknown models plus transcription models.
      final modelMetadataList = modelIds
          .where(
            (modelId) =>
                getModelType(modelId) == 'chat' ||
                getModelType(modelId) == 'unknown' ||
                isTranscriptionModel(modelId),
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
        final request = req!;
        final options = request.config != null
            ? OpenAIOptions.$schema.parse(request.config!)
            : OpenAIOptions();

        if (apiKey == null) {
          throw GenkitException(
            'API key is required. Provide it via the plugin constructor.',
          );
        }

        final resolvedModel = options.version ?? modelName;
        if (isTranscriptionModel(resolvedModel)) {
          return _handleTranscription(request, resolvedModel, ctx);
        }

        final client = OpenAIClient(
          apiKey: apiKey!,
          baseUrl: baseUrl,
          headers: headers,
        );

        try {
          final supports = modelInfo.supports;
          final supportsTools = supports?['tools'] == true;

          final isJsonMode = isJsonStructuredOutput(
            request.output?.format,
            request.output?.contentType,
          );
<<<<<<< openai-add-whisper
          final responseFormat = buildOpenAIResponseFormat(request.output?.schema);
          final chatRequest = CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(resolvedModel),
=======
          final responseFormat = buildOpenAIResponseFormat(req.output?.schema);
          final request = CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(options.version ?? modelName),
>>>>>>> main
            messages: GenkitConverter.toOpenAIMessages(
              request.messages,
              options.visualDetailLevel,
            ),
            tools: supportsTools
                ? request.tools?.map(GenkitConverter.toOpenAITool).toList()
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
            responseFormat: isJsonMode ? responseFormat : null,
          );
          if (ctx.streamingRequested) {
            return await _handleStreaming(client, chatRequest, ctx);
          } else {
            return await _handleNonStreaming(client, chatRequest);
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

  Future<ModelResponse> _handleTranscription(
    ModelRequest req,
    String modelName,
    ({
      bool streamingRequested,
      void Function(ModelResponseChunk) sendChunk,
      Map<String, dynamic>? context,
      Stream<ModelRequest>? inputStream,
      void init,
    })
    ctx,
  ) async {
    if (ctx.streamingRequested) {
      throw GenkitException(
        'Streaming is not currently supported for transcription models.',
      );
    }

    final media = _extractAudioMedia(req.messages);
    if (media == null) {
      throw GenkitException(
        'Transcription requires at least one audio MediaPart in request messages.',
      );
    }

    final audioPayload = _decodeAudioDataUrl(media);
    final transcriptionUri = _buildOpenAIUri('/audio/transcriptions');
    final httpClient = HttpClient();

    try {
      final request = await httpClient.postUrl(transcriptionUri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${apiKey!}');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        for (final header in headers!.entries) {
          request.headers.set(header.key, header.value);
        }
      }

      final boundary = 'genkit-${DateTime.now().microsecondsSinceEpoch}';
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      final bodyBuilder = BytesBuilder();
      _appendMultipartField(bodyBuilder, boundary, 'model', modelName);

      final prompt = _extractTranscriptionPrompt(req.messages);
      if (prompt != null && prompt.isNotEmpty) {
        _appendMultipartField(bodyBuilder, boundary, 'prompt', prompt);
      }

      _appendMultipartFile(
        bodyBuilder,
        boundary,
        fieldName: 'file',
        filename: audioPayload.filename,
        contentType: audioPayload.contentType,
        bytes: audioPayload.bytes,
      );

      bodyBuilder.add(utf8.encode('--$boundary--\r\n'));
      request.add(bodyBuilder.takeBytes());

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GenkitException(
          'OpenAI API error: transcription request failed with status ${response.statusCode}.',
          status: StatusCodes.fromHttpStatus(response.statusCode),
          details: responseBody,
        );
      }

      final parsedBody = jsonDecode(responseBody);
      final raw = parsedBody is Map<String, dynamic>
          ? parsedBody
          : <String, dynamic>{'response': parsedBody};
      final transcript = _extractTranscriptionText(raw);

      if (transcript == null || transcript.trim().isEmpty) {
        throw GenkitException(
          'Transcription response did not contain text.',
          details: responseBody,
        );
      }

      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: transcript.trim())],
        ),
        raw: raw,
      );
    } on GenkitException {
      rethrow;
    } on FormatException catch (e, stackTrace) {
      throw GenkitException(
        'Invalid transcription response format: $e',
        underlyingException: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      throw GenkitException(
        'OpenAI transcription error: $e',
        details: e.toString(),
        underlyingException: e,
        stackTrace: stackTrace,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Uri _buildOpenAIUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    if (baseUrl == null || baseUrl!.isEmpty) {
      return Uri.parse('https://api.openai.com/v1$normalizedPath');
    }

    final parsedBaseUri = Uri.parse(baseUrl!);
    final trimmedBasePath = parsedBaseUri.path.endsWith('/')
        ? parsedBaseUri.path.substring(0, parsedBaseUri.path.length - 1)
        : parsedBaseUri.path;

    return parsedBaseUri.replace(path: '$trimmedBasePath$normalizedPath');
  }

  Media? _extractAudioMedia(List<Message> messages) {
    for (final message in messages.reversed) {
      for (final part in message.content.reversed) {
        final media = part.media;
        if (media == null) continue;

        final contentType = media.contentType?.toLowerCase();
        final isAudioDataUrl = media.url.toLowerCase().startsWith('data:audio/');
        if (isAudioDataUrl ||
            (contentType != null && contentType.startsWith('audio/'))) {
          return media;
        }
      }
    }
    return null;
  }

  ({
    List<int> bytes,
    String contentType,
    String filename,
  })
  _decodeAudioDataUrl(Media media) {
    final url = media.url.trim();
    final match = RegExp(
      r'^data:(audio\/[^;]+);base64,',
      caseSensitive: false,
    ).firstMatch(url);

    if (match == null) {
      throw GenkitException(
        'Audio media must be provided as a base64 data URL for transcription models.',
      );
    }

    final contentType = match.group(1)!.toLowerCase();
    final encodedAudio = url.substring(match.end);
    final bytes = base64Decode(encodedAudio);
    final filename = switch (contentType) {
      'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'audio.wav',
      'audio/mp3' || 'audio/mpeg' || 'audio/x-mp3' => 'audio.mp3',
      _ => 'audio.bin',
    };

    return (bytes: bytes, contentType: contentType, filename: filename);
  }

  String? _extractTranscriptionPrompt(List<Message> messages) {
    for (final message in messages.reversed) {
      if (message.role != Role.user) continue;

      final prompt = message.text.trim();
      if (prompt.isNotEmpty) return prompt;
    }
    return null;
  }

  String? _extractTranscriptionText(Map<String, dynamic> responseBody) {
    final text = responseBody['text'];
    if (text is String && text.trim().isNotEmpty) {
      return text;
    }

    final transcript = responseBody['transcript'];
    if (transcript is String && transcript.trim().isNotEmpty) {
      return transcript;
    }

    return null;
  }

  void _appendMultipartField(
    BytesBuilder builder,
    String boundary,
    String name,
    String value,
  ) {
    builder.add(utf8.encode('--$boundary\r\n'));
    builder.add(
      utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'),
    );
    builder.add(utf8.encode(value));
    builder.add(utf8.encode('\r\n'));
  }

  void _appendMultipartFile(
    BytesBuilder builder,
    String boundary, {
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
  }) {
    builder.add(utf8.encode('--$boundary\r\n'));
    builder.add(
      utf8.encode(
        'Content-Disposition: form-data; name="$fieldName"; filename="$filename"\r\n',
      ),
    );
    builder.add(utf8.encode('Content-Type: $contentType\r\n\r\n'));
    builder.add(bytes);
    builder.add(utf8.encode('\r\n'));
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
      }
    } catch (e) {
      if (e is GenkitException) rethrow;
      throw GenkitException('Error in streaming: $e', underlyingException: e);
    }

    final response = aggregateStreamResponses(chunks);
    final choice = response.choices.first;
    final message = GenkitConverter.fromOpenAIAssistantMessage(choice.message);

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
