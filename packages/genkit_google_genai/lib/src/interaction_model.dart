// Copyright 2026 Google LLC
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

// The Interactions API branch of a Gemini model call.
//
// Mirrors the `useInteractions` branch of the model function in
// js/plugins/google-genai/src/googleai/gemini.ts (as on the JS branch
// `if-fixStore`, Oct 27 2026). Keep the two in step: change JS first, then
// translate.
//
// Differences from JS (decided for Dart):
// - No config passthrough: Dart only sends the GeminiOptions fields it
//   knows, so unknown config keys never reach the server.
// - GeminiOptions fields with no effect on Interactions models are dropped
//   with a warning (once per model and field): topK (accepted but ignored;
//   deprecated), presencePenalty, frequencyPenalty, responseMimeType
//   outside JSON mode, and candidateCount (only warned about when > 1, as
//   in JS). JS forwards topK; a JS TODO is open to stop that.
// - responseLogprobs / logprobs are sent (they work on gemini-4-argon).
// - The family fields (imageConfig, audioFormat, videoFormat, videoConfig)
//   are read through their option types (GeminiImageOptions, ...); JS
//   reads them from the untyped config.
//
// Not ported (Dart has no such option): toolConfig, legacyResponseSchema.

import 'dart:convert';

import 'package:genkit/plugin.dart';

import 'common_plugin.dart';
import 'interaction_converters.dart';
import 'interaction_types.dart';
import 'known_models.dart';
import 'model.dart';

/// Calls [modelName] through the Interactions API for [plugin].
Future<ModelResponse> generateWithInteractions(
  CommonGoogleGenPlugin plugin,
  String modelName,
  ModelRequest req,
  ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
) async {
  // GeminiTtsOptions has the same fields as GeminiOptions, so one view
  // reads both. A copy, so the request config is never changed.
  final options = GeminiOptions.$schema.parse({...?req.config});
  final request = buildInteractionRequest(plugin, modelName, req, options);

  final service = await plugin.getApiClient(options.apiKey);
  // Aborts the in-flight request on a plugin-owned client; an injected
  // client's close() is a no-op, so cancellation there only lands at the
  // next throwIfCancelled checkpoint.
  final disposeCancel = ctx.cancel?.onCancel(service.client.close);
  try {
    ctx.cancel?.throwIfCancelled();
    if (!ctx.streamingRequested) {
      final interaction = await service.createInteraction(request);
      ctx.cancel?.throwIfCancelled();
      return fromInteractionSync(interaction);
    }

    final toChunkParts = createInteractionChunkConverter();
    final assembler = InteractionStreamAssembler();
    await for (final event in service.createInteractionStream(request)) {
      ctx.cancel?.throwIfCancelled();
      assembler.add(event);
      final chunkParts = toChunkParts(
        event,
      ).map(removeId3FromAudio).where(_hasContent).toList();
      if (chunkParts.isNotEmpty) {
        ctx.sendChunk(ModelResponseChunk(index: 0, content: chunkParts));
      }
    }
    ctx.cancel?.throwIfCancelled();
    final out = fromInteractionSync(assembler.interaction);
    // Streamed audio arrives as many headerless chunks (raw PCM by
    // default); the final response joins them into one part of the same
    // format.
    final message = out.message;
    if (message != null) {
      out.message = Message(
        role: message.role,
        content: mergeStreamedAudio(
          message.content.map(removeId3FromAudio).toList(),
        ),
        metadata: message.metadata,
      );
    }
    return out;
  } catch (e, stack) {
    throw plugin.handleException(e, stack);
  } finally {
    disposeCancel?.call();
    service.client.close();
  }
}

/// Whether a stream chunk part has content, i.e. more than metadata.
///
/// A `thought_signature` delta becomes a part with only
/// `metadata.thoughtSignature`, and it arrives before any text. Sent as its
/// own chunk, it gives a first chunk with no text, where
/// `chunk.output` is null; code written for generateContent (where the
/// signature comes on the first text part) assumes it isn't
/// (`chunk.output!`). The signature still reaches the final response, which
/// is what history and tool loops use. Differs from JS, which streams that
/// part (harmless there).
bool _hasContent(Part part) => part.toJson().keys.any((k) => k != 'metadata');

/// Builds the Interactions request for [req] (everything but the call).
///
/// Throws a GenkitException (INVALID_ARGUMENT) for requests the model can't
/// honour: non-text system content, blocking safety settings, speech
/// metadata without a voice, and multi-speaker turns without a speaker.
CreateInteractionRequest buildInteractionRequest(
  CommonGoogleGenPlugin plugin,
  String modelName,
  ModelRequest req,
  GeminiOptions options,
) {
  var messages = [...req.messages];
  if (messages.isEmpty) {
    throw GenkitException(
      'No messages provided.',
      status: StatusCode.invalidArgument,
    );
  }

  if (modelName.startsWith('gemma-')) {
    // Gemma does not allow previous thoughts.
    messages = [
      for (final m in messages)
        Message(
          role: m.role,
          content: m.content
              .where(
                (p) =>
                    !p.isReasoning && p.metadata?['thoughtSignature'] == null,
              )
              .toList(),
          metadata: m.metadata,
        ),
    ];
  }

  // The first system message is sent as the system instruction.
  String? systemInstruction;
  final systemIndex = messages.indexWhere((m) => m.role == Role.system);
  if (systemIndex != -1) {
    final systemMessage = messages.removeAt(systemIndex);
    if (systemMessage.content.any((p) => !p.isText)) {
      throw GenkitException(
        'System message contains non-text content which is not supported '
        'for this model.',
        status: StatusCode.invalidArgument,
      );
    }
    systemInstruction = systemMessage.content.map((p) => p.text).join('\n');
  }

  final tools = <InteractionTool>[...?req.tools?.map(toInteractionTool)];

  // The Gemini API's Interactions endpoint does not accept
  // `safety_settings` (it returns 400), even though the published
  // Interactions spec lists the field. The Gemini Enterprise Agent Platform
  // accepts it, so the vertexAI plugin should map safety settings rather
  // than copy this guard. Permissive settings can be dropped safely: per
  // the Gemini API docs, the adjustable safety filters are Off by default
  // for current Gemini models, so BLOCK_NONE (and HARM_CATEGORY_UNSPECIFIED
  // entries) never block anything beyond the default. Built-in protections
  // against core harms always apply.
  // See https://ai.google.dev/gemini-api/docs/safety-settings
  //
  // Blocking thresholds (BLOCK_ONLY_HIGH and stricter) cannot be honored, so
  // throw rather than silently weaken the requested filtering.
  final blockingSafetySettings = [
    for (final setting in options.safetySettings ?? <GeminiSafetySettings>[])
      if (setting.category != 'HARM_CATEGORY_UNSPECIFIED' &&
          setting.threshold != 'BLOCK_NONE')
        setting.toJson(),
  ];
  if (blockingSafetySettings.isNotEmpty) {
    throw GenkitException(
      'safetySettings with blocking thresholds are not supported for model '
      "'$modelName'. This model applies no additional safety filters by "
      'default (built-in protections against core harms still apply). '
      'Remove the safetySettings or set their thresholds to BLOCK_NONE.',
      status: StatusCode.invalidArgument,
      details: jsonEncode({'safetySettings': blockingSafetySettings}),
    );
  }

  final candidateCount = options.candidateCount;
  if (candidateCount != null && candidateCount > 1) {
    logger.warning(
      'Multiple candidates are not supported for this model with the '
      'Interactions API; only one candidate will be returned.',
    );
  }

  tools.addAll([...?options.tools?.map(toInteractionConfigTool)]);
  if (options.codeExecution == true) {
    tools.add(toInteractionConfigTool({'codeExecution': true}));
  }
  final googleSearch = options.googleSearch;
  if (googleSearch != null) {
    tools.add(toInteractionConfigTool({'googleSearch': googleSearch.toJson()}));
  }
  final fileSearch = options.fileSearch;
  if (fileSearch != null) {
    tools.add(toInteractionConfigTool({'fileSearch': fileSearch.toJson()}));
  }
  final urlContext = options.urlContext;
  if (urlContext != null) {
    tools.add(toInteractionConfigTool({'urlContext': urlContext.toJson()}));
  }
  final retrievalConfig = options.retrievalConfig;
  if (retrievalConfig != null) {
    // There is no retrieval config on the Interactions path; the user
    // location is set on the google_maps tool instead.
    final latLng = retrievalConfig.latLng;
    if (latLng != null && !applyLatLngToGoogleMapsTools(tools, latLng)) {
      logger.warning(
        'retrievalConfig.latLng is only used with the googleMaps tool for '
        'this model and will be ignored.',
      );
    }
    final unsupportedKeys = retrievalConfig.toJson().keys.where(
      (k) => k != 'latLng',
    );
    if (unsupportedKeys.isNotEmpty) {
      logger.warning(
        'retrievalConfig.${unsupportedKeys.join(', retrievalConfig.')} is '
        'not supported for this model with the Interactions API and will be '
        'ignored.',
      );
    }
  }

  return _withGenerationConfig(plugin, modelName, req, options, (
    messages: messages,
    systemInstruction: systemInstruction,
    tools: tools,
  ));
}

/// The second half of [buildInteractionRequest] (split for readability):
/// generation config, tool choice, store, response format and modalities.
CreateInteractionRequest _withGenerationConfig(
  CommonGoogleGenPlugin plugin,
  String modelName,
  ModelRequest req,
  GeminiOptions options,
  ({
    List<Message> messages,
    String? systemInstruction,
    List<InteractionTool> tools,
  })
  parts,
) {
  // JSON output: from Genkit's output config, or (as on generateContent)
  // from `responseMimeType: 'application/json'` in the request config.
  final configMimeType = options.responseMimeType;
  final isJsonMode =
      req.output?.format == 'json' ||
      req.output?.contentType == 'application/json' ||
      configMimeType == 'application/json';

  // Fields with no effect on Interactions models (see the file header).
  void drop(String field) => warnDroppedConfigField(modelName, field);
  if (options.topK != null) drop('topK');
  if (options.presencePenalty != null) drop('presencePenalty');
  if (options.frequencyPenalty != null) drop('frequencyPenalty');
  if (configMimeType != null &&
      configMimeType.isNotEmpty &&
      configMimeType != 'application/json') {
    drop('responseMimeType');
  }

  // Family fields (see model.dart), read from the config whatever the
  // model's family, as in JS.
  final config = req.config ?? const <String, dynamic>{};
  final imageConfig = GeminiImageOptions.$schema.parse(config).imageConfig;
  final audioFormat = GeminiTtsOptions.$schema.parse(config).audioFormat;
  final videoOptions = GeminiVideoOptions.$schema.parse(config);

  final stopSequences = options.stopSequences;
  final generationConfig = toInteractionGenerationConfig({
    'temperature': ?options.temperature,
    'topP': ?options.topP,
    'seed': ?options.seed,
    if (stopSequences != null && stopSequences.isNotEmpty)
      'stopSequences': stopSequences,
    'maxOutputTokens': ?options.maxOutputTokens,
    'responseLogprobs': ?options.responseLogprobs,
    'logprobs': ?options.logprobs,
    'speechConfig': ?options.speechConfig?.toJson(),
    'thinkingConfig': ?options.thinkingConfig?.toJson(),
    'videoConfig': ?videoOptions.videoConfig?.toJson(),
  }, drop);

  final toolChoice = toInteractionToolChoice(
    options.functionCallingConfig,
    req.toolChoice?.value,
  );
  if (toolChoice != null) {
    generationConfig.toolChoice = toolChoice.json;
  }

  final store = options.store == true || plugin.store == true;
  final (:messages, :previousInteractionId) = selectInteractionInput(
    parts.messages,
    store,
    options.previousInteractionId,
  );
  _checkSpeechMetadata(modelName, messages, generationConfig.speechConfig);

  var serviceTier = options.serviceTier;
  if (serviceTier != null && !plugin.supportsServiceTier) {
    drop('serviceTier');
    serviceTier = null;
  }

  final request = CreateInteractionRequest(
    systemInstruction: parts.systemInstruction,
    model: modelName,
    tools: parts.tools.isEmpty ? null : parts.tools,
    generationConfig: generationConfig,
    input: toInteractionSteps(messages),
    serviceTier: serviceTier == null ? null : ServiceTier(serviceTier),
    store: store,
  );

  // One `response_format` with an entry per output type (the deprecated
  // `response_modalities` isn't sent). TTS and image models ask for the same
  // outputs as before by default.
  final responseModalities = options.responseModalities;
  final responseFormat = toInteractionResponseFormat(
    modalities: responseModalities != null && responseModalities.isNotEmpty
        ? responseModalities
        : switch (GeminiModelFamily.of(modelName)) {
            .tts => ['AUDIO'],
            .image => ['TEXT', 'IMAGE'],
            // Video models return video by default (JS sends nothing).
            .text || .video => null,
          },
    imageConfig: imageConfig?.toJson(),
    audioFormat: audioFormat?.toJson(),
    videoFormat: videoOptions.videoFormat?.toJson(),
    // Without a schema the server answers in prose (live: no schema 0/9
    // JSON); an empty schema `{}` gives JSON of any shape (6/6), like
    // `responseMimeType: 'application/json'` on generateContent. (`{type:
    // 'object'}` is no good: it returned `{}` every time.)
    json: isJsonMode
        ? (
            schema:
                ((req.output?.constrained ?? false)
                    ? req.output?.schema
                    : null) ??
                const <String, Object?>{},
          )
        : null,
  );
  if (responseFormat != null) {
    request.responseFormat = responseFormat;
  }

  if (previousInteractionId != null && previousInteractionId.isNotEmpty) {
    request.previousInteractionId = previousInteractionId;
  }
  return request;
}

/// Checks speech metadata (speaker/style on text parts) against the speech
/// config, so the user gets a clear error instead of the server's generic
/// 400.
void _checkSpeechMetadata(
  String modelName,
  List<Message> messages,
  Object? speechConfig,
) {
  final userParts = [
    for (final m in messages)
      if (m.role == Role.user) ...m.content,
  ];

  // Turn-level speech metadata (speaker/style) is only accepted together
  // with a speech_config; without one the server returns a generic 400
  // ("Request contains an invalid argument"), so explain what to set.
  if (speechConfig == null) {
    final hasSpeechMetadata = userParts.any(
      (p) => p.isText && p.metadata?['speechMetadata'] is Map,
    );
    if (hasSpeechMetadata) {
      throw GenkitException(
        'speechMetadata (speaker/style) requires a voice for model '
        "'$modelName'. Set "
        'config.speechConfig.voiceConfig.prebuiltVoiceConfig.voiceName '
        '(or multiSpeakerVoiceConfig for multiple speakers).',
        status: StatusCode.invalidArgument,
      );
    }
    return;
  }

  // Multi-speaker TTS requires every non-empty text part to name a speaker
  // that matches one of the configured speakers. The server's own error
  // talks about "text turns", so explain what to set instead.
  if (speechConfig is Map) {
    final speakers = speechConfig['speakers'];
    final speakerNames = [
      if (speakers is List)
        for (final s in speakers)
          if (s is Map && s['speaker'] is String && s['speaker'] != '')
            s['speaker'] as String,
    ];
    final invalidTurn = userParts
        .where((p) => p.text?.trim().isNotEmpty ?? false)
        .any((p) {
          final speechMetadata = p.metadata?['speechMetadata'];
          return speechMetadata is! Map ||
              speechMetadata['speaker'] is! String ||
              !speakerNames.contains(speechMetadata['speaker']);
        });
    if (invalidTurn) {
      throw GenkitException(
        "Multi-speaker speech for model '$modelName' requires each turn to "
        'be a separate text part with '
        '`metadata: { speechMetadata: { speaker } }` set to one of the '
        'configured speakers (${speakerNames.join(', ')}).',
        status: StatusCode.invalidArgument,
      );
    }
  }
}
