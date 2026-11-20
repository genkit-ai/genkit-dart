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

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';

import '../genkit_firebase_ai.dart';
import 'finish_reason.dart';
import 'grounding.dart';

final _logger = Logger('genkit_firebase_ai');

/// Maps a Genkit [Role] to the role string expected by the Gemini API.
///
/// Gemini's Content API only understands `user` and `model` roles. Tool
/// (function response) messages must be sent with the `user` role for
/// compatibility.
String toGeminiRole(Role role) {
  if (role == Role.model) return 'model';
  // user, tool and anything else map to 'user'.
  return 'user';
}

/// The parts of every system message in [messages], in order, as one
/// `systemInstruction`, or null when there are none.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] for a part
/// other than text, since Gemini's `systemInstruction` takes text only.
fai.Content? toGeminiSystemInstruction(List<Message> messages) {
  final parts = [
    for (final m in messages)
      if (m.role == Role.system)
        for (final part in m.content)
          if (part.isText)
            toGeminiPart(part)
          else
            throw GenkitException(
              'System messages can only contain text; Gemini rejects other '
              'parts in systemInstruction.',
              status: StatusCode.invalidArgument,
            ),
  ];
  return parts.isEmpty ? null : fai.Content('system', parts);
}

Iterable<fai.Content> toGeminiContent(List<Message> messages) {
  return messages.map(
    (msg) => fai.Content(
      toGeminiRole(msg.role),
      msg.content.map(toGeminiPart).toList(),
    ),
  );
}

/// The full media type of a data URL, keeping parameters such as the
/// `rate` in `audio/pcm;rate=24000` that [UriData.mimeType] drops.
String _dataUriMimeType(UriData data) => [
  data.mimeType,
  for (final MapEntry(:key, :value) in data.parameters.entries) '$key=$value',
].join(';');

/// [value] as a string, for the part metadata field at `metadata.[path]`.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] when it is
/// set to something other than a string.
String? _metadataString(Object? value, String path) => switch (value) {
  null => null,
  final String s => s,
  final other => throw GenkitException(
    'metadata.$path must be a string, not $other.',
    status: StatusCode.invalidArgument,
  ),
};

/// Reads a text part's `metadata['speechMetadata']`, which names the speaker
/// (from `speakerVoiceConfigs`) of the part in a multi-speaker TTS request,
/// and optionally a `style`.
///
/// Returns null when there is nothing to send. Throws a [GenkitException] with
/// [StatusCode.invalidArgument] for a value that is not a map of strings.
Map<String, String>? _toSpeechMetadata(Object? value) {
  if (value == null) return null;
  if (value is! Map) {
    throw GenkitException(
      'metadata.speechMetadata must be a map, not $value.',
      status: StatusCode.invalidArgument,
    );
  }
  final result = <String, String>{};
  for (final key in const ['speaker', 'style']) {
    final v = _metadataString(value[key], 'speechMetadata.$key');
    if (v != null) result[key] = v;
  }
  // Nothing to send, so the part goes out as a plain text part.
  return result.isEmpty ? null : result;
}

fai.Part toGeminiPart(Part p) {
  final isThought = p.metadata?['isThought'] == true;
  final thoughtSignature = p.metadata?['thoughtSignature'] as String?;

  // firebase_ai does not officially expose thoughtSignature in its public constructors
  // yet. It only exposes them via `.forTest` constructors meant for internal testing.
  // We use them here but defensively fallback to standard constructors if they
  // are ever removed or changed.
  if (p.isReasoning) {
    try {
      return fai.TextPart.forTest(
        p.reasoning!,
        isThought: true,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.TextPart(p.reasoning!, isThought: true);
    }
  }
  if (p.isText) {
    final speechMetadata = _toSpeechMetadata(p.metadata?['speechMetadata']);
    if (speechMetadata != null) {
      // firebase_ai has a typed SpeechMetadata only from 5.1.0, so send the
      // part as raw JSON to keep the 3.15.0 floor.
      return fai.UnknownPart({
        'text': p.text!,
        'speechMetadata': speechMetadata,
        if (isThought) 'thought': true,
        'thoughtSignature': ?thoughtSignature,
      });
    }
    try {
      return fai.TextPart.forTest(
        p.text!,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.TextPart(p.text!, isThought: isThought);
    }
  }
  if (p.isMedia) {
    final media = p.media!;
    final mediaResolution = _toMediaResolution(
      _metadataString(p.metadata?['mediaResolution'], 'mediaResolution'),
      perPart: true,
    );
    if (media.url.startsWith('data:')) {
      final Uint8List bytes;
      final String mimeType;
      try {
        // `Uri.data` is never null for a `data:` URL; a malformed one throws.
        final data = Uri.parse(media.url).data!;
        bytes = data.contentAsBytes();
        mimeType = media.contentType ?? _dataUriMimeType(data);
      } on FormatException catch (e) {
        // INVALID_ARGUMENT, not INTERNAL: retrying the same request cannot
        // help.
        throw GenkitException(
          'Media part has a malformed data: URL: ${e.message}',
          status: StatusCode.invalidArgument,
          cause: e,
        );
      }
      try {
        return fai.InlineDataPart.forTest(
          mimeType,
          bytes,
          mediaResolution: mediaResolution,
          isThought: isThought,
          thoughtSignature: thoughtSignature,
        );
      } catch (_) {
        return fai.InlineDataPart(
          mimeType,
          bytes,
          mediaResolution: mediaResolution,
          isThought: isThought,
        );
      }
    }
    // Assume HTTP/S or other URLs are File URIs
    try {
      return fai.FileData.forTest(
        media.contentType ?? 'application/octet-stream',
        media.url,
        mediaResolution: mediaResolution,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.FileData(
        media.contentType ?? 'application/octet-stream',
        media.url,
        mediaResolution: mediaResolution,
        isThought: isThought,
      );
    }
  }
  if (p.isToolResponse) {
    final toolResponse = p.toolResponse!;
    // Firebase AI function responses carry a structured map only, so multipart
    // tool content (images, media, etc.) cannot be represented here. Warn so
    // authors of multipart tools can discover the parts are dropped for this
    // provider rather than failing silently.
    if (toolResponse.content?.isNotEmpty ?? false) {
      _logger.warning(
        'Tool "${toolResponse.name}" returned multipart content, but Firebase '
        'AI function responses only support structured output. Dropping '
        '${toolResponse.content!.length} content part(s); only the structured '
        'output is sent.',
      );
    }
    return fai.FunctionResponse(
      toolResponse.name,
      {'result': toolResponse.output},
      id: toolResponse.ref,
      isThought: isThought,
    );
  }
  if (p.isToolRequest) {
    final toolRequest = p.toolRequest!;
    try {
      return fai.FunctionCall.forTest(
        toolRequest.name,
        toolRequest.input is Map
            ? (toolRequest.input as Map).cast<String, Object?>()
            : <String, Object?>{},
        id: toolRequest.ref,
        isThought: isThought,
        thoughtSignature: thoughtSignature,
      );
    } catch (_) {
      return fai.FunctionCall(
        toolRequest.name,
        toolRequest.input is Map
            ? (toolRequest.input as Map).cast<String, Object?>()
            : <String, Object?>{},
        id: toolRequest.ref,
        isThought: isThought,
      );
    }
  }
  if (p.isCustom) {
    final custom = p.custom!;
    for (final key in const ['executableCode', 'codeExecutionResult']) {
      if (custom[key] != null) {
        // The typed parts' public constructors drop thoughtSignature.
        return fai.UnknownPart({
          key: custom[key],
          if (isThought) 'thought': true,
          'thoughtSignature': ?thoughtSignature,
        });
      }
    }
    if (p.metadata?[_rawGeminiPartKey] == true) {
      return fai.UnknownPart({
        ...custom,
        if (isThought) 'thought': true,
        'thoughtSignature': ?thoughtSignature,
      });
    }
  }
  // INVALID_ARGUMENT, not INTERNAL: retrying the same request cannot help.
  throw GenkitException(
    'Part type $p is not supported by the Firebase AI plugin.',
    status: StatusCode.invalidArgument,
  );
}

(Message, FinishReason) fromGeminiCandidate(fai.Candidate candidate) {
  final message = Message(
    role: Role(candidate.content.role ?? 'model'),
    content: candidate.content.parts.map(fromGeminiPart).toList(),
  );
  return (message, finishReasonFromWire(candidate.finishReason?.toJson()));
}

/// The `custom` map for a response, or null when it has nothing to hold.
///
/// It holds the finish reason as `firebase_ai` parsed it, left out when it
/// parsed none or [fai.FinishReason.unknown], whose original wire value is
/// lost, and the candidate's grounding and URL context metadata, rebuilt from
/// what `firebase_ai` parsed.
Map<String, dynamic>? candidateCustom(fai.Candidate candidate) {
  final custom = {
    'finishReason': ?switch (candidate.finishReason) {
      null || fai.FinishReason.unknown => null,
      final reason => reason.toJson(),
    },
    'groundingMetadata': ?groundingMetadataJson(candidate),
    'urlContextMetadata': ?urlContextMetadataJson(candidate),
  };
  return custom.isEmpty ? null : custom;
}

/// Marks a [CustomPart] built from an unparsed API part, so it can go back.
const _rawGeminiPartKey = 'rawGeminiPart';

Part fromGeminiPart(fai.Part p) {
  final pJson = p.toJson() as Map<String, dynamic>;
  final thoughtSignature = pJson['thoughtSignature'] as String?;

  final metadata = <String, dynamic>{
    if (p.isThought == true) 'isThought': true,
    'thoughtSignature': ?thoughtSignature,
  };

  if (p is fai.TextPart) {
    if (p.isThought == true) {
      return ReasoningPart(reasoning: p.text, metadata: metadata);
    }
    return TextPart(text: p.text, metadata: metadata);
  }
  if (p is fai.FunctionCall) {
    return ToolRequestPart(
      toolRequest: ToolRequest(name: p.name, input: p.args, ref: p.id),
      metadata: metadata,
    );
  }
  if (p is fai.InlineDataPart) {
    final base64 = base64Encode(p.bytes);
    return MediaPart(
      media: Media(
        url: 'data:${p.mimeType};base64,$base64',
        contentType: p.mimeType,
      ),
      metadata: metadata,
    );
  }
  if (p is fai.FileData) {
    return MediaPart(
      media: Media(url: p.fileUri, contentType: p.mimeType),
      metadata: metadata,
    );
  }
  if (p is fai.ExecutableCodePart) {
    return CustomPart(
      custom: {'executableCode': pJson['executableCode']},
      metadata: metadata,
    );
  }
  if (p is fai.CodeExecutionResultPart) {
    return CustomPart(
      custom: {'codeExecutionResult': pJson['codeExecutionResult']},
      metadata: metadata,
    );
  }
  if (p is fai.UnknownPart) {
    final custom = {...p.data}
      ..remove('thought')
      ..remove('thoughtSignature');
    return CustomPart(
      custom: custom,
      metadata: {
        _rawGeminiPartKey: true,
        if (p.data['thought'] == true) 'isThought': true,
        'thoughtSignature': ?thoughtSignature,
      },
    );
  }
  final custom = {...pJson}
    ..remove('thought')
    ..remove('thoughtSignature');
  return CustomPart(custom: custom, metadata: metadata);
}

/// Converts the safety settings in [options] to `firebase_ai` ones.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] for a missing,
/// unknown or wrongly typed category or threshold, or, on the Gemini Developer
/// API ([developerApi]), for an image category or a `method`, which it
/// rejects.
List<fai.SafetySetting>? toGeminiSafetySettings(
  GeminiOptions options, {
  required bool developerApi,
}) {
  try {
    return _toGeminiSafetySettings(
      options.safetySettings,
      developerApi: developerApi,
    );
  } on GenkitException {
    rethrow;
  } catch (e) {
    // A wrongly typed list or field fails in the generated getters.
    throw GenkitException(
      'Invalid safetySettings: $e',
      status: StatusCode.invalidArgument,
    );
  }
}

List<fai.SafetySetting>? _toGeminiSafetySettings(
  List<GeminiSafetySettings>? settings, {
  required bool developerApi,
}) {
  if (settings == null) return null;
  return [
    for (final s in settings)
      fai.SafetySetting(
        switch (_wireValue(
          'category',
          s.category,
          _harmCategories,
          expected: developerApi
              ? _harmCategories.keys.where(
                  (c) => !_imageCategories.contains(_harmCategories[c]),
                )
              : null,
        )) {
          final category
              when developerApi && _imageCategories.contains(category) =>
            throw GenkitException(
              'safetySettings category ${s.category} is not supported by the '
              'Gemini Developer API; use FirebaseAiProvider.agentPlatform() or '
              'remove it.',
              status: StatusCode.invalidArgument,
            ),
          final category => category,
        },
        _wireValue('threshold', s.threshold, _harmBlockThresholds),
        switch (s.method) {
          null => null,
          _ when developerApi => throw GenkitException(
            'safetySettings method is not supported by the Gemini Developer '
            'API; use FirebaseAiProvider.agentPlatform() or remove it.',
            status: StatusCode.invalidArgument,
          ),
          final method => _wireValue('method', method, _harmBlockMethods),
        },
      ),
  ];
}

final _harmCategories = {
  for (final c in fai.HarmCategory.values)
    if (c != fai.HarmCategory.unknown) c.toJson(): c,
};

/// Image categories, which the Gemini Developer API rejects.
const _imageCategories = {
  fai.HarmCategory.imageHate,
  fai.HarmCategory.imageDangerousContent,
  fai.HarmCategory.imageHarassment,
  fai.HarmCategory.imageSexuallyExplicit,
};

final _harmBlockThresholds = {
  for (final t in fai.HarmBlockThreshold.values) t.toJson() as String: t,
};

final _harmBlockMethods = {
  for (final m in [
    fai.HarmBlockMethod.severity,
    fai.HarmBlockMethod.probability,
  ])
    m.toJson() as String: m,
};

/// The enum value of safety setting [field] whose wire name is [value].
///
/// The error for an unknown [value] lists [expected], or every wire name.
T _wireValue<T>(
  String field,
  String? value,
  Map<String, T> byWireName, {
  Iterable<String>? expected,
}) {
  if (byWireName[value] case final match?) return match;
  throw GenkitException(
    value == null
        ? 'safetySettings entries need a $field.'
        : 'Unknown safetySettings $field "$value"; expected one of '
              '${(expected ?? byWireName.keys).join(', ')}.',
    status: StatusCode.invalidArgument,
  );
}

List<fai.Tool>? toGeminiTools(
  List<ToolDefinition>? tools, {
  bool? codeExecution,
  bool googleSearch = false,
  bool urlContext = false,
  bool googleMaps = false,
}) {
  final result = [
    if (tools != null) ...tools.map(_toGeminiTool),
    if (codeExecution == true) fai.Tool.codeExecution(),
    if (googleSearch) fai.Tool.googleSearch(),
    if (urlContext) fai.Tool.urlContext(),
    if (googleMaps) fai.Tool.googleMaps(),
  ];
  return result.isEmpty ? null : result;
}

fai.Tool _toGeminiTool(ToolDefinition tool) => fai.Tool.functionDeclarations([
  _JsonSchemaFunctionDeclaration(
    tool.name,
    tool.description,
    _constrainsInput(tool.inputSchema) ? tool.inputSchema : null,
  ),
]);

/// Whether [schema] says anything about the input. A schema with only
/// `$schema` or `description`, such as the one `dynamicSchema()` produces,
/// accepts any value, and Gemini expects `parametersJsonSchema` to describe
/// an object, so it is left out, as the JS and Go plugins do.
bool _constrainsInput(Map<String, dynamic>? schema) =>
    schema != null &&
    schema.keys.any((k) => k != r'$schema' && k != 'description');

/// A function declaration that sends the tool's input schema to Gemini
/// unchanged as `parametersJsonSchema`, as `genkit_google_genai` does.
///
/// `firebase_ai` builds `parametersJsonSchema` only from its typed
/// [fai.JSONSchema], which cannot carry `additionalProperties`, `pattern`,
/// `oneOf` or a top-level `$defs`, so converting would lose them.
final class _JsonSchemaFunctionDeclaration extends fai.FunctionDeclaration {
  _JsonSchemaFunctionDeclaration(
    super.name,
    super.description,
    this.parametersJsonSchema,
  ) : super(parameters: const {});

  final Map<String, dynamic>? parametersJsonSchema;

  @override
  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'parametersJsonSchema': ?parametersJsonSchema,
  };
}

/// Maps Genkit's request onto Firebase AI's generation config.
///
/// [outputSchema] is sent verbatim as `responseJsonSchema` only on a
/// constrained JSON request, matching `genkit_google_genai`. A caller asking
/// for a schema without constraint wants it enforced by nothing rather than by
/// Gemini specifically - core does not inject textual instructions for it
/// either (`jsonFormatter` sets `defaultInstructions: false`), so honouring
/// that choice here means the model sees no description of the shape at all,
/// native or textual, unless the caller supplied their own. Gemini only
/// honours a response schema alongside an `application/json` response mime
/// type, so the JSON-mode half of the condition is the provider's rule, not a
/// preference.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] when a field
/// has the wrong type or an unknown value.
fai.GenerationConfig toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode, {
  bool constrained = false,
}) {
  try {
    return _toGeminiSettings(
      options,
      outputSchema,
      isJsonMode,
      constrained: constrained,
    );
  } on GenkitException {
    rethrow;
  } catch (e) {
    throw GenkitException(
      'Invalid model config: $e',
      status: StatusCode.invalidArgument,
    );
  }
}

fai.GenerationConfig _toGeminiSettings(
  GeminiOptions options,
  Map<String, dynamic>? outputSchema,
  bool isJsonMode, {
  bool constrained = false,
}) {
  final responseJsonSchema = constrained && isJsonMode && outputSchema != null
      ? outputSchema
      : options.responseJsonSchema;
  return fai.GenerationConfig(
    candidateCount: options.candidateCount,
    stopSequences: options.stopSequences ?? [],
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    responseMimeType: isJsonMode
        ? 'application/json'
        : (options.responseMimeType?.isEmpty ?? true
              ? null
              : options.responseMimeType),
    responseJsonSchema: responseJsonSchema,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
    responseModalities: options.responseModalities
        ?.map((e) => fai.ResponseModalities.values.byName(e.toLowerCase()))
        .toList(),
    thinkingConfig: options.thinkingConfig == null
        ? null
        : _toGeminiThinkingConfig(options.thinkingConfig!),
    speechConfig: toGeminiSpeechConfig(options.speechConfig),
    imageConfig: _toGeminiImageConfig(options.imageConfig),
    mediaResolution: _toMediaResolution(options.mediaResolution),
  );
}

/// Converts [config] to a `firebase_ai` speech config.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] when both a
/// voice and multiple speakers are set, there are not exactly two speakers, or
/// a speaker lacks a name or voice.
fai.SpeechConfig? toGeminiSpeechConfig(SpeechConfig? config) {
  if (config == null) return null;
  final voiceName = config.voiceConfig?.prebuiltVoiceConfig?.voiceName;
  final multi = config.multiSpeakerVoiceConfig;
  if (multi == null) {
    return fai.SpeechConfig(
      voiceName: voiceName,
      languageCode: config.languageCode,
    );
  }
  if (config.voiceConfig != null) {
    throw GenkitException(
      'speechConfig cannot set both voiceConfig and multiSpeakerVoiceConfig.',
      status: StatusCode.invalidArgument,
    );
  }
  final speakers = multi.speakerVoiceConfigs;
  // Gemini TTS takes exactly two speakers.
  if (speakers == null || speakers.length != 2) {
    throw GenkitException(
      'multiSpeakerVoiceConfig needs exactly two speakerVoiceConfigs entries, '
      'not ${speakers?.length ?? 0}.',
      status: StatusCode.invalidArgument,
    );
  }
  return fai.SpeechConfig.multiSpeaker(
    multiSpeakerVoiceConfig: fai.MultiSpeakerVoiceConfig(
      speakerVoiceConfigs: [
        for (final speaker in speakers)
          switch (speaker) {
            SpeakerVoiceConfig(
              speaker: final name?,
              voiceConfig: VoiceConfig(
                prebuiltVoiceConfig: PrebuiltVoiceConfig(
                  voiceName: final voice?,
                ),
              ),
            ) =>
              fai.SpeakerVoiceConfig(speaker: name, voiceName: voice),
            _ => throw GenkitException(
              'Each speakerVoiceConfigs entry needs a speaker and a '
              'voiceConfig.prebuiltVoiceConfig.voiceName.',
              status: StatusCode.invalidArgument,
            ),
          },
      ],
    ),
    languageCode: config.languageCode,
  );
}

fai.ImageConfig? _toGeminiImageConfig(GeminiImageConfig? config) {
  if (config == null) return null;
  return fai.ImageConfig(
    aspectRatio: _byWireName(
      'imageConfig.aspectRatio',
      config.aspectRatio,
      fai.ImageAspectRatio.values,
      (r) => r.toJson(),
    ),
    imageSize: _byWireName(
      'imageConfig.imageSize',
      config.imageSize,
      fai.ImageSize.values,
      (s) => s.toJson(),
    ),
  );
}

/// The [fai.MediaResolution] named [value]. `ultraHigh` is only valid on a
/// part ([perPart]); `firebase_ai` asserts against it for a whole request.
fai.MediaResolution? _toMediaResolution(String? value, {bool perPart = false}) {
  if (!perPart && value == fai.MediaResolution.ultraHigh.toJson()) {
    throw GenkitException(
      '$value is only supported on a media part, in '
      'metadata.mediaResolution.',
      status: StatusCode.invalidArgument,
    );
  }
  return _byWireName(
    perPart ? 'metadata.mediaResolution' : 'mediaResolution',
    value,
    fai.MediaResolution.values.where(
      (r) => r != fai.MediaResolution.unspecified,
    ),
    (r) => r.toJson(),
  );
}

/// The value of [values] whose wire name is [value], or null when [value] is.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] for an unknown
/// [value] in [field].
T? _byWireName<T>(
  String field,
  String? value,
  Iterable<T> values,
  String Function(T) wireName,
) {
  if (value == null) return null;
  for (final v in values) {
    if (wireName(v) == value) return v;
  }
  throw GenkitException(
    'Unknown $field "$value"; expected one of '
    '${values.map(wireName).join(', ')}.',
    status: StatusCode.invalidArgument,
  );
}

fai.ThinkingConfig _toGeminiThinkingConfig(ThinkingConfig config) {
  final includeThoughts = config.includeThoughts ?? false;
  final level = config.thinkingLevel;
  if (level == null) {
    return fai.ThinkingConfig.withThinkingBudget(
      config.thinkingBudget,
      includeThoughts: includeThoughts,
    );
  }
  if (config.thinkingBudget != null) {
    throw GenkitException(
      'thinkingConfig cannot set both thinkingBudget and thinkingLevel.',
      status: StatusCode.invalidArgument,
    );
  }
  final thinkingLevel = fai.ThinkingLevel.values
      .where((l) => l.toJson() == level)
      .firstOrNull;
  if (thinkingLevel == null) {
    throw GenkitException(
      'Unknown thinkingConfig.thinkingLevel "$level"; expected one of '
      '${fai.ThinkingLevel.values.map((l) => l.toJson()).join(', ')}.',
      status: StatusCode.invalidArgument,
    );
  }
  return fai.ThinkingConfig.withThinkingLevel(
    thinkingLevel,
    includeThoughts: includeThoughts,
  );
}

/// Builds the Firebase AI `toolConfig` from the plugin-specific
/// [functionCallingConfig] or, when that is absent, the portable Genkit
/// [toolChoice] (`auto` / `required` / `none`). The plugin config wins because
/// it can also restrict the allowed function names. Unknown [toolChoice]
/// values are ignored.
///
/// [toolChoice] only applies when [hasFunctionTools] is true, i.e. the request
/// declares Genkit tools. Code execution and the grounding tools don't count: a
/// function-calling mode with no function declarations is contradictory
/// (`required` would demand a call to nothing).
///
/// [retrievalConfig] goes next to the function calling config. Throws a
/// [GenkitException] with [StatusCode.invalidArgument] when its `latLng` has
/// only one coordinate.
fai.ToolConfig? toGeminiToolConfig(
  FunctionCallingConfig? functionCallingConfig, {
  ToolChoice? toolChoice,
  bool hasFunctionTools = false,
  GeminiRetrievalConfig? retrievalConfig,
}) {
  final calling = _toFunctionCallingConfig(
    functionCallingConfig,
    toolChoice: toolChoice,
    hasFunctionTools: hasFunctionTools,
  );
  final retrieval = _toRetrievalConfig(retrievalConfig);
  if (calling == null && retrieval == null) return null;
  return fai.ToolConfig(
    functionCallingConfig: calling,
    retrievalConfig: retrieval,
  );
}

fai.FunctionCallingConfig? _toFunctionCallingConfig(
  FunctionCallingConfig? functionCallingConfig, {
  ToolChoice? toolChoice,
  bool hasFunctionTools = false,
}) {
  if (functionCallingConfig == null) {
    if (!hasFunctionTools) return null;
    return switch (toolChoice?.value) {
      'auto' => fai.FunctionCallingConfig.auto(),
      'required' => fai.FunctionCallingConfig.any({}),
      'none' => fai.FunctionCallingConfig.none(),
      _ => null,
    };
  }
  return switch (functionCallingConfig.mode?.toUpperCase()) {
    'ANY' => fai.FunctionCallingConfig.any(
      functionCallingConfig.allowedFunctionNames?.toSet() ?? {},
    ),
    'NONE' => fai.FunctionCallingConfig.none(),
    _ => fai.FunctionCallingConfig.auto(),
  };
}

/// Runs [read], reporting a wrongly typed config field, which fails in the
/// generated getter, as [StatusCode.invalidArgument].
T readConfig<T>(T Function() read) {
  try {
    return read();
  } on GenkitException {
    rethrow;
  } catch (e) {
    throw GenkitException(
      'Invalid model config: $e',
      status: StatusCode.invalidArgument,
    );
  }
}

/// Throws a [GenkitException] with [StatusCode.invalidArgument] when `latLng`
/// is missing a coordinate.
fai.RetrievalConfig? _toRetrievalConfig(GeminiRetrievalConfig? config) {
  if (config == null) return null;
  final latLng = switch (config.latLng) {
    null => null,
    GeminiLatLng(:final latitude?, :final longitude?) => fai.LatLng(
      latitude: latitude,
      longitude: longitude,
    ),
    _ => throw GenkitException(
      'retrievalConfig.latLng needs both latitude and longitude.',
      status: StatusCode.invalidArgument,
    ),
  };
  return fai.RetrievalConfig(latLng: latLng, languageCode: config.languageCode);
}

/// Converts Firebase AI [fai.UsageMetadata] into Genkit [GenerationUsage].
GenerationUsage? extractUsage(fai.UsageMetadata? metadata) {
  if (metadata == null) return null;
  return GenerationUsage(
    // A count the API leaves out stays null, not 0, as in genkit_google_genai.
    inputTokens: metadata.promptTokenCount,
    outputTokens: metadata.candidatesTokenCount,
    totalTokens: metadata.totalTokenCount,
    thoughtsTokens: metadata.thoughtsTokenCount,
    cachedContentTokens: metadata.cachedContentTokenCount,
    custom: switch (metadata.toolUsePromptTokenCount) {
      final count? => {'toolUsePromptTokenCount': count},
      null => null,
    },
  );
}

GenkitException noCandidatesException(fai.PromptFeedback? feedback) {
  if (feedback case fai.PromptFeedback(
    :final blockReason?,
    blockReasonMessage: final detail,
  )) {
    return GenkitException(
      'Prompt was blocked (${blockReason.toJson()})'
      '${detail == null || detail.isEmpty ? '.' : ': $detail'}',
      status: StatusCode.failedPrecondition,
    );
  }
  return GenkitException('Model returned no candidates.');
}

/// Rebuilds the wire JSON of [response] from the fields `firebase_ai` parses.
///
/// Citation metadata is left out because the SDK gives it no serialization.
Map<String, dynamic> rawResponse(fai.GenerateContentResponse response) => {
  'candidates': [
    for (final c in response.candidates)
      {
        if (c.content.parts.isNotEmpty) 'content': c.content.toJson(),
        'finishReason': ?c.finishReason?.toJson(),
        'finishMessage': ?c.finishMessage,
        'safetyRatings': ?c.safetyRatings?.map(_rawSafetyRating).toList(),
        'groundingMetadata': ?groundingMetadataJson(c),
        'urlContextMetadata': ?urlContextMetadataJson(c),
      },
  ],
  if (response.promptFeedback case final feedback?)
    'promptFeedback': {
      'blockReason': ?feedback.blockReason?.toJson(),
      'blockReasonMessage': ?feedback.blockReasonMessage,
      'safetyRatings': feedback.safetyRatings.map(_rawSafetyRating).toList(),
    },
  if (response.usageMetadata case final usage?)
    'usageMetadata': {
      'promptTokenCount': ?usage.promptTokenCount,
      'candidatesTokenCount': ?usage.candidatesTokenCount,
      'totalTokenCount': ?usage.totalTokenCount,
      'thoughtsTokenCount': ?usage.thoughtsTokenCount,
      'toolUsePromptTokenCount': ?usage.toolUsePromptTokenCount,
      'cachedContentTokenCount': ?usage.cachedContentTokenCount,
      for (final (key, details) in [
        ('promptTokensDetails', usage.promptTokensDetails),
        ('candidatesTokensDetails', usage.candidatesTokensDetails),
        ('toolUsePromptTokensDetails', usage.toolUsePromptTokensDetails),
        ('cacheTokensDetails', usage.cacheTokensDetails),
      ])
        if (details != null)
          key: [
            for (final d in details)
              {'modality': d.modality.toJson(), 'tokenCount': d.tokenCount},
          ],
    },
};

Map<String, dynamic> _rawSafetyRating(fai.SafetyRating rating) => {
  'category': rating.category.toJson(),
  'probability': rating.probability.toJson(),
  'probabilityScore': ?rating.probabilityScore,
  'blocked': ?rating.isBlocked,
  // HarmSeverity.toJson drops the HARM_SEVERITY_ prefix the wire uses.
  'severity': ?switch (rating.severity?.toJson()) {
    'UNKNOWN' => 'UNKNOWN',
    final String severity => 'HARM_SEVERITY_$severity',
    null => null,
  },
  'severityScore': ?rating.severityScore,
};
