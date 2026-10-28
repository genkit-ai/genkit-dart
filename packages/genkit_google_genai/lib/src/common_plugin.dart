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
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'aggregation.dart';
import 'api_client.dart';
import 'generated/generativelanguage.dart' as gcl;
import 'interaction_converters.dart'
    show mergeStreamedAudio, warnDroppedConfigField;
import 'interaction_model.dart';
import 'known_models.dart';
import 'model.dart';

final logger = Logger('genkit_google_genai');

final commonModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

/// Fallback metadata for an un-curated `-tts` model name.
final commonTtsModelInfo = ModelInfo(supports: geminiTtsSupports);

/// Fallback metadata for an un-curated video model name (`gemini-omni-*`).
final commonVideoModelInfo = ModelInfo(supports: geminiVideoSupports);

abstract class CommonGoogleGenPlugin extends GenkitPlugin {
  Future<GenerativeLanguageBaseClient> getApiClient([String? requestApiKey]);

  /// The API client for a model request with [config] (the request's
  /// options). By default it only reads `apiKey`; vertexAI overrides it to
  /// apply the per-request `location` and `payGo`.
  Future<GenerativeLanguageBaseClient> getApiClientForRequest(
    Map<String, dynamic>? config,
  ) => getApiClient(
    config == null ? null : GeminiOptions.$schema.parse(config).apiKey,
  );

  /// The full Vertex AI Search data store path for `vertexRetrieval` (JS
  /// vertexai toVertexAISearchDatastore). Only called when
  /// [supportsVertexOptions] is true.
  String vertexSearchDatastore(GeminiVertexDatastore datastore) =>
      throw UnsupportedError('vertexRetrieval is not supported by $name.');

  /// Curated per-model capability metadata exposed by this plugin, keyed by
  /// bare model name.
  ///
  /// Model names not present here still resolve; they fall back to
  /// [commonModelInfo]. Override in concrete plugins to advertise accurate
  /// capabilities for known models.
  Map<String, ModelInfo> get knownModels => const {};

  /// Returns the capability metadata for [modelName].
  ///
  /// Names not in [knownModels] fall back to the profile of their
  /// [GeminiModelFamily]: [commonTtsModelInfo] for `-tts` names and
  /// [commonModelInfo] for everything else.
  ModelInfo modelInfoFor(String modelName) =>
      knownModels[modelName] ??
      switch (GeminiModelFamily.of(modelName)) {
        .tts => commonTtsModelInfo,
        .video => commonVideoModelInfo,
        .text || .image => commonModelInfo,
      };

  /// Returns action metadata for every [knownModels] entry whose bare name is
  /// not in [discoveredNames], so a curated model stays listed when model
  /// discovery omits it or fails outright.
  Iterable<ActionMetadata<dynamic, dynamic, dynamic, dynamic>>
  curatedModelMetadata({Set<String> discoveredNames = const {}}) {
    return knownModels.entries
        .where((entry) => !discoveredNames.contains(entry.key))
        .map(
          (entry) => modelMetadata(
            '$name/${entry.key}',
            customOptions: GeminiModelFamily.of(entry.key).customOptions,
            info: entry.value,
          ),
        );
  }

  /// Whether [modelName] is called through the Interactions API rather than
  /// generateContent (JS `modelInteractionsMap`).
  ///
  /// The default keeps every model on generateContent; plugins override it.
  bool usesInteractions(String modelName) => false;

  /// The plugin-level `store` option, used when a request doesn't set
  /// `store`; null when not set. Interactions models treat null as false;
  /// generateContent models only send it when set (see
  /// [supportsGenerateContentStore]).
  bool? get store => null;

  /// Whether this plugin's generateContent API takes a top-level `store`
  /// (on the Gemini API it controls whether the server logs the request for
  /// the project). When false, `store: true` is dropped with a warning (the
  /// Gemini Enterprise Agent Platform has no such field).
  bool get supportsGenerateContentStore => false;

  /// Whether Interactions requests send `safety_settings`. The Gemini API
  /// rejects the field (400), so by default permissive settings are dropped
  /// and blocking ones throw; the Gemini Enterprise Agent Platform accepts
  /// it (vertexAI overrides this).
  bool get supportsInteractionSafetySettings => false;

  /// Server-side tool step types left out of a stateless (`store: false`)
  /// history on the Interactions API, because the server rejects them when
  /// they're sent back (vertexAI). A warning is logged once when any are
  /// left out.
  Set<String> get unsupportedResentStepTypes => const {};

  /// Whether Interactions requests to text-to-speech models ask for audio
  /// by default (a `{type: audio}` response format). The Gemini API needs
  /// it; vertexAI sends its TTS models through generateContent.
  bool get defaultsTtsToAudio => true;

  /// Whether this plugin sends the `serviceTier` option to the API. When
  /// false, it is dropped with a warning (the vertexAI plugin has no service
  /// tier option in JS).
  bool get supportsServiceTier => false;

  /// Whether this plugin uses the vertexAI-only options (`location`,
  /// `labels`, `vertexRetrieval`, `payGo`, `videoFormat.gcsUri`). When false
  /// (the Gemini API has no such fields), they are dropped with a warning
  /// (see [warnDroppedVertexOptions]).
  bool get supportsVertexOptions => false;

  /// Whether this plugin's generateContent TTS models take `audioFormat`
  /// (as `generationConfig.responseFormat`) and join streamed audio chunks
  /// into one part in the final response (vertexAI, as in JS). When false,
  /// `audioFormat` is dropped with a warning there and streamed chunks are
  /// returned as they arrived (googleAI, whose generateContent TTS models
  /// are all deprecated; its newer TTS models use the Interactions API).
  bool get generateContentTtsFormats => false;

  Model createModel(String modelName, SchemanticType customOptions) {
    return Model(
      name: '$name/$modelName',
      customOptions: customOptions,
      metadata: {'model': modelInfoFor(modelName).toJson()},
      fn: (req, ctx) async {
        if (usesInteractions(modelName)) {
          return generateWithInteractions(this, modelName, req, ctx);
        }

        gcl.GenerationConfig generationConfig;
        List<gcl.SafetySetting>? safetySettings;
        List<gcl.Tool>? tools;
        gcl.ToolConfig? toolConfig;
        GeminiRetrievalConfig? retrievalConfig;
        String? serviceTier;
        bool? storeFromConfig;
        String? previousInteractionId;

        final isJsonMode =
            req.output?.format == 'json' ||
            req.output?.contentType == 'application/json';

        if (customOptions == GeminiTtsOptions.$schema) {
          final options = req.config == null
              ? GeminiTtsOptions()
              : GeminiTtsOptions.$schema.parse(req.config!);
          serviceTier = options.serviceTier;
          storeFromConfig = options.store;
          previousInteractionId = options.previousInteractionId;
          generationConfig = toGeminiTtsSettings(
            options,
            req.output?.schema,
            isJsonMode,
            constrained: req.output?.constrained ?? false,
          );
          safetySettings = toGeminiSafetySettings(options.safetySettings);
          tools = toGeminiTools(
            req.tools,
            codeExecution: options.codeExecution,
            configTools: options.tools,
            googleSearch: options.googleSearch,
            urlContext: options.urlContext,
          );
          toolConfig = toGeminiToolConfig(
            options.functionCallingConfig,
            toolChoice: req.toolChoice,
            hasFunctionTools: req.tools?.isNotEmpty ?? false,
          );
          retrievalConfig = options.retrievalConfig;
        } else {
          final options = req.config == null
              ? GeminiOptions()
              : GeminiOptions.$schema.parse(req.config!);
          serviceTier = options.serviceTier;
          storeFromConfig = options.store;
          previousInteractionId = options.previousInteractionId;
          generationConfig = toGeminiSettings(
            options,
            req.output?.schema,
            isJsonMode,
            constrained: req.output?.constrained ?? false,
          );
          safetySettings = toGeminiSafetySettings(options.safetySettings);
          tools = toGeminiTools(
            req.tools,
            codeExecution: options.codeExecution,
            configTools: options.tools,
            googleSearch: options.googleSearch,
            urlContext: options.urlContext,
          );
          toolConfig = toGeminiToolConfig(
            options.functionCallingConfig,
            toolChoice: req.toolChoice,
            hasFunctionTools: req.tools?.isNotEmpty ?? false,
          );
          retrievalConfig = options.retrievalConfig;
        }

        if (retrievalConfig != null) {
          toolConfig ??= gcl.ToolConfig();
          toolConfig.toJson()['retrievalConfig'] = retrievalConfig.toJson();
        }

        warnDroppedVertexOptions(this, modelName, req.config);

        // Family fields (see model.dart), read from the config whatever the
        // model's family, as in JS.
        final config = req.config ?? const <String, dynamic>{};

        // vertexAI-only fields (the vertexAI fields are the same on every
        // Gemini option type).
        final vertexOptions = GeminiOptions.$schema.parse(config);
        final labels = supportsVertexOptions
            ? toGeminiLabels(vertexOptions.labels)
            : null;
        final vertexRetrieval = vertexOptions.vertexRetrieval;
        if (supportsVertexOptions && vertexRetrieval != null) {
          // After the other tools, as in JS.
          tools = [
            ...tools,
            gcl.Tool.fromJson({
              'retrieval': {
                'vertexAiSearch': {
                  'datastore': vertexSearchDatastore(vertexRetrieval.datastore),
                },
                'disableAttribution': ?vertexRetrieval.disableAttribution,
              },
            }),
          ];
        }
        final imageConfig = GeminiImageOptions.$schema
            .parse(config)
            .imageConfig;
        if (imageConfig != null) {
          generationConfig.toJson()['imageConfig'] = imageConfig.toJson();
        }
        // TTS models on vertexAI: audioFormat is the generateContent
        // `responseFormat`, and audio is asked for by default (as in JS).
        final isTts = GeminiModelFamily.of(modelName) == .tts;
        final audioFormat = GeminiTtsOptions.$schema.parse(config).audioFormat;
        if (generateContentTtsFormats) {
          final responseFormat = toGeminiAudioResponseFormat(audioFormat);
          if (responseFormat != null) {
            generationConfig.toJson()['responseFormat'] = responseFormat;
          }
          if (isTts && generationConfig.responseModalities == null) {
            generationConfig.responseModalities = ['AUDIO'];
          }
        } else if (audioFormat != null) {
          // generateContent rejects unknown generationConfig fields with a
          // 400 (googleAI's generateContent TTS models have no such field).
          warnDroppedConfigField(modelName, 'audioFormat');
        }
        // No equivalent on generateContent for these Interactions-only
        // fields. JS forwards videoConfig; it's dropped here too, for the
        // same reason.
        final videoOptions = GeminiVideoOptions.$schema.parse(config);
        if (videoOptions.videoFormat != null) {
          warnDroppedConfigField(modelName, 'videoFormat');
        }
        if (videoOptions.videoConfig != null) {
          warnDroppedConfigField(modelName, 'videoConfig');
        }

        // There's no stored conversation to continue on generateContent.
        if (previousInteractionId?.isNotEmpty ?? false) {
          logger.warning(
            'previousInteractionId is not supported for this model and will '
            'be ignored.',
          );
        }
        // On generateContent, `store` only controls whether the server logs
        // this request for the API key's project (viewable in AI Studio's
        // Logs and Datasets); there's nothing to continue. Sent only when
        // set; otherwise the project's logging setting applies. Where the
        // API has no `store` (the Gemini Enterprise Agent Platform), nothing
        // is stored for later anyway, so only `store: true` asks for
        // something that can't happen.
        final generateContentStore = storeFromConfig ?? store;
        if (generateContentStore == true && !supportsGenerateContentStore) {
          warnDroppedConfigField(modelName, 'store');
        }
        if (serviceTier != null && !supportsServiceTier) {
          warnDroppedConfigField(modelName, 'serviceTier');
        }

        final service = await getApiClientForRequest(req.config);

        // Aborts the in-flight request on a plugin-owned client; an injected
        // client's close() is a no-op, so cancellation there only lands at
        // the next throwIfCancelled checkpoint.
        final disposeCancel = ctx.cancel?.onCancel(service.client.close);

        try {
          ctx.cancel?.throwIfCancelled();

          final systemMessage = req.messages
              .where((m) => m.role == Role.system)
              .firstOrNull;
          final messages = req.messages
              .where((m) => m.role != Role.system)
              .toList();

          final generateRequest = gcl.GenerateContentRequest(
            contents: toGeminiContent(messages),
            tools: tools.isEmpty ? null : tools,
            toolConfig: toolConfig,
            generationConfig: generationConfig,
            safetySettings: safetySettings?.isEmpty ?? true
                ? null
                : safetySettings,
            systemInstruction: systemMessage == null
                ? null
                : gcl.Content(
                    parts: systemMessage.content.map(toGeminiPart).toList(),
                    role: 'system',
                  ),
          );
          if (serviceTier != null && supportsServiceTier) {
            generateRequest.toJson()['serviceTier'] = serviceTier;
          }
          if (generateContentStore != null && supportsGenerateContentStore) {
            generateRequest.toJson()['store'] = generateContentStore;
          }
          if (labels != null) {
            generateRequest.toJson()['labels'] = labels;
          }

          if (ctx.streamingRequested) {
            final stream = service.streamGenerateContent(
              generateRequest,
              model: 'models/$modelName',
            );
            final chunks = <gcl.GenerateContentResponse>[];
            await for (final chunk in stream) {
              ctx.cancel?.throwIfCancelled();

              chunks.add(chunk);
              if (chunk.candidates?.isNotEmpty == true) {
                final (message, finishReason) = fromGeminiCandidate(
                  chunk.candidates!.first,
                );
                ctx.sendChunk(
                  ModelResponseChunk(index: 0, content: message.content),
                );
              }
            }
            ctx.cancel?.throwIfCancelled();
            final aggregated = aggregateResponses(chunks);
            if (aggregated.candidates?.isEmpty ?? true) {
              final blockReason = aggregated.promptFeedback?.blockReason;
              throw Exception(
                'No candidates returned from generative stream. Block reason: $blockReason',
              );
            }
            final candidate = aggregated.candidates!.first;
            var (message, finishReason) = fromGeminiCandidate(candidate);
            if (isTts && generateContentTtsFormats) {
              // Streamed audio arrives as many headerless chunks (audio/l16
              // by default); join them into one part, like a non-streamed
              // response (JS vertexAI).
              message = Message(
                role: message.role,
                content: mergeStreamedAudio(message.content),
                metadata: message.metadata,
              );
            }
            return ModelResponse(
              finishReason: finishReason,
              finishMessage: candidate.finishMessage,
              message: message,
              raw: aggregated.toJson(),
              usage: extractUsage(aggregated.usageMetadata),
            );
          } else {
            final response = await service.generateContent(
              generateRequest,
              model: 'models/$modelName',
            );
            ctx.cancel?.throwIfCancelled();
            if (response.candidates?.isEmpty ?? true) {
              final blockReason = response.promptFeedback?.blockReason;
              throw Exception(
                'No candidates returned from generateContent. Block reason: $blockReason',
              );
            }
            final candidate = response.candidates!.first;
            final (message, finishReason) = fromGeminiCandidate(candidate);
            return ModelResponse(
              finishReason: finishReason,
              finishMessage: candidate.finishMessage,
              message: message,
              raw: response?.toJson(),
              usage: extractUsage(response.usageMetadata),
            );
          }
        } catch (e, stack) {
          throw handleException(e, stack);
        } finally {
          disposeCancel?.call();
          service.client.close();
        }
      },
    );
  }

  Embedder createEmbedder(String embedderName);

  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType == .embedder) {
      return createEmbedder(name);
    }
    if (actionType == .model) {
      return createModel(name, GeminiModelFamily.of(name).customOptions);
    }
    return null;
  }

  GenkitException handleException(Object e, StackTrace stack) {
    if (e is GenkitException) return e;

    int? httpStatus;
    String? message;

    try {
      if ((e as dynamic).status != null) {
        httpStatus = (e as dynamic).status as int?;
      } else if ((e as dynamic).code != null) {
        httpStatus = (e as dynamic).code as int?;
      }
      if ((e as dynamic).message != null) {
        message = (e as dynamic).message as String?;
      }
    } catch (_) {}

    if (httpStatus != null) {
      return GenkitException(
        message ?? 'Google AI API Error: $httpStatus',
        status: StatusCode.fromHttpStatus(httpStatus),
        cause: e,
        stackTrace: stack,
      );
    }

    return GenkitException(
      'Google AI Error: $e',
      status: StatusCode.internal,
      cause: e,
      stackTrace: stack,
    );
  }
}

/// Warns (once per model and field) about the vertexAI-only options in
/// [config] when [plugin] doesn't use them (see
/// [CommonGoogleGenPlugin.supportsVertexOptions]). The caller leaves them
/// out of the request.
void warnDroppedVertexOptions(
  CommonGoogleGenPlugin plugin,
  String modelName,
  Map<String, dynamic>? config,
) {
  if (plugin.supportsVertexOptions || config == null) return;
  // The fields are the same on every Gemini option type (see model.dart).
  final options = GeminiVideoOptions.$schema.parse(config);
  for (final (field, value) in [
    ('location', options.location),
    ('labels', options.labels),
    ('vertexRetrieval', options.vertexRetrieval),
    ('payGo', options.payGo),
    ('videoFormat.gcsUri', options.videoFormat?.gcsUri),
  ]) {
    if (value != null) warnDroppedConfigField(modelName, field);
  }
}

(Message, FinishReason) fromGeminiCandidate(gcl.Candidate candidate) {
  final message = Message(
    role: Role(candidate.content?.role ?? 'model'),
    content: candidate.content?.parts?.map(fromGeminiPart).toList() ?? [],
  );
  return (message, _toFinishReason(candidate.finishReason));
}

/// Maps a Gemini finish reason onto Genkit's vocabulary.
///
/// No published list is complete: the discovery doc, protos, Gen AI SDKs and
/// Firebase SDKs each lag the live API differently, so this is the union of
/// all of them. A missing or `FINISH_REASON_UNSPECIFIED` reason maps to
/// [FinishReason.unknown], so a turn that names no reason still returns its
/// text. Any other unrecognized reason maps to [FinishReason.other]: new
/// values tend to be blocks or failures, and `other` is abnormal, so output
/// parsing is skipped and `finishMessage` explains why.
FinishReason _toFinishReason(String? raw) {
  switch (raw) {
    case null:
    case '':
    case 'FINISH_REASON_UNSPECIFIED':
      return FinishReason.unknown;
    case 'STOP':
      return FinishReason.stop;
    case 'MAX_TOKENS':
      return FinishReason.length;
    case 'SAFETY':
    case 'RECITATION':
    case 'LANGUAGE':
    case 'BLOCKLIST':
    case 'PROHIBITED_CONTENT':
    case 'SPII':
    case 'IMAGE_SAFETY':
    case 'IMAGE_PROHIBITED_CONTENT':
    case 'IMAGE_RECITATION':
    // Vertex only; reaches here via genkit_vertexai.
    case 'MODEL_ARMOR':
    // Only listed in the Gemini discovery doc so far.
    case 'ESCALATION':
    case 'PUP_LIMITED_DISABLED':
      return FinishReason.blocked;
    case 'MALFORMED_FUNCTION_CALL':
    case 'UNEXPECTED_TOOL_CALL':
    case 'TOO_MANY_TOOL_CALLS':
    case 'NO_IMAGE':
    case 'IMAGE_OTHER':
    case 'MALFORMED_RESPONSE':
    // Gemini 3 returns this when thought signatures are missing from the
    // request; treat it as a non-fatal "other" like the Go plugin.
    case 'MISSING_THOUGHT_SIGNATURE':
    case 'OTHER':
      return FinishReason.other;
    default:
      // Deliberately differs from Go/JS, which return `unknown` here.
      return FinishReason.other;
  }
}

@visibleForTesting
gcl.GenerationConfig toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode, {
  bool constrained = false,
}) {
  return gcl.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences?.isEmpty ?? true
        ? null
        : options.stopSequences,
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    seed: options.seed,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType?.isEmpty ?? true
              ? null
              : options.responseMimeType),
    responseJsonSchema: constrained && isJsonMode ? outputSchema : null,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    responseModalities: options.responseModalities?.isEmpty ?? true
        ? null
        : options.responseModalities!.map((m) => m.toUpperCase()).toList(),
    speechConfig: options.speechConfig != null
        ? gcl.SpeechConfig.fromJson(_toSpeechConfig(options.speechConfig)!)
        : null,
    thinkingConfig: options.thinkingConfig != null
        ? gcl.ThinkingConfig.fromJson(
            _toThinkingConfig(options.thinkingConfig)!,
          )
        : null,
  );
}

@visibleForTesting
gcl.GenerationConfig toGeminiTtsSettings(
  GeminiTtsOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode, {
  bool constrained = false,
}) {
  return gcl.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences?.isEmpty ?? true
        ? null
        : options.stopSequences,
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    seed: options.seed,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType?.isEmpty ?? true
              ? null
              : options.responseMimeType),
    responseJsonSchema: constrained && isJsonMode ? outputSchema : null,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseLogprobs: options.responseLogprobs,
    logprobs: options.logprobs,
    responseModalities: options.responseModalities?.isEmpty ?? true
        ? null
        : options.responseModalities!.map((m) => m.toUpperCase()).toList(),
    speechConfig: options.speechConfig != null
        ? gcl.SpeechConfig.fromJson(_toSpeechConfig(options.speechConfig)!)
        : null,
    thinkingConfig: options.thinkingConfig != null
        ? gcl.ThinkingConfig.fromJson(
            _toThinkingConfig(options.thinkingConfig)!,
          )
        : null,
  );
}

Map<String, dynamic>? _toSpeechConfig(GeminiSpeechConfig? config) {
  if (config == null) return null;
  return {
    if (config.voiceConfig != null)
      'voiceConfig': _toVoiceConfig(config.voiceConfig),
    if (config.multiSpeakerVoiceConfig != null)
      'multiSpeakerVoiceConfig': _toMultiSpeakerVoiceConfig(
        config.multiSpeakerVoiceConfig,
      ),
  };
}

Map<String, dynamic>? _toThinkingConfig(GeminiThinkingConfig? config) {
  if (config == null) return null;
  return {
    if (config.includeThoughts != null)
      'includeThoughts': config.includeThoughts,
    if (config.thinkingBudget != null) 'thinkingBudget': config.thinkingBudget,
    if (config.thinkingLevel != null) 'thinkingLevel': config.thinkingLevel,
  };
}

Map<String, dynamic>? _toMultiSpeakerVoiceConfig(
  GeminiMultiSpeakerVoiceConfig? config,
) {
  if (config == null) return null;
  return {
    'speakerVoiceConfigs': config.speakerVoiceConfigs
        .map(_toSpeakerVoiceConfig)
        .toList(),
  };
}

Map<String, Object?> _toSpeakerVoiceConfig(GeminiSpeakerVoiceConfig config) {
  return {
    'speaker': config.speaker,
    'voiceConfig': _toVoiceConfig(config.voiceConfig),
  };
}

Map<String, Object?>? _toVoiceConfig(GeminiVoiceConfig? config) {
  if (config == null) return null;
  return {
    'prebuiltVoiceConfig': _toPrebuiltVoiceConfig(config.prebuiltVoiceConfig),
  };
}

Map<String, Object?>? _toPrebuiltVoiceConfig(
  GeminiPrebuiltVoiceConfig? config,
) {
  if (config == null) return null;
  return {'voiceName': config.voiceName};
}

@visibleForTesting
List<gcl.SafetySetting>? toGeminiSafetySettings(
  List<GeminiSafetySettings>? safetySettings,
) {
  if (safetySettings == null) return null;
  final settings = <gcl.SafetySetting>[];
  for (final s in safetySettings) {
    final category = s.category;
    if (category == null || category == 'HARM_CATEGORY_UNSPECIFIED') {
      logger.warning(
        'Dropping safety setting with unset or UNSPECIFIED category: '
        'the API rejects HARM_CATEGORY_UNSPECIFIED.',
      );
      continue;
    }
    settings.add(gcl.SafetySetting(category: category, threshold: s.threshold));
  }
  return settings;
}

/// Reads a text part's `metadata.speechMetadata` (`{speaker?, style?}`),
/// used by TTS models to assign each turn to a speaker and set its delivery
/// style (JS common toGeminiSpeechMetadata). Returns null if neither is set.
Map<String, String>? _toGeminiSpeechMetadata(Object? value) {
  if (value is! Map) return null;
  final speaker = value['speaker'];
  final style = value['style'];
  final result = {
    if (speaker is String && speaker.isNotEmpty) 'speaker': speaker,
    if (style is String && style.isNotEmpty) 'style': style,
  };
  return result.isEmpty ? null : result;
}

/// Converts the TTS `audioFormat` (`{mimeType: 'audio/mulaw'}`) to the
/// generateContent `responseFormat` (`[{audio: {mimeType: 'AUDIO_MULAW'}}]`)
/// (JS vertexai toGeminiAudioResponseFormat). Returns null when no mimeType
/// is set, so the server defaults apply (audio/wav, or audio/l16 when
/// streaming).
@visibleForTesting
List<Map<String, Object?>>? toGeminiAudioResponseFormat(
  GeminiAudioFormat? audioFormat,
) {
  final mimeType = audioFormat?.mimeType;
  if (audioFormat == null || mimeType == null) return null;
  return [
    {
      'audio': {
        ...audioFormat.toJson(),
        // 'audio/mulaw' -> 'AUDIO_MULAW'; enum values pass through.
        'mimeType': mimeType.toUpperCase().replaceFirst('/', '_'),
      },
    },
  ];
}

/// The request's `labels` without empty keys; null when none are left (JS
/// vertexai toGeminiLabels). Used on both APIs.
Map<String, String>? toGeminiLabels(Map<String, String>? labels) {
  if (labels == null) return null;
  final result = {
    for (final MapEntry(:key, :value) in labels.entries)
      if (key.isNotEmpty) key: value,
  };
  return result.isEmpty ? null : result;
}

/// Builds the generateContent `tools`: the request's function tools, then
/// the built-in tools from the config, in the JS plugin's order. The
/// [configTools] maps (the `tools` option, e.g. `{'googleMaps': {}}`) are
/// sent as they are.
@visibleForTesting
List<gcl.Tool> toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
  List<Map<String, dynamic>>? configTools,
  GeminiGoogleSearch? googleSearch,
  GeminiUrlContext? urlContext,
}) {
  return [
    ...(tools?.map(_toGeminiTool) ?? []),
    if (codeExecution == true) gcl.Tool(codeExecution: gcl.CodeExecution()),
    ...?configTools?.map(gcl.Tool.fromJson),
    if (googleSearch != null) gcl.Tool(googleSearch: gcl.GoogleSearch()),
    // The generated client has no urlContext field.
    if (urlContext != null)
      gcl.Tool.fromJson({'urlContext': urlContext.toJson()}),
  ];
}

/// Builds Gemini's `toolConfig` from the plugin-specific
/// [functionCallingConfig] or, when that is absent, the portable Genkit
/// [toolChoice] (`auto` / `required` / `none` map to Gemini's `AUTO` / `ANY` /
/// `NONE`). The plugin config wins because it is strictly more expressive
/// (allowed function names). Unknown [toolChoice] values are ignored.
///
/// [toolChoice] only applies when [hasFunctionTools] is true, i.e. the request
/// declares Genkit tools. Built-in tools (Google Search, code execution) don't
/// count: a function-calling mode with no function declarations is
/// contradictory (`required` would demand a call to nothing).
@visibleForTesting
gcl.ToolConfig? toGeminiToolConfig(
  GeminiFunctionCallingConfig? functionCallingConfig, {
  ToolChoice? toolChoice,
  bool hasFunctionTools = false,
}) {
  if (functionCallingConfig == null) {
    if (!hasFunctionTools) return null;
    final mode = switch (toolChoice?.value) {
      'auto' => 'AUTO',
      'required' => 'ANY',
      'none' => 'NONE',
      _ => null,
    };
    if (mode == null) return null;
    return gcl.ToolConfig(
      functionCallingConfig: gcl.FunctionCallingConfig(mode: mode),
    );
  }
  return gcl.ToolConfig(
    functionCallingConfig: gcl.FunctionCallingConfig(
      mode: functionCallingConfig.mode ?? 'MODE_UNSPECIFIED',
      allowedFunctionNames:
          functionCallingConfig.allowedFunctionNames
              ?.map(_toGeminiToolName)
              .toList() ??
          [],
    ),
  );
}

/// Maps a Genkit [Role] to the role string expected by the Gemini API.
///
/// Gemini's Content API only understands `user` and `model` roles. Tool
/// (function response) messages must be sent with the `user` role for
/// compatibility.
@visibleForTesting
String toGeminiRole(Role role) {
  if (role == Role.model) return 'model';
  // user, tool and anything else map to 'user'.
  return 'user';
}

/// Embeds each of [docs] with the `:embedContent` method: one request per
/// document, with its text and media as parts (the googleAI embedders, and
/// gemini-embedding-2 and newer on vertexAI, as in JS).
///
/// [sendTaskTypeAndTitle] is false where the model has no such fields
/// (vertexAI's gemini-embedding-2; the caller warns about them).
Future<List<Embedding>> embedWithEmbedContent(
  GenerativeLanguageBaseClient service, {
  required String embedderName,
  required List<DocumentData> docs,
  GoogleGenAiEmbedderOptions? options,
  bool sendTaskTypeAndTitle = true,
}) {
  // Built first, so malformed media fails before any request is sent.
  final contents = [
    for (final (index, doc) in docs.indexed)
      gcl.Content(role: 'user', parts: _embedParts(index, doc)),
  ];
  return Future.wait(
    contents.map((content) async {
      final res = await service.embedContent(
        gcl.EmbedContentRequest(
          content: content,
          outputDimensionality: options?.outputDimensionality,
          taskType: sendTaskTypeAndTitle ? options?.taskType : null,
          title: sendTaskTypeAndTitle ? options?.title : null,
        ),
        model: 'models/$embedderName',
      );
      return Embedding(embedding: res.embedding?.values ?? []);
    }),
  );
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

/// Whether [name] (bare or resource-prefixed) names an embedding model:
/// any name containing `embedding`, such as `text-embedding-004`,
/// `gemini-embedding-2`, or `multimodalembedding`.
bool isEmbedderModelName(String name) => name.contains('embedding');

@visibleForTesting
List<gcl.Content> toGeminiContent(List<Message> messages) {
  return messages
      .map(
        (m) => gcl.Content(
          role: toGeminiRole(m.role),
          parts: m.content.map(toGeminiPart).toList(),
        ),
      )
      .toList();
}

@internal
gcl.Part toGeminiPart(Part p) {
  final thoughtSignature = p.metadata?['thoughtSignature'] != null
      ? p.metadata!['thoughtSignature'] as String
      : null;

  if (p.isReasoning) {
    return gcl.Part(
      text: p.reasoning,
      thought: true,
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isText) {
    final part = gcl.Part(text: p.text, thoughtSignature: thoughtSignature);
    // The generated client has no speechMetadata field.
    final speechMetadata = _toGeminiSpeechMetadata(
      p.metadata?['speechMetadata'],
    );
    if (speechMetadata != null) {
      part.toJson()['speechMetadata'] = speechMetadata;
    }
    return part;
  }
  if (p.isToolRequest) {
    return gcl.Part(
      functionCall: gcl.FunctionCall(
        id: p.toolRequest!.ref ?? '',
        name: _toGeminiToolName(p.toolRequest!.name),
        args: p.toolRequest!.input is Map
            ? (p.toolRequest!.input as Map).cast<String, Object?>()
            : null,
      ),

      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isToolResponse) {
    final tr = p.toolResponse!;
    // Multipart tool content (images, media, etc.) becomes function-response
    // parts. Gemini's FunctionResponse.parts only supports inline/file data
    // (see js-genai `FunctionResponsePart`), so we map media parts to their
    // `inlineData`/`fileData` shape and skip parts that cannot be represented
    // there (e.g. text) which would otherwise be rejected by the API. The
    // structured result still travels in `response.output`.
    final contentParts = tr.content
        ?.map((c) => Part.fromJson(c as Map<String, dynamic>))
        .where((part) => part.isMedia)
        .map((part) => toGeminiPart(part).toJson())
        .toList();
    return gcl.Part(
      functionResponse: gcl.FunctionResponse.fromJson({
        'id': tr.ref ?? '',
        'name': _toGeminiToolName(tr.name),
        'response': {'output': tr.output},
        'parts': ?(contentParts == null || contentParts.isEmpty
            ? null
            : contentParts),
      }),

      thoughtSignature: thoughtSignature,
    );
  }

  if (p.isMedia) {
    final media = p.media;
    if (media!.url.startsWith('data:')) {
      final uri = Uri.parse(media.url);
      if (uri.data != null) {
        return gcl.Part.fromJson({
          'inlineData': {
            'mimeType': media.contentType ?? uri.data!.mimeType,
            'data': base64Encode(uri.data!.contentAsBytes()),
          },
          'thoughtSignature': ?thoughtSignature,
        });
      }
    }
    return gcl.Part.fromJson({
      'fileData': {'mimeType': media.contentType ?? '', 'fileUri': media.url},
      'thoughtSignature': ?thoughtSignature,
    });
  }
  if (p.isCustom && p.custom!['codeExecutionResult'] != null) {
    p as CustomPart;
    return gcl.Part(
      codeExecutionResult: gcl.CodeExecutionResult(
        outcome:
            (p.custom['codeExecutionResult'] as Map<String, dynamic>)['outcome']
                as String?,
        output:
            (p.custom['codeExecutionResult'] as Map<String, dynamic>)['output']
                as String?,
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  if (p.isCustom && p.custom!['executableCode'] != null) {
    p as CustomPart;
    return gcl.Part(
      executableCode: gcl.ExecutableCode(
        language:
            (p.custom['executableCode'] as Map<String, dynamic>)['language']
                as String?,
        code:
            (p.custom['executableCode'] as Map<String, dynamic>)['code']
                as String?,
      ),
      thoughtSignature: thoughtSignature,
    );
  }
  final kind = p.toJson().keys.where((key) => key != 'metadata').join(', ');
  throw UnimplementedError('Unsupported part type: $kind');
}

@visibleForTesting
Part fromGeminiPart(gcl.Part p) {
  final metadata = <String, dynamic>{
    if (p.thoughtSignature != null) 'thoughtSignature': p.thoughtSignature,
  };

  if (p.text != null) {
    if (p.thought == true) {
      return ReasoningPart(reasoning: p.text!, metadata: metadata);
    }
    return TextPart(text: p.text!, metadata: metadata);
  }
  if (p.functionCall != null) {
    return ToolRequestPart(
      toolRequest: ToolRequest(
        ref: p.functionCall!.id == '' ? null : p.functionCall!.id,
        name: _fromGeminiToolName(p.functionCall!.name ?? ''),
        input: p.functionCall!.args,
      ),
      metadata: metadata,
    );
  }
  if (p.codeExecutionResult != null) {
    return CustomPart(
      custom: {'codeExecutionResult': p.codeExecutionResult!.toJson()},
      metadata: metadata,
    );
  }
  if (p.executableCode != null) {
    return CustomPart(
      custom: {'executableCode': p.executableCode!.toJson()},
      metadata: metadata,
    );
  }
  if (p.inlineData != null) {
    final mimeType = p.inlineData!.mimeType;
    final data = p.inlineData!.data;
    if (data != null) {
      return MediaPart(
        media: Media(url: 'data:$mimeType;base64,$data', contentType: mimeType),
        metadata: metadata,
      );
    }
  }
  if (p.fileData != null) {
    final mimeType = p.fileData!.mimeType;
    final fileUri = p.fileData!.fileUri;
    if (fileUri != null) {
      return MediaPart(
        media: Media(url: fileUri, contentType: mimeType),
        metadata: metadata,
      );
    }
  }
  throw UnimplementedError('Unsupported part type: ${p.toJson()}');
}

String _toGeminiToolName(String name) => name.replaceAll('/', '__');

String _fromGeminiToolName(String name) => name.replaceAll('__', '/');

gcl.Tool _toGeminiTool(ToolDefinition tool) {
  return gcl.Tool(
    functionDeclarations: [
      gcl.FunctionDeclaration(
        name: _toGeminiToolName(tool.name),
        description: tool.description,
        parametersJsonSchema: tool.inputSchema,
      ),
    ],
  );
}

@visibleForTesting
GenerationUsage? extractUsage(gcl.UsageMetadata? metadata) {
  if (metadata == null) return null;
  return GenerationUsage(
    inputTokens: metadata.promptTokenCount,
    outputTokens: metadata.candidatesTokenCount,
    totalTokens: metadata.totalTokenCount,
    thoughtsTokens: metadata.thoughtsTokenCount,
    cachedContentTokens: metadata.cachedContentTokenCount,
    custom: {
      // Same key as on the Interactions API (as in JS).
      if (metadata.toolUsePromptTokenCount case final tokens? when tokens != 0)
        'toolUseTokens': tokens,
    },
  );
}

const _apiKeyEnvVars = ['GOOGLE_API_KEY', 'GEMINI_API_KEY'];

http.Client httpClientFromApiKey(String? apiKey) {
  apiKey ??= _apiKeyEnvVars.map(getConfigVar).nonNulls.firstOrNull;
  var headers = {
    'X-Goog-Api-Client':
        'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}',
    'x-goog-api-key': ?apiKey,
  };
  if (apiKey == null) {
    throw GenkitException(
      'apiKey must be set to an API key',
      status: StatusCode.invalidArgument,
    );
  }
  final baseClient = CustomClient(defaultHeaders: headers);
  return baseClient;
}

/// Delegates to a caller-owned client but ignores `close()`, so a plugin's
/// per-call cleanup never tears down an injected transport.
class NonClosingClient extends http.BaseClient {
  /// Wraps [_inner], which stays owned by whoever supplied it.
  NonClosingClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {}
}

class CustomClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> defaultHeaders;

  CustomClient({required this.defaultHeaders, http.Client? inner})
    : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(defaultHeaders);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
