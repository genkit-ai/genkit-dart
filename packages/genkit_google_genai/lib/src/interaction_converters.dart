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

// Converters between Genkit types and the Gemini Interactions API.
//
// Mirrors js/plugins/google-genai/src/common/interaction-converters.ts (as on
// the JS branch `if-typeUpdates`, Oct 26 2026): same function names, same
// order. Keep the two in step: change JS first, then translate. The JS
// helpers these use from common/utils.ts (applyInteractionStepEvent, the
// error code mapping, cleanSchema, ...) are at the end of this file.
// Functions that are private in JS are private here too.
//
// Also here, from common/utils.ts: warnDroppedConfigField, appendToWavData,
// stripLeadingId3Tags, and InteractionStreamAssembler (JS
// `getInteractionResponsePromise`, which assembles the final interaction of
// a stream).
//
// Not ported yet (translate from the JS file when the feature arrives):
// - fromInteraction (to an Operation): needs background models.
// - toInteractionRole: unused in JS.
//
// How JS maps to Dart here:
// - JS checks part shapes with Zod schemas (e.g. `GoogleSearchCallSchema`);
//   here the `_require*` helpers do the same checks and throw a
//   GenkitException (INVALID_ARGUMENT) when a required field is missing.
// - JS `console.warn` / `logger.warn` are `logger.warning`.
// - JS returns plain objects and leaves `undefined` fields out; Dart builds
//   Genkit parts with their constructors and leaves null fields out.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:genkit/plugin.dart';
import 'package:meta/meta.dart';

import 'common_plugin.dart' show logger;
import 'interaction_types.dart';
import 'model.dart';

/// Ensures that all tool requests and responses in a list of messages have
/// unique reference IDs.
///
/// This performs two passes:
/// 1. Assigns generated IDs to tool requests that lack a `ref`.
/// 2. Assigns matching IDs to tool responses that lack a `ref`, assuming they
///    correspond sequentially to the requests. A response with no matching
///    request gets an orphaned ID.
///
/// Returns a deep copy of the messages with tool IDs ensured.
List<Message> ensureToolIds(List<Message> messages) {
  final generatedIds = <String>[];
  var nextIdCounter = 0;

  // Deep copy to avoid mutating the original request messages.
  final newMessages = [
    for (final m in messages)
      (jsonDecode(jsonEncode(m.toJson())) as Map).cast<String, dynamic>(),
  ];

  // First pass: find tool requests without a ref.
  for (final message in newMessages) {
    for (final part in (message['content'] as List).cast<Map>()) {
      final request = part['toolRequest'];
      if (request is Map && _isEmpty(request['ref'])) {
        final newId = 'genkit-auto-id-${nextIdCounter++}';
        request['ref'] = newId;
        generatedIds.add(newId);
      }
    }
  }

  // Second pass: find tool responses without a ref and assign from the
  // queue. This assumes responses are in the same order as requests.
  for (final message in newMessages) {
    for (final part in (message['content'] as List).cast<Map>()) {
      final response = part['toolResponse'];
      if (response is Map && _isEmpty(response['ref'])) {
        // No matching request found (or the queue is empty): generate a
        // unique one to avoid an empty string rejection.
        response['ref'] = generatedIds.isNotEmpty
            ? generatedIds.removeAt(0)
            : 'genkit-orphan-id-${nextIdCounter++}';
      }
    }
  }

  return newMessages.map(Message.fromJson).toList();
}

/// Converts a Genkit [ToolDefinition] to an [InteractionTool].
///
/// Maps the name, description, and input schema (cleaned) to the interaction
/// tool structure.
InteractionTool toInteractionTool(ToolDefinition tool) {
  final schema = tool.inputSchema;
  return InteractionFunctionTool(
    name: tool.name,
    description: tool.description,
    parameters: schema == null ? null : cleanSchema(schema),
  );
}

/// Converts a built-in tool from the `tools` config (e.g.
/// `{'googleSearch': {}}`, `{'urlContext': true}`) to an [InteractionTool].
///
/// Known keys map to their tool type, with the tool's settings (a map, or
/// `true` for none) in snake_case. Any other map that names its own `type`
/// is passed through in snake_case.
InteractionTool toInteractionConfigTool(Object? toolRaw) {
  if (toolRaw is! Map) {
    throw ArgumentError(
      'Invalid tool configuration: Expected an object, got '
      '${toolRaw.runtimeType}',
    );
  }
  final tool = toolRaw;

  // A tool whose settings are passed through in snake_case.
  InteractionTool withSettings(String name, String type, Object? config) {
    if (config == true || config == null) {
      return InteractionTool.fromJson({'type': type});
    }
    if (config is! Map) {
      throw ArgumentError(
        'Invalid configuration for $name tool: Expected object or true, got '
        '${config.runtimeType}',
      );
    }
    return InteractionTool.fromJson({'type': type, ...toSnakeCaseObj(config)});
  }

  if (tool.containsKey('googleSearch') || tool.containsKey('google_search')) {
    return toInteractionGoogleSearch(
      _or(tool['googleSearch'], tool['google_search']),
    );
  }
  if (tool.containsKey('codeExecution') || tool.containsKey('code_execution')) {
    return withSettings(
      'codeExecution',
      'code_execution',
      _or(tool['codeExecution'], tool['code_execution']),
    );
  }
  if (tool.containsKey('fileSearch') || tool.containsKey('file_search')) {
    final config = _or(tool['fileSearch'], tool['file_search']);
    if (config == true || config == null) {
      return InteractionFileSearchTool();
    }
    if (config is! Map) {
      throw ArgumentError(
        'Invalid configuration for fileSearch tool: Expected object, got '
        '${config.runtimeType}',
      );
    }
    final fileSearchStoreNames = _or(
      config['fileSearchStoreNames'],
      config['file_search_store_names'],
    );
    final restFileSearch = {...config}
      ..remove('fileSearchStoreNames')
      ..remove('file_search_store_names');

    if (fileSearchStoreNames != null &&
        (fileSearchStoreNames is! List ||
            !fileSearchStoreNames.every((n) => n is String))) {
      throw ArgumentError('fileSearchStoreNames must be an array of strings.');
    }
    return InteractionTool.fromJson({
      'type': 'file_search',
      'file_search_store_names': ?(fileSearchStoreNames as List?)
          ?.cast<String>(),
      ...toSnakeCaseObj(restFileSearch),
    });
  }
  if (tool.containsKey('urlContext')) {
    return withSettings('urlContext', 'url_context', tool['urlContext']);
  }
  if (tool.containsKey('googleMaps')) {
    return withSettings('googleMaps', 'google_maps', tool['googleMaps']);
  }
  if (tool.containsKey('computerUse')) {
    return withSettings('computerUse', 'computer_use', tool['computerUse']);
  }
  if (tool.containsKey('retrieval')) {
    return withSettings('retrieval', 'retrieval', tool['retrieval']);
  }
  if (tool.containsKey('mcpServer')) {
    final result = withSettings('mcpServer', 'mcp_server', tool['mcpServer']);
    final allowedTools = result.json['allowed_tools'];
    if (allowedTools is List &&
        allowedTools.isNotEmpty &&
        allowedTools.first is String) {
      result.json['allowed_tools'] = [
        {'tools': allowedTools},
      ];
    }
    return result;
  }

  // Pass through any other tool that names its own `type`, in snake_case.
  final rest = toSnakeCaseObj(tool);
  final type = rest.remove('type');
  if (type is! String) {
    throw ArgumentError(
      'Unsupported tool configuration: ${jsonEncode(tool)}. '
      'Use a built-in tool key (e.g. googleSearch, codeExecution) or set '
      '`type`.',
    );
  }
  return InteractionDynamicTool(type, rest);
}

/// Copies a `retrievalConfig.latLng` user location onto the Interactions
/// `google_maps` tools in [tools], which take `latitude`/`longitude`
/// directly (there is no retrieval config on the Interactions path). A
/// location already set on a tool is kept.
///
/// Returns whether there was a `google_maps` tool to apply the location to.
bool applyLatLngToGoogleMapsTools(
  List<InteractionTool> tools,
  GeminiLatLng latLng,
) {
  var found = false;
  for (var i = 0; i < tools.length; i++) {
    final tool = tools[i];
    if (tool.type != 'google_maps') continue;
    found = true;
    if (tool.json.containsKey('latitude') ||
        tool.json.containsKey('longitude')) {
      continue;
    }
    tools[i] = InteractionTool.fromJson({
      ...tool.json,
      'latitude': ?latLng.latitude,
      'longitude': ?latLng.longitude,
    });
  }
  return found;
}

/// Picks the messages to send to the Interactions API and the interaction to
/// continue, if any.
///
/// Without [store], the server keeps no history, so every message is sent.
/// With [store], the last model message's `metadata.interactionId` is
/// continued and only the newer messages are sent. An explicit
/// [previousInteractionIdFromConfig] (which requires [store]) overrides the
/// metadata; messages up to the last model message are still left out.
///
/// Throws a GenkitException (INVALID_ARGUMENT) if
/// [previousInteractionIdFromConfig] is set without [store].
({List<Message> messages, String? previousInteractionId})
selectInteractionInput(
  List<Message> messages,
  bool store, [
  String? previousInteractionIdFromConfig,
]) {
  if (!_isEmpty(previousInteractionIdFromConfig) && !store) {
    throw GenkitException(
      'store must be true when previousInteractionId is set.',
      status: StatusCode.invalidArgument,
    );
  }

  if (!_isEmpty(previousInteractionIdFromConfig)) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == Role.model) {
        return (
          messages: messages.sublist(i + 1),
          previousInteractionId: previousInteractionIdFromConfig,
        );
      }
    }
    return (
      messages: messages,
      previousInteractionId: previousInteractionIdFromConfig,
    );
  }

  if (store) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final prevId = messages[i].metadata?['interactionId'];
      if (messages[i].role == Role.model && prevId is String && prevId != '') {
        return (
          messages: messages.sublist(i + 1),
          previousInteractionId: prevId,
        );
      }
    }
  }
  return (messages: messages, previousInteractionId: null);
}

/// Converts `functionCallingConfig` (or, without it, the request's
/// `toolChoice`) to the Interactions `generation_config.tool_choice`.
/// Returns null when neither sets anything.
InteractionToolChoiceConfig? toInteractionToolChoice(
  GeminiFunctionCallingConfig? functionCallingConfig, [
  String? toolChoice,
]) {
  if (functionCallingConfig != null) {
    final mode = functionCallingConfig.mode?.toLowerCase();
    final validMode = !_isEmpty(mode) && mode != 'mode_unspecified'
        ? mode
        : null;
    final names = functionCallingConfig.allowedFunctionNames;
    if (validMode == null && (names == null || names.isEmpty)) {
      return null;
    }
    return InteractionToolChoiceConfig(
      allowedTools: InteractionAllowedTools(mode: validMode, tools: names),
    );
  }
  if (!_isEmpty(toolChoice)) {
    return InteractionToolChoiceConfig(
      allowedTools: InteractionAllowedTools(
        mode: toolChoice == 'required' ? 'any' : toolChoice,
      ),
    );
  }
  return null;
}

/// Converts a `googleSearch` option (`true`, or a map) to an Interactions
/// Google Search tool.
///
/// `searchTypes` (a list of names, or a map of name to enabled) is converted
/// to `search_types` in snake_case; unknown types are passed through. Other
/// fields are passed through in snake_case.
InteractionGoogleSearchTool toInteractionGoogleSearch(Object? gs) {
  final result = InteractionGoogleSearchTool();

  if (gs == true || gs == null) {
    return result;
  }

  if (gs is! Map) {
    throw ArgumentError(
      'Invalid configuration for googleSearch tool: Expected object or true, '
      'got ${gs.runtimeType}',
    );
  }

  final searchTypesObj = gs['searchTypes'] ?? gs['search_types'];
  if (searchTypesObj != null) {
    final searchTypes = <String>{};

    String toSearchType(String type) => switch (type) {
      'webSearch' || 'web_search' => 'web_search',
      'imageSearch' || 'image_search' => 'image_search',
      'enterpriseWebSearch' ||
      'enterprise_web_search' => 'enterprise_web_search',
      // Passthrough for any unknown names.
      _ => camelToSnakeCase(type),
    };

    if (searchTypesObj is List) {
      for (final type in searchTypesObj) {
        if (type is! String) {
          throw ArgumentError(
            'Invalid search type: Expected string, got ${type.runtimeType}',
          );
        }
        searchTypes.add(toSearchType(type));
      }
    } else if (searchTypesObj is Map) {
      for (final MapEntry(:key, :value) in searchTypesObj.entries) {
        if (_isTruthy(value)) searchTypes.add(toSearchType(key as String));
      }
    } else {
      throw ArgumentError(
        'Invalid searchTypes configuration: Expected array or object, got '
        '${searchTypesObj.runtimeType}',
      );
    }

    if (searchTypes.isNotEmpty) {
      result.json['search_types'] = searchTypes.toList();
    }
  }

  // Handle any other properties on gs (passthrough).
  final restConfig = {...gs}
    ..remove('searchTypes')
    ..remove('search_types');
  result.json.addAll(toSnakeCaseObj(restConfig));

  return result;
}

/// Converts the `audioFormat` config (`{mimeType, sampleRate}`) into an
/// Interactions audio `response_format` entry. Returns null if it isn't
/// set, so the server defaults apply.
Map<String, Object?>? toInteractionAudioResponseFormat(Object? audioFormat) {
  if (audioFormat is! Map) return null;
  final mimeType = audioFormat['mimeType'];
  final sampleRate = audioFormat['sampleRate'];
  final rest = {...audioFormat}
    ..remove('mimeType')
    ..remove('sampleRate');
  return {
    'type': 'audio',
    ...toSnakeCaseObj(rest),
    if (mimeType is String) 'mime_type': mimeType,
    if (sampleRate is num) 'sample_rate': sampleRate,
  };
}

/// Converts the `videoFormat` config (`{aspectRatio, resolution}`) into an
/// Interactions video `response_format` entry. Returns null if it isn't
/// set, so the server defaults apply (16:9, 720p).
Map<String, Object?>? toInteractionVideoResponseFormat(Object? videoFormat) {
  if (videoFormat is! Map) return null;
  return {'type': 'video', ...toSnakeCaseObj(videoFormat)};
}

/// Builds the Interactions `response_format`: one entry per output type
/// (`text`, `image`, `audio`, `video`), each with its settings. This
/// replaces the deprecated `response_modalities` and
/// `generation_config.image_config`.
///
/// - Each of [modalities] (e.g. `['TEXT', 'IMAGE']`: the config's
///   `responseModalities`, or the model's default) gets an entry.
/// - [imageConfig] (`{aspectRatio, imageSize}`), [audioFormat] and
///   [videoFormat] go on the image, audio and video entries (adding the
///   entry if needed).
/// - [json] output goes on the text entry (adding it if needed):
///   `mime_type: 'application/json'`, plus `schema` when given.
///
/// Returns a single entry when there's one, a list when there are more, and
/// null when nothing is set (the server's defaults apply).
Object? toInteractionResponseFormat({
  List<String>? modalities,
  Object? imageConfig,
  Object? audioFormat,
  Object? videoFormat,
  ({Object? schema})? json,
}) {
  // Insertion-ordered, like the JS Map.
  final entries = <String, Map<String, Object?>>{};
  Map<String, Object?> entry(String type) =>
      entries.putIfAbsent(type, () => {'type': type});

  for (final modality in modalities ?? const <String>[]) {
    entry(modality.toLowerCase());
  }
  if (imageConfig is Map) {
    entry('image').addAll(toSnakeCaseObj(imageConfig));
  }
  final audio = toInteractionAudioResponseFormat(audioFormat);
  if (audio != null) entry('audio').addAll(audio);
  final video = toInteractionVideoResponseFormat(videoFormat);
  if (video != null) entry('video').addAll(video);
  if (json != null) {
    entry(
      'text',
    ).addAll({'mime_type': 'application/json', 'schema': ?json.schema});
  }

  final result = entries.values.toList();
  if (result.isEmpty) return null;
  return result.length == 1 ? result.single : result;
}

/// Converts generateContent-style safety settings to the Interactions API
/// shape: `type` without the `HARM_CATEGORY_` prefix, and lower-case values
/// (`HARM_CATEGORY_HATE_SPEECH` / `BLOCK_LOW_AND_ABOVE` -> `hate_speech` /
/// `block_low_and_above`). The server rejects the upper-case values with a
/// 400. `method` (`SEVERITY` / `PROBABILITY`) is lower-cased too.
/// `HARM_CATEGORY_UNSPECIFIED` has no equivalent and is left out. Other
/// fields are passed through in snake_case.
///
/// Returns null when [settings] is null or nothing is left.
List<InteractionSafetySetting>? toInteractionSafetySettings(
  List<GeminiSafetySettings>? settings,
) {
  if (settings == null) return null;
  final result = [
    for (final setting in settings)
      if (setting.category != 'HARM_CATEGORY_UNSPECIFIED')
        _toInteractionSafetySetting(setting.toJson()),
  ];
  return result.isEmpty ? null : result;
}

InteractionSafetySetting _toInteractionSafetySetting(
  Map<String, dynamic> setting,
) {
  final rest = {...setting}
    ..remove('category')
    ..remove('threshold')
    ..remove('method');
  final method = setting['method'];
  return InteractionSafetySetting.fromJson({
    ...toSnakeCaseObj(rest),
    'type': (setting['category'] as String? ?? '')
        .replaceFirst(RegExp('^HARM_CATEGORY_'), '')
        .toLowerCase(),
    'threshold': (setting['threshold'] as String? ?? '').toLowerCase(),
    if (method is String) 'method': method.toLowerCase(),
  });
}

/// Converts a generateContent-style `speechConfig` to the Interactions API
/// `speech_config`.
///
/// - `voiceConfig.prebuiltVoiceConfig.voiceName` becomes `[{voice}]`.
/// - `multiSpeakerVoiceConfig.speakerVoiceConfigs[]` becomes
///   `{speakers: [{speaker, voice}, ...]}`. Each text part must then name its
///   speaker via `metadata.speechMetadata.speaker`.
/// - A top-level `languageCode` is applied to every entry as `language`.
///
/// Returns null if no voice or language is set. The result is a list of
/// [SpeechConfig] maps or `{speakers: [...]}` (see
/// [ModelGenerationConfig.speechConfig]).
Object? toInteractionSpeechConfig(Object? speechConfig) {
  if (speechConfig is! Map) {
    return null;
  }

  final language = speechConfig['languageCode'] is String
      ? speechConfig['languageCode'] as String
      : null;
  String? voiceNameOf(Object? voiceConfig) {
    if (voiceConfig is! Map) return null;
    final prebuilt = voiceConfig['prebuiltVoiceConfig'];
    if (prebuilt is! Map) return null;
    final voiceName = prebuilt['voiceName'];
    return voiceName is String ? voiceName : null;
  }

  SpeechConfig entry(String? voice, [String? speaker]) => SpeechConfig(
    voice: _isEmpty(voice) ? null : voice,
    language: _isEmpty(language) ? null : language,
    speaker: _isEmpty(speaker) ? null : speaker,
  );

  final multi = speechConfig['multiSpeakerVoiceConfig'];
  if (multi is Map && multi['speakerVoiceConfigs'] is List) {
    return {
      'speakers': [
        for (final s in multi['speakerVoiceConfigs'] as List)
          if (s is Map)
            entry(
              voiceNameOf(s['voiceConfig']),
              s['speaker'] is String ? s['speaker'] as String : null,
            ).json,
      ],
    };
  }

  final voice = voiceNameOf(speechConfig['voiceConfig']);
  if (!_isEmpty(voice) || !_isEmpty(language)) {
    return [entry(voice).json];
  }
  return null;
}

/// Converts the remaining request config into the Interactions
/// `generation_config`.
///
/// The API rejects unknown `generation_config` fields with a 400, so config
/// fields this plugin defines are mapped explicitly:
///  - `speechConfig` is converted to `speech_config`;
///  - `thinkingConfig.thinkingLevel` / `includeThoughts` become
///    `thinking_level` / `thinking_summaries`. There is no
///    `thinking_config`, so other thinking fields (e.g. `thinkingBudget`) are
///    dropped;
///  - `contextCache` (not implemented by this plugin) is dropped;
///  - `imageConfig`, `audioFormat` and `videoFormat` are left out: they're
///    sent as `response_format` entries (see toInteractionResponseFormat).
/// Everything else, including keys the user passes through that aren't in
/// the schema, is forwarded in snake_case.
///
/// [config] is the request config, without fields handled elsewhere.
/// [onDropped] is called with the name of each config field that was dropped.
ModelGenerationConfig toInteractionGenerationConfig(
  Map<String, Object?> config, [
  void Function(String field)? onDropped,
]) {
  final rest = {...config}
    ..remove('speechConfig')
    ..remove('thinkingConfig')
    ..remove('thinking_config')
    ..remove('contextCache')
    ..remove('context_cache')
    // Sent as `response_format` entries (see toInteractionResponseFormat).
    ..remove('audioFormat')
    ..remove('videoFormat')
    ..remove('imageConfig')
    ..remove('image_config');
  final result = ModelGenerationConfig.fromJson(toSnakeCaseObj(rest));

  final interactionSpeechConfig = toInteractionSpeechConfig(
    config['speechConfig'],
  );
  if (interactionSpeechConfig != null) {
    result.speechConfig = interactionSpeechConfig;
  }

  final thinking = config['thinkingConfig'] ?? config['thinking_config'];
  if (thinking is Map) {
    for (final MapEntry(:key, :value) in thinking.entries) {
      if (key == 'thinkingLevel' || key == 'thinking_level') {
        result.json['thinking_level'] = value is String
            ? value.toLowerCase()
            : value;
      } else if (key == 'includeThoughts' || key == 'include_thoughts') {
        result.json['thinking_summaries'] = value is bool
            ? (value ? 'auto' : 'none')
            : value;
      } else {
        onDropped?.call('thinkingConfig.$key');
      }
    }
  }

  if (config['contextCache'] != null || config['context_cache'] != null) {
    onDropped?.call('contextCache');
  }

  return result;
}

/// Converts a Genkit [Part] to an Interactions [Content] block.
///
/// Handles text and media parts. Other parts are left out (with a warning).
Content? toInteractionContent(Part part) {
  if (part.isText) {
    final speechMetadata = _toSpeechMetadataAnnotation(
      part.metadata?['speechMetadata'],
    );
    return TextContent(
      text: part.text,
      annotations: speechMetadata == null ? null : [speechMetadata],
    );
  }
  if (part.isMedia) {
    return _toInteractionMedia(part);
  }
  logger.warning(
    'Unsupported part type for Interaction input: ${jsonEncode(part.toJson())}',
  );
  return null;
}

/// Converts a text part's `metadata.speechMetadata` (`{speaker?, style?}`)
/// into an Interactions `speech_metadata` annotation, used by TTS models to
/// assign each turn to a speaker and set its delivery style.
SpeechAnnotation? _toSpeechMetadataAnnotation(Object? speechMetadata) {
  if (speechMetadata is! Map) {
    return null;
  }
  final speaker = speechMetadata['speaker'] is String
      ? speechMetadata['speaker'] as String
      : null;
  final style = speechMetadata['style'] is String
      ? speechMetadata['style'] as String
      : null;
  if (_isEmpty(speaker) && _isEmpty(style)) {
    return null;
  }
  return SpeechAnnotation(
    speaker: _isEmpty(speaker) ? null : speaker,
    style: _isEmpty(style) ? null : style,
  );
}

/// Reports whether a URL points at a YouTube video.
bool _isYouTubeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.replaceFirst(RegExp(r'^(www\.|m\.)'), '');
  return host == 'youtube.com' || host == 'youtu.be';
}

/// The `processing` mode (`static` or `agentic`) for a video part, from the
/// part's `metadata.processing`.
VideoProcessing? _videoProcessingOf(Part part) {
  final processing = part.metadata?['processing'];
  return processing is String ? VideoProcessing(processing) : null;
}

Content _toInteractionMedia(Part part) {
  final media = part.media!;
  final url = media.url;
  final contentType = _isEmpty(media.contentType)
      ? extractMimeType(url)
      : media.contentType!;

  if (contentType.isEmpty) {
    if (url.startsWith('data:')) {
      throw ArgumentError('Media part missing contentType');
    }
    // A URI whose type can't be determined (e.g. a YouTube link or a Files
    // API URI). The server works out the type itself, so send it without a
    // mime_type, as the generateContent path does. YouTube links are video;
    // anything else is sent as a document (verified live: the server still
    // treats a YouTube link sent as a document as video).
    if (_isYouTubeUrl(url)) {
      return VideoContent(uri: url, processing: _videoProcessingOf(part));
    }
    return DocumentContent(uri: url);
  }

  // Inline data URLs are sent as `data`, everything else as a `uri`.
  final isData = url.startsWith('data:');
  final data = isData ? url.substring(url.indexOf(',') + 1) : null;
  final uri = isData ? null : url;

  if (contentType.startsWith('image/')) {
    return ImageContent(mimeType: contentType, data: data, uri: uri);
  }
  if (contentType.startsWith('audio/')) {
    return AudioContent(mimeType: contentType, data: data, uri: uri);
  }
  if (contentType.startsWith('video/')) {
    return VideoContent(
      mimeType: contentType,
      data: data,
      uri: uri,
      processing: _videoProcessingOf(part),
    );
  }
  // Everything else is a document (PDF, CSV, Word, Excel, ...). The server
  // decides which types it accepts and returns a clear error for the rest;
  // its list has grown beyond the PDF and CSV in the published spec.
  return DocumentContent(mimeType: contentType, data: data, uri: uri);
}

// Checks for the custom parts read back from history. JS checks these with
// Zod schemas (GoogleSearchCallSchema, ExecutableCodeSchema, the built-in
// tool `*PartSchema`s, ...): only the ids (and the fields named below) are
// required, the platform can omit the rest, and missing fields aren't sent
// back. A part that fails a check throws, as a failed Zod parse does in JS.

/// The custom part [value] as a map, or throws.
Map<String, Object?> _requireMap(Object? value, String what) {
  if (value is Map) return value.cast<String, Object?>();
  throw _invalidPart(what, 'expected an object');
}

/// The string at [key] of [map], or throws.
String _requireString(Map<String, Object?> map, String key, String what) {
  final value = map[key];
  if (value is String) return value;
  throw _invalidPart(what, '`$key` must be a string');
}

/// The optional string at [key] of [map], or throws if it isn't a string.
String? _optionalString(Map<String, Object?> map, String key, String what) {
  final value = map[key];
  if (value == null || value is String) return value as String?;
  throw _invalidPart(what, '`$key` must be a string');
}

/// The optional map at [key] of [map], or throws if it isn't a map.
Map<String, Object?>? _optionalMap(
  Map<String, Object?> map,
  String key,
  String what,
) {
  final value = map[key];
  if (value == null) return null;
  if (value is Map) return value.cast<String, Object?>();
  throw _invalidPart(what, '`$key` must be an object');
}

/// The optional list of maps at [key] of [map], or throws.
List<Object?>? _optionalMapList(
  Map<String, Object?> map,
  String key,
  String what,
) {
  final value = map[key];
  if (value == null) return null;
  if (value is List && value.every((e) => e is Map)) return value;
  throw _invalidPart(what, '`$key` must be a list of objects');
}

/// The optional bool at [key] of [map], or throws if it isn't a bool.
bool? _optionalBool(Map<String, Object?> map, String key, String what) {
  final value = map[key];
  if (value == null || value is bool) return value as bool?;
  throw _invalidPart(what, '`$key` must be a boolean');
}

/// Whether [value] is a map, a string, or a list of text and image content
/// (JS `RecordUnknownOrStringOrArraySchema`).
bool _isFunctionResult(Object? value) =>
    value is Map ||
    value is String ||
    (value is List &&
        value.every(
          (e) => e is Map && (e['type'] == 'text' || e['type'] == 'image'),
        ));

GenkitException _invalidPart(String what, String problem) => GenkitException(
  'Invalid $what part in the message history: $problem.',
  status: StatusCode.invalidArgument,
);

/// The part's `metadata.thoughtSignature`, if it's set (JS
/// `OptionalStringSchema.parse(part.metadata?.thoughtSignature)`).
String? _thoughtSignatureOf(Part part) {
  final signature = part.metadata?['thoughtSignature'];
  if (signature == null || signature is String) return signature as String?;
  throw _invalidPart('signed', '`metadata.thoughtSignature` must be a string');
}

/// Converts a built-in tool custom part (see [fromBuiltInToolStep]) back into
/// its step, with its signature, so the tool call and result are resent in
/// the history. Returns null for any other part.
BuiltInToolStep? _toBuiltInToolStep(Part part) {
  if (!part.isCustom) return null;
  final custom = part.custom!;
  final signature = _nonEmpty(_thoughtSignatureOf(part));

  if (custom['urlContextCall'] != null) {
    const what = 'urlContextCall';
    final call = _requireMap(custom['urlContextCall'], what);
    return UrlContextCallStep(
      id: _requireString(call, 'id', what),
      arguments: _optionalMap(call, 'arguments', what),
      signature: signature,
    );
  }
  if (custom['urlContextResult'] != null) {
    const what = 'urlContextResult';
    final result = _requireMap(custom['urlContextResult'], what);
    return UrlContextResultStep.fromJson({
      'type': 'url_context_result',
      'call_id': _requireString(result, 'callId', what),
      'result': ?_optionalMapList(result, 'result', what),
      'is_error': ?_optionalBool(result, 'isError', what),
      'signature': ?signature,
    });
  }
  if (custom['fileSearchCall'] != null) {
    const what = 'fileSearchCall';
    final call = _requireMap(custom['fileSearchCall'], what);
    return FileSearchCallStep(
      id: _requireString(call, 'id', what),
      signature: signature,
    );
  }
  if (custom['fileSearchResult'] != null) {
    const what = 'fileSearchResult';
    final result = _requireMap(custom['fileSearchResult'], what);
    return FileSearchResultStep.fromJson({
      'type': 'file_search_result',
      'call_id': _requireString(result, 'callId', what),
      'result': ?_optionalMapList(result, 'result', what),
      'signature': ?signature,
    });
  }
  if (custom['googleMapsCall'] != null) {
    const what = 'googleMapsCall';
    final call = _requireMap(custom['googleMapsCall'], what);
    return GoogleMapsCallStep(
      id: _requireString(call, 'id', what),
      arguments: _optionalMap(call, 'arguments', what),
      signature: signature,
    );
  }
  if (custom['googleMapsResult'] != null) {
    const what = 'googleMapsResult';
    final result = _requireMap(custom['googleMapsResult'], what);
    return GoogleMapsResultStep.fromJson({
      'type': 'google_maps_result',
      'call_id': _requireString(result, 'callId', what),
      'result': ?_optionalMapList(result, 'result', what),
      'signature': ?signature,
    });
  }
  if (custom['mcpServerToolCall'] != null) {
    // MCP steps have no signature in the spec.
    const what = 'mcpServerToolCall';
    final call = _requireMap(custom['mcpServerToolCall'], what);
    return McpServerToolCallStep(
      id: _requireString(call, 'id', what),
      name: _nonEmpty(_optionalString(call, 'name', what)),
      serverName: _nonEmpty(_optionalString(call, 'serverName', what)),
      arguments: _optionalMap(call, 'arguments', what),
    );
  }
  if (custom['mcpServerToolResult'] != null) {
    const what = 'mcpServerToolResult';
    final result = _requireMap(custom['mcpServerToolResult'], what);
    final value = result['result'];
    if (value != null && !_isFunctionResult(value)) {
      throw _invalidPart(what, '`result` must be an object, string or list');
    }
    return McpServerToolResultStep(
      callId: _requireString(result, 'callId', what),
      name: _nonEmpty(_optionalString(result, 'name', what)),
      serverName: _nonEmpty(_optionalString(result, 'serverName', what)),
      result: value,
    );
  }
  return null;
}

/// Converts a list of Genkit [Message]s into a list of Interactions [Step]s.
List<Step> toInteractionSteps(List<Message> messages) {
  final steps = <Step>[];

  for (final message in messages) {
    final normalContent = <Content>[];

    for (final part in message.content) {
      final builtInToolStep = _toBuiltInToolStep(part);
      if (builtInToolStep != null) {
        steps.add(builtInToolStep);
        continue;
      }
      final custom = part.isCustom ? part.custom! : const <String, dynamic>{};
      if (part.isToolRequest) {
        steps.add(_toFunctionCallStep(part));
      } else if (part.isToolResponse) {
        steps.add(_toFunctionResultStep(part.toolResponse!));
      } else if (custom['googleSearchCall'] != null) {
        const what = 'googleSearchCall';
        final gsCall = _requireMap(custom['googleSearchCall'], what);
        steps.add(
          GoogleSearchCallStep(
            id: _requireString(gsCall, 'id', what),
            arguments: _optionalMap(gsCall, 'arguments', what),
            searchType: _nonEmpty(_optionalString(gsCall, 'searchType', what)),
            signature: _thoughtSignatureOf(part),
          ),
        );
      } else if (custom['googleSearchResult'] != null) {
        const what = 'googleSearchResult';
        final gsResult = _requireMap(custom['googleSearchResult'], what);
        final result = gsResult['result'];
        if (result != null && result is! Map) {
          // A list of maps, as the API returns it (or a map, for parts saved
          // before that was fixed in JS).
          _optionalMapList(gsResult, 'result', what);
        }
        steps.add(
          GoogleSearchResultStep(
            callId: _requireString(gsResult, 'callId', what),
            result: result,
            isError: _optionalBool(gsResult, 'isError', what),
            signature: _thoughtSignatureOf(part),
          ),
        );
      } else if (custom['executableCode'] != null) {
        const what = 'executableCode';
        final execCode = _requireMap(custom['executableCode'], what);
        steps.add(
          CodeExecutionCallStep(
            id: _requireString(part.metadata ?? const {}, 'callId', what),
            arguments: {
              'code': _requireString(execCode, 'code', what),
              'language':
                  _optionalString(execCode, 'language', what) ?? 'PYTHON',
            },
            signature: _thoughtSignatureOf(part),
          ),
        );
      } else if (custom['codeExecutionResult'] != null) {
        const what = 'codeExecutionResult';
        final execResult = _requireMap(custom['codeExecutionResult'], what);
        steps.add(
          CodeExecutionResultStep(
            callId: _requireString(part.metadata ?? const {}, 'callId', what),
            result: _requireString(execResult, 'output', what),
            signature: _thoughtSignatureOf(part),
          ),
        );
      } else if (custom['processingCall'] != null) {
        // Agentic video steps are resent as they came back, with their
        // signatures, when the history is sent again.
        const what = 'processingCall';
        final call = _requireMap(custom['processingCall'], what);
        steps.add(
          ProcessingCallStep(
            id: _requireString(call, 'id', what),
            signature: _nonEmpty(_thoughtSignatureOf(part)),
          ),
        );
      } else if (custom['processingResult'] != null) {
        const what = 'processingResult';
        final result = _requireMap(custom['processingResult'], what);
        steps.add(
          ProcessingResultStep(
            callId: _requireString(result, 'callId', what),
            signature: _nonEmpty(_thoughtSignatureOf(part)),
          ),
        );
      } else if (part.isReasoning || _isTruthy(custom['thought'])) {
        steps.add(_toThoughtStep(part));
      } else {
        final content = toInteractionContent(part);
        if (content != null) {
          normalContent.add(content);
        }
      }
    }

    if (normalContent.isNotEmpty) {
      if (message.role == Role.model) {
        steps.add(ModelOutputStep(content: normalContent));
      } else {
        steps.add(UserInputStep(content: normalContent));
      }
    }
  }

  return steps;
}

// Pieces of toInteractionSteps (inline in JS), split out for readability.

FunctionCallStep _toFunctionCallStep(Part part) {
  final request = part.toolRequest!;
  final input = request.input;
  if (input != null && input is! Map) {
    throw _invalidPart('toolRequest', '`input` must be an object');
  }
  return FunctionCallStep(
    name: request.name,
    arguments: (input as Map?)?.cast<String, Object?>(),
    id: request.ref ?? '',
    signature: _nonEmpty(_thoughtSignatureOf(part)),
  );
}

FunctionResultStep _toFunctionResultStep(ToolResponse response) {
  Object? result = response.output;

  final content = response.content;
  if (content != null && content.isNotEmpty) {
    final contentParts = <Object?>[];
    if (result != null) {
      final outputText = result is String ? result : jsonEncode(result);
      contentParts.add(TextContent(text: outputText).json);
    }
    for (final p in content) {
      final mapped = toInteractionContent(
        Part.fromJson((p as Map).cast<String, dynamic>()),
      );
      if (mapped != null) {
        contentParts.add(mapped.json);
      }
    }
    result = contentParts;
  } else if ((result is! Map && result is! String) || result is List) {
    result = {'result': result};
  }

  if (!_isFunctionResult(result)) {
    throw GenkitException(
      'Tool output for ${response.name} may only contain text or image '
      'content.',
      status: StatusCode.invalidArgument,
    );
  }
  return FunctionResultStep(
    name: response.name,
    result: result!,
    callId: response.ref ?? '',
  );
}

/// The thought step for a reasoning part, or a part carrying
/// `custom.thought` (see [fromInteractionStep]).
ThoughtStep _toThoughtStep(Part part) {
  final thought = part.custom?['thought'];
  final thoughtMap = thought is Map ? thought : null;
  final signature =
      part.metadata?['thoughtSignature'] ?? thoughtMap?['signature'];
  if (signature != null && signature is! String) {
    throw _invalidPart('thought', '`signature` must be a string');
  }

  List<Content>? summary;
  final thoughtSummary = thoughtMap?['summary'];
  if (thoughtSummary is List && thoughtSummary.isNotEmpty) {
    summary = [
      for (final c in thoughtSummary)
        Content.fromJson((c as Map).cast<String, Object?>()),
    ];
  } else if (!_isEmpty(part.reasoning)) {
    summary = [TextContent(text: part.reasoning)];
  }

  return ThoughtStep(
    summary: summary,
    signature: _nonEmpty(signature as String?),
  );
}

/// Steps whose content streams as deltas (text, media, thought summaries).
const _streamedContentStepTypes = {'model_output', 'thought'};

/// Steps streamed when the interaction completes (see below).
const _functionStepTypes = {'function_call', 'function_result'};

/// Creates a converter from stream events to the parts of stream chunks.
///
/// Content (text, media, thought summaries and signatures) is emitted as
/// each delta arrives. Tool steps (Google Search, code execution, URL
/// context, ...) are emitted once complete, at `step.stop`: the server sends
/// their ids in `step.start` and everything else in a single delta, so
/// waiting for the end gives the same parts as the final response. Function
/// calls (and function results, to keep them in order) are emitted when the
/// interaction completes, because only then is it known whether a call is
/// for Genkit to run (a tool request) or was already run by the server.
///
/// Returns a function that takes each stream event, in order, and returns
/// the parts to stream for it (often none).
List<Part> Function(InteractionSseEvent event)
createInteractionChunkConverter() {
  // Each event is applied to this converter's own copy of the steps, the
  // same way the final response is assembled.
  final steps = <Step?>[];
  final partialArguments = <int, String>{};
  String? status;
  return (event) {
    applyInteractionStepEvent(steps, partialArguments, event);
    switch (event.eventType) {
      case 'interaction.status_update':
        status = InteractionStatusUpdate.fromJson(event.json).status;
      case 'step.delta':
        final delta = StepDelta.fromJson(event.json).delta;
        return delta == null ? [] : fromInteractionDelta(delta);
      case 'step.stop':
        final index = StepStop.fromJson(event.json).index;
        final step = index == null || index >= steps.length
            ? null
            : steps[index];
        if (step == null ||
            _functionStepTypes.contains(step.type) ||
            _streamedContentStepTypes.contains(step.type)) {
          return [];
        }
        return _withoutEmptyParts(fromInteractionStep(step));
      case 'interaction.completed':
        final known = <Step>[for (final step in steps) ?step];
        final pendingIds = _getPendingFunctionCallIds(
          known,
          InteractionEvent.fromJson(event.json).interaction?.status ?? status,
        );
        return _withoutEmptyParts([
          for (final step in known)
            if (_functionStepTypes.contains(step.type))
              ...fromInteractionStep(
                step,
                step.type == 'function_call' &&
                    pendingIds.contains(step.json['id']),
              ),
        ]);
    }
    return [];
  };
}

List<Part> _withoutEmptyParts(List<Part> parts) =>
    parts.where((p) => p.toJson().isNotEmpty).toList();

/// Converts a streamed content delta (text, media, thought summary or
/// signature) into Genkit parts for a stream chunk.
///
/// [delta] is the `delta` of a `step.delta` SSE event. Returns the matching
/// Genkit parts (empty for deltas with nothing to emit on their own, such as
/// function call arguments).
List<Part> fromInteractionDelta(StepDeltaData delta) {
  switch (delta.type) {
    case 'text':
      return [TextPart(text: TextDelta.fromJson(delta.json).text ?? '')];
    case 'image':
    case 'audio':
    case 'document':
    case 'video':
      final json = delta.json;
      final data = json['data'] as String?;
      final mimeType = json['mime_type'] as String?;
      var url = json['uri'] as String?;
      if (!_isEmpty(data) && !_isEmpty(mimeType)) {
        url = 'data:$mimeType;base64,$data';
      }
      final resolution = json['resolution'];
      return [
        MediaPart(
          media: Media(url: url ?? '', contentType: mimeType),
          metadata:
              (delta.type == 'image' || delta.type == 'video') &&
                  resolution != null
              ? {'resolution': resolution}
              : null,
        ),
      ];
    case 'thought_summary':
      final content = ThoughtSummaryDelta.fromJson(delta.json).content;
      if (content == null) return [];
      if (content.type == 'text') {
        final annotations = content.json['annotations'];
        return [
          ReasoningPart(
            reasoning: TextContent.fromJson(content.json).text ?? '',
            metadata: annotations != null ? {'annotations': annotations} : null,
          ),
        ];
      }
      // Non-text thought content (e.g. a draft image) is part of the
      // reasoning, not the answer. Use the same placeholder as the final
      // response so streaming clients don't receive it as a regular part.
      return [ReasoningPart(reasoning: _thoughtContentPlaceholder(content))];
    case 'thought_signature':
      return [
        Part.fromJson({
          'metadata': {
            'thoughtSignature': ThoughtSignatureDelta.fromJson(
              delta.json,
            ).signature,
          },
        }),
      ];
    default:
      return [];
  }
}

/// Converts an Interactions [Content] block back into a Genkit [Part].
///
/// Supports text, image, audio, document, video, thought, function calls, and
/// function results. Unknown content types are returned as a custom part.
Part fromInteractionContent(Content content) {
  switch (content.type) {
    case 'text':
      return _fromTextContent(TextContent.fromJson(content.json));
    case 'image':
    case 'video':
      return _fromImageOrVideoContent(content);
    case 'audio':
    case 'document':
      return _fromMediaContent(content);
    case 'thought':
      return _fromThoughtContent(content.json);
    case 'function_call':
      return _fromFunctionCallContent(
        FunctionCallContent.fromJson(content.json),
      );
    case 'function_result':
      return _fromFunctionResultContent(
        FunctionResultContent.fromJson(content.json),
      );
    default:
      return CustomPart(custom: {'unknownContent': content.json});
  }
}

/// Copies the step's `signature` (if set) into the part's
/// `metadata.thoughtSignature`.
Part _maybeAddGeminiThoughtSignature(Step step, Part part) {
  final signature = step.json['signature'];
  if (signature is! String || signature.isEmpty) return part;
  final json = part.toJson();
  return Part.fromJson({
    ...json,
    'metadata': {
      ...?(json['metadata'] as Map?)?.cast<String, dynamic>(),
      'thoughtSignature': signature,
    },
  });
}

Part fromGoogleSearchCall(GoogleSearchCallStep step) {
  return _maybeAddGeminiThoughtSignature(
    step,
    CustomPart(
      custom: {
        'googleSearchCall': {
          'id': step.id,
          'arguments': ?step.arguments,
          'searchType': ?_nonEmpty(step.searchType),
        },
      },
    ),
  );
}

Part fromGoogleSearchResult(GoogleSearchResultStep step) {
  return _maybeAddGeminiThoughtSignature(
    step,
    CustomPart(
      custom: {
        'googleSearchResult': {
          'callId': step.callId,
          'result': ?step.result,
          'isError': ?step.isError,
        },
      },
    ),
  );
}

Part fromCodeExecutionCall(CodeExecutionCallStep step) {
  return _maybeAddGeminiThoughtSignature(
    step,
    CustomPart(
      custom: {
        'executableCode': {
          'code': ?step.arguments?['code'],
          'language':
              _nonEmpty(step.arguments?['language'] as String?) ?? 'PYTHON',
        },
      },
      metadata: {'callId': step.id},
    ),
  );
}

Part fromCodeExecutionResult(CodeExecutionResultStep step) {
  final result = step.result;
  return _maybeAddGeminiThoughtSignature(
    step,
    CustomPart(
      custom: {
        'codeExecutionResult': {
          'output': result is String ? result : jsonEncode(result),
          'outcome': 'OUTCOME_OK',
        },
      },
      metadata: {'callId': step.callId},
    ),
  );
}

/// A function call the client has to run: a tool request.
///
/// [step] is a [FunctionCallStep] or a [FunctionCallContent].
Part fromPendingFunctionCall(Step step) {
  // Keep the signature so it can be sent back with the function call when
  // the history is resent (stateless, the default).
  final json = step.json;
  return _maybeAddGeminiThoughtSignature(
    step,
    ToolRequestPart(
      toolRequest: ToolRequest(
        name: json['name'] as String? ?? '',
        ref: json['id'] as String?,
        input: json['arguments'],
      ),
    ),
  );
}

/// A function call the server ran itself (e.g. an MCP tool on googleAI).
///
/// [step] is a [FunctionCallStep] or a [FunctionCallContent].
Part fromServerFunctionCall(Step step) {
  final json = step.json;
  return _maybeAddGeminiThoughtSignature(
    step,
    CustomPart(
      custom: {
        'serverFunctionCall': {
          'id': ?json['id'],
          'name': ?json['name'],
          'arguments': ?json['arguments'],
        },
      },
    ),
  );
}

/// The result of a function call the server ran itself.
///
/// [step] is a [FunctionResultStep] or a [FunctionResultContent].
Part fromServerFunctionResult(Step step) {
  final json = step.json;
  return CustomPart(
    custom: {
      'serverFunctionResult': {
        'callId': ?json['call_id'],
        'name': json['name'] as String? ?? '',
        'result': ?json['result'],
        'isError': ?json['is_error'],
      },
    },
  );
}

List<Part> fromInteractionStep(Step step, [bool isPending = false]) {
  switch (step.type) {
    case 'model_output':
      return [
        for (final c
            in ModelOutputStep.fromJson(step.json).content ?? const <Content>[])
          fromInteractionContent(c),
      ];
    case 'user_input':
      return [];
    case 'google_search_call':
      return [fromGoogleSearchCall(GoogleSearchCallStep.fromJson(step.json))];
    case 'google_search_result':
      return [
        fromGoogleSearchResult(GoogleSearchResultStep.fromJson(step.json)),
      ];
    case 'code_execution_call':
      return [fromCodeExecutionCall(CodeExecutionCallStep.fromJson(step.json))];
    case 'code_execution_result':
      return [
        fromCodeExecutionResult(CodeExecutionResultStep.fromJson(step.json)),
      ];
    case 'thought':
      return [_fromThoughtContent(step.json)];
    case 'function_call':
      return isPending
          ? [fromPendingFunctionCall(step)]
          : [fromServerFunctionCall(step)];
    case 'function_result':
      return [fromServerFunctionResult(step)];
    case 'processing_call':
      return [
        _maybeAddGeminiThoughtSignature(
          step,
          CustomPart(
            custom: {
              'processingCall': {'id': ?step.json['id']},
            },
          ),
        ),
      ];
    case 'processing_result':
      return [
        _maybeAddGeminiThoughtSignature(
          step,
          CustomPart(
            custom: {
              'processingResult': {'callId': ?step.json['call_id']},
            },
          ),
        ),
      ];
    case 'url_context_call':
    case 'url_context_result':
    case 'file_search_call':
    case 'file_search_result':
    case 'google_maps_call':
    case 'google_maps_result':
    case 'mcp_server_tool_call':
    case 'mcp_server_tool_result':
      return [fromBuiltInToolStep(BuiltInToolStep.fromJson(step.json))];
  }

  return [
    CustomPart(custom: {'unknownStep': step.json}),
  ];
}

/// Converts a server-side built-in tool step (url context, file search,
/// Google Maps, MCP server) into a custom part, with the step's `signature`
/// in `metadata.thoughtSignature`. [_toBuiltInToolStep] turns it back into
/// the step when the history is resent. These are never tool request parts:
/// the server ran the tool, so there's nothing for Genkit to run.
Part fromBuiltInToolStep(BuiltInToolStep step) {
  final json = step.json;
  switch (step.type) {
    case 'url_context_call':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'urlContextCall': {
              'id': ?json['id'],
              'arguments': ?json['arguments'],
            },
          },
        ),
      );
    case 'url_context_result':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'urlContextResult': {
              'callId': ?json['call_id'],
              'result': ?json['result'],
              'isError': ?json['is_error'],
            },
          },
        ),
      );
    case 'file_search_call':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'fileSearchCall': {'id': ?json['id']},
          },
        ),
      );
    case 'file_search_result':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'fileSearchResult': {
              'callId': ?json['call_id'],
              'result': ?json['result'],
            },
          },
        ),
      );
    case 'google_maps_call':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'googleMapsCall': {
              'id': ?json['id'],
              'arguments': ?json['arguments'],
            },
          },
        ),
      );
    case 'google_maps_result':
      return _maybeAddGeminiThoughtSignature(
        step,
        CustomPart(
          custom: {
            'googleMapsResult': {
              'callId': ?json['call_id'],
              'result': ?json['result'],
            },
          },
        ),
      );
    case 'mcp_server_tool_call':
      return CustomPart(
        custom: {
          'mcpServerToolCall': {
            'id': ?json['id'],
            'name': ?_nonEmpty(json['name'] as String?),
            'serverName': ?_nonEmpty(json['server_name'] as String?),
            'arguments': ?json['arguments'],
          },
        },
      );
    case 'mcp_server_tool_result':
      return CustomPart(
        custom: {
          'mcpServerToolResult': {
            'callId': ?json['call_id'],
            'name': ?_nonEmpty(json['name'] as String?),
            'serverName': ?_nonEmpty(json['server_name'] as String?),
            'result': ?json['result'],
          },
        },
      );
  }
  // Only reached for a step that isn't a built-in tool step.
  return CustomPart(custom: {'unknownStep': json});
}

Set<String> _getPendingFunctionCallIds(List<Step> steps, String? status) {
  final pendingIds = <String>{};
  if (status != 'requires_action') {
    return pendingIds;
  }

  final resultSet = <String>{};
  for (final step in steps) {
    final callId = step.json['call_id'];
    if (step.type == 'function_result' && callId is String && callId != '') {
      resultSet.add(callId);
    }
  }

  for (final step in steps) {
    final id = step.json['id'];
    if (step.type == 'function_call' && id is String && id != '') {
      if (!resultSet.contains(id)) {
        pendingIds.add(id);
      }
    }
  }

  return pendingIds;
}

Part _fromMediaContent(Content content) {
  final json = content.json;
  final data = json['data'] as String?;
  final mimeType = json['mime_type'] as String?;
  var url = json['uri'] as String?;
  if (!_isEmpty(data) && !_isEmpty(mimeType)) {
    url = 'data:$mimeType;base64,$data';
  }
  return MediaPart(
    media: Media(url: url ?? '', contentType: mimeType),
  );
}

Part _fromTextContent(TextContent content) {
  return TextPart(
    text: content.text ?? '',
    metadata: {'annotations': ?content.json['annotations']},
  );
}

/// JS `fromImageContent` and `fromVideoContent` (the same code).
Part _fromImageOrVideoContent(Content content) {
  final resolution = content.json['resolution'];
  if (resolution == null) return _fromMediaContent(content);
  return MediaPart(
    media: (_fromMediaContent(content) as MediaPart).media,
    metadata: {'resolution': resolution},
  );
}

/// Placeholder text for non-text content inside a thought summary, e.g.
/// `[Image]`, `[Audio]` or `[Function call]`.
///
/// Thoughts are returned as reasoning text, so non-text items (such as a
/// draft image the model reviews before its final output) are shown as a
/// label instead of being dropped or returned as regular media parts. The
/// label is derived from the content type, so any type the server adds in the
/// future still shows up in the reasoning.
String _thoughtContentPlaceholder(Content content) {
  final label = (content.type ?? '').replaceAll('_', ' ');
  if (label.isEmpty) return '[]';
  return '[${label[0].toUpperCase()}${label.substring(1)}]';
}

/// JS `fromThoughtContent`: for a [ThoughtContent] block or a [ThoughtStep]
/// (both are `{type: 'thought', signature?, summary?}`).
Part _fromThoughtContent(Map<String, Object?> content) {
  final thought = ThoughtContent.fromJson(content);
  var reasoning = '';
  final summary = thought.summary;
  if (summary != null) {
    // Separate summary blocks with a newline so distinct thought sections
    // don't run together. Each summary block is a whole section, both in
    // non-streamed responses and in streamed `thought_summary` deltas (one
    // delta per section, confirmed live), so this doesn't split sentences.
    reasoning = summary
        .map(
          (c) => c.type == 'text'
              ? TextContent.fromJson(c.json).text ?? ''
              : _thoughtContentPlaceholder(c),
        )
        .join('\n');
  }

  return ReasoningPart(
    reasoning: reasoning,
    metadata: {'thoughtSignature': ?thought.signature},
    custom: {'thought': content},
  );
}

Part _fromFunctionCallContent(FunctionCallContent content) {
  return ToolRequestPart(
    toolRequest: ToolRequest(
      name: content.name ?? '',
      input: content.arguments,
      ref: content.id,
    ),
  );
}

bool _isContentArray(Object? value) =>
    value is List &&
    value.isNotEmpty &&
    value.every((item) => item is Map && item['type'] is String);

Part _fromFunctionResultContent(FunctionResultContent content) {
  final result = content.result;
  if (_isContentArray(result)) {
    return ToolResponsePart(
      toolResponse: ToolResponse(
        name: content.name ?? '',
        content: [
          for (final c in result as List)
            fromInteractionContent(
              Content.fromJson((c as Map).cast<String, Object?>()),
            ).toJson(),
        ],
        ref: content.callId,
      ),
    );
  }
  return ToolResponsePart(
    toolResponse: ToolResponse(
      name: content.name ?? '',
      output: result,
      ref: content.callId,
    ),
  );
}

/// Converts Interactions API token usage to Genkit usage.
GenerationUsage _fromInteractionUsage(Usage usage) {
  int? tokensFor(List<ModalityTokens>? byModality, String modality) {
    // Like JS, the last entry for a modality wins.
    int? tokens;
    for (final m in byModality ?? const <ModalityTokens>[]) {
      if (m.modality?.value == modality) tokens = m.tokens;
    }
    return tokens;
  }

  final input = usage.inputTokensByModality;
  final output = usage.outputTokensByModality;

  // Genkit has no standard fields for these.
  final custom = <String, dynamic>{};
  // Tokens loaded by tools, e.g. video frames read during agentic video
  // understanding.
  final toolUseTokens = usage.totalToolUseTokens;
  if (toolUseTokens != null && toolUseTokens != 0) {
    custom['toolUseTokens'] = toolUseTokens;
  }
  // How many times each grounding tool was used, e.g. `googleSearchCount`.
  for (final g in usage.groundingToolCount ?? const <GroundingToolCount>[]) {
    final type = g.type;
    final count = g.count;
    if (!_isEmpty(type) && count != null) {
      final key = '${snakeToCamelCase(type!)}Count';
      custom[key] = ((custom[key] as int?) ?? 0) + count;
    }
  }

  return GenerationUsage(
    inputTokens: usage.totalInputTokens,
    outputTokens: usage.totalOutputTokens,
    totalTokens: usage.totalTokens,
    cachedContentTokens: usage.totalCachedTokens,
    thoughtsTokens: usage.totalThoughtTokens,
    inputCharacters: tokensFor(input, 'text'),
    inputImages: tokensFor(input, 'image'),
    inputAudioFiles: tokensFor(input, 'audio'),
    inputVideos: tokensFor(input, 'video'),
    outputCharacters: tokensFor(output, 'text'),
    outputImages: tokensFor(output, 'image'),
    outputAudioFiles: tokensFor(output, 'audio'),
    outputVideos: tokensFor(output, 'video'),
    custom: custom.isEmpty ? null : custom,
  );
}

const _interactionFailedMessage = 'Interaction failed';
const _interactionIncompleteMessage =
    'Interaction incomplete (truncated output)';

/// Builds a human-readable message from a failed interaction's errors.
String _interactionFailureMessage(GeminiInteraction interaction) {
  final details = (interaction.errors ?? const <InteractionError>[])
      .map(
        (e) => [
          _isEmpty(e.code) ? '' : '[${e.code}]',
          e.message ?? '',
        ].join(' ').trim(),
      )
      .where((d) => d.isNotEmpty)
      .join('; ');
  return details.isNotEmpty
      ? '$_interactionFailedMessage: $details'
      : _interactionFailedMessage;
}

/// Converts a `status: 'failed'` interaction into a Genkit outcome:
///  - content-policy blocks (safety, recitation, ...) return a response with
///    `finishReason: blocked`, matching the generateContent path;
///  - everything else throws a GenkitException with the status mapped from
///    the error code (UNKNOWN if unrecognized, which is not retried).
ModelResponse _fromFailedInteraction(GeminiInteraction interaction) {
  final firstError = interaction.errors?.firstOrNull;
  if (isInteractionContentBlockCode(firstError?.code)) {
    final usage = interaction.usage;
    return ModelResponse(
      finishReason: FinishReason.blocked,
      finishMessage:
          _nonEmpty(firstError?.message) ??
          _interactionFailureMessage(interaction),
      message: Message(
        role: Role.model,
        content: [],
        metadata: _interactionMessageMetadata(interaction),
      ),
      custom: interaction.json,
      raw: interaction.json,
      usage: usage == null ? null : _fromInteractionUsage(usage),
    );
  }
  throw GenkitException(
    _interactionFailureMessage(interaction),
    status:
        interactionErrorCodeToGenkitStatus(firstError?.code) ??
        StatusCode.unknown,
    details: jsonEncode(interaction.json),
  );
}

/// Message metadata carrying the interaction and environment IDs, if any.
Map<String, dynamic>? _interactionMessageMetadata(
  GeminiInteraction interaction,
) {
  final metadata = <String, dynamic>{
    'interactionId': ?_nonEmpty(interaction.id),
    'environmentId': ?_nonEmpty(interaction.environmentId),
  };
  return metadata.isEmpty ? null : metadata;
}

/// Converts a (non-background) interaction into a Genkit model response.
ModelResponse fromInteractionSync(GeminiInteraction interaction) {
  if (interaction.status == 'failed') {
    return _fromFailedInteraction(interaction);
  }

  final interactionUsage = interaction.usage;
  final usage = interactionUsage == null
      ? null
      : _fromInteractionUsage(interactionUsage);
  final metadata = _interactionMessageMetadata(interaction);

  if (interaction.status == 'cancelled') {
    return ModelResponse(
      finishReason: FinishReason.aborted,
      finishMessage: 'Operation cancelled',
      message: Message(
        role: Role.model,
        content: [TextPart(text: 'Operation cancelled.')],
        metadata: metadata,
      ),
      custom: interaction.json,
      raw: interaction.json,
      usage: usage,
    );
  }

  var finishReason = FinishReason.stop;
  String? finishMessage;
  if (interaction.status == 'incomplete') {
    // Token/step limit reached (MAX_TOKENS); partial content may be present.
    finishReason = FinishReason.length;
    finishMessage = _interactionIncompleteMessage;
  }

  var content = <Part>[];
  final steps = interaction.steps;
  if (steps != null && steps.isNotEmpty) {
    final pendingIds = _getPendingFunctionCallIds(steps, interaction.status);
    content = _withoutEmptyParts([
      for (final step in steps)
        ...fromInteractionStep(
          step,
          step.type == 'function_call' && pendingIds.contains(step.json['id']),
        ),
    ]);
  }

  return ModelResponse(
    finishReason: finishReason,
    finishMessage: finishMessage,
    message: Message(role: Role.model, content: content, metadata: metadata),
    custom: interaction.json,
    raw: interaction.json,
    usage: usage,
  );
}

/// Audio types without a container header, so chunks can be joined end to
/// end.
const _headerlessAudioTypes = ['audio/l16', 'audio/mulaw', 'audio/alaw'];

bool _isHeaderlessAudio(Part part) {
  final media = part.media;
  final contentType = media?.contentType?.toLowerCase();
  return media != null &&
      media.url.startsWith('data:') &&
      contentType != null &&
      contentType.isNotEmpty &&
      _headerlessAudioTypes.any(contentType.startsWith);
}

bool _isWavAudio(Part part) {
  final media = part.media;
  return media != null &&
      media.url.startsWith('data:') &&
      (media.contentType?.toLowerCase().startsWith('audio/wav') ?? false);
}

Uint8List _mediaBytes(Part part) {
  final url = part.media?.url ?? '';
  return base64Decode(url.substring(url.indexOf(',') + 1));
}

Part _mediaPart(String contentType, Uint8List bytes) => MediaPart(
  media: Media(
    url: 'data:$contentType;base64,${base64Encode(bytes)}',
    contentType: contentType,
  ),
);

/// Removes ID3 tags from the start of a headerless audio part.
///
/// The server sometimes sends a C2PA manifest, in an ID3 tag, at the start
/// of a streamed `audio/l16` chunk (seen with gemini-3.8-flash-lite-tts and
/// two speakers). The tag isn't audio: played or joined as raw audio it is
/// noise, and its odd size shifts every sample after it by one byte. This
/// has been reported to the Gemini API team; until it's fixed, the tag is
/// removed so the audio plays correctly. That manifest is dropped. The tag
/// has only been seen whole at the start of a chunk; a tag that doesn't fit
/// in the chunk is left in, since bytes that can't be checked as a tag might
/// be audio.
Part removeId3FromAudio(Part part) {
  final media = part.media;
  if (media == null || !_isHeaderlessAudio(part)) {
    return part;
  }
  final bytes = _mediaBytes(part);
  final audio = stripLeadingId3Tags(bytes);
  if (identical(audio, bytes)) {
    return part;
  }
  final contentType = media.contentType ?? 'audio/l16';
  return Part.fromJson({
    ...part.toJson(),
    'media': {
      ...media.toJson(),
      'url': 'data:$contentType;base64,${base64Encode(audio)}',
    },
  });
}

/// Joins streamed audio chunks in the final response into one part, in the
/// format the server returned:
///  - consecutive headerless chunks (`audio/l16`, `audio/mulaw`,
///    `audio/alaw`) of the same type are joined end to end;
///  - a streamed `audio/wav` request starts with a small complete WAV file
///    and continues with `audio/l16` chunks (seen live). Those chunks go
///    into the WAV's `data` chunk, giving one WAV like a non-streamed
///    response.
/// Other parts are kept as they are.
List<Part> mergeStreamedAudio(List<Part> parts) {
  Uint8List concat(Iterable<Part> chunks) {
    final builder = BytesBuilder(copy: false);
    for (final chunk in chunks) {
      builder.add(_mediaBytes(chunk));
    }
    return builder.takeBytes();
  }

  final merged = <Part>[];
  var i = 0;
  while (i < parts.length) {
    final part = parts[i];
    if (_isWavAudio(part)) {
      var j = i + 1;
      while (j < parts.length && _isHeaderlessAudio(parts[j])) {
        j++;
      }
      final audio = concat(parts.sublist(i + 1, j));
      final wav = audio.isNotEmpty
          ? appendToWavData(_mediaBytes(part), audio)
          : null;
      if (wav != null) {
        merged.add(_mediaPart(part.media!.contentType ?? 'audio/wav', wav));
        i = j;
        continue;
      }
      merged.add(part);
      i++;
      continue;
    }
    if (_isHeaderlessAudio(part)) {
      final contentType = part.media?.contentType;
      var j = i + 1;
      while (j < parts.length &&
          _isHeaderlessAudio(parts[j]) &&
          parts[j].media?.contentType == contentType) {
        j++;
      }
      if (j - i > 1 && contentType != null && contentType.isNotEmpty) {
        merged.add(_mediaPart(contentType, concat(parts.sublist(i, j))));
      } else {
        merged.addAll(parts.sublist(i, j));
      }
      i = j;
      continue;
    }
    merged.add(part);
    i++;
  }
  return merged;
}

// ---------------------------------------------------------------------------
// Helpers from js/plugins/google-genai/src/common/utils.ts.
// ---------------------------------------------------------------------------

/// Applies a `step.start`, `step.delta` or `step.stop` event to the steps
/// assembled so far (other events are ignored). Used for the final response
/// and for stream chunks ([createInteractionChunkConverter]), so both see
/// the same steps.
///
/// [steps] are the steps so far, by index (null for an index not started
/// yet); updated in place. [partialArguments] holds the function call
/// arguments received so far, by step index; they're parsed when the step
/// stops.
void applyInteractionStepEvent(
  List<Step?> steps,
  Map<int, String> partialArguments,
  InteractionSseEvent event,
) {
  switch (event.eventType) {
    case 'step.start':
      final start = StepStart.fromJson(event.json);
      final index = start.index;
      final step = start.step;
      if (index == null || index < 0 || step == null) return;
      while (steps.length <= index) {
        steps.add(null);
      }
      // A copy: the event must not change as the step is assembled, and
      // several readers can assemble steps from the same events.
      steps[index] = Step.fromJson(_deepCopy(step.json));
    case 'step.delta':
      final stepDelta = StepDelta.fromJson(event.json);
      final index = stepDelta.index;
      final delta = stepDelta.delta;
      if (index == null || delta == null) return;
      final step = index >= 0 && index < steps.length ? steps[index] : null;
      if (step != null) {
        _applyStepDelta(step, index, delta, partialArguments);
      }
    case 'step.stop':
      final index = StepStop.fromJson(event.json).index;
      // If we had partial arguments for this step, parse them and update the
      // function call arguments.
      if (index == null || !partialArguments.containsKey(index)) return;
      final step = index >= 0 && index < steps.length ? steps[index] : null;
      if (step != null && step.type == 'function_call') {
        final argStr = partialArguments[index];
        if (argStr != null && argStr.isNotEmpty) {
          try {
            step.json['arguments'] = jsonDecode(argStr);
          } on FormatException catch (e) {
            logger.warning(
              'Failed to parse partial arguments JSON for function call: $e',
            );
          }
        }
      }
      partialArguments.remove(index);
  }
}

void _applyStepDelta(
  Step step,
  int index,
  StepDeltaData delta,
  Map<int, String> partialArguments,
) {
  final type = step.type;
  if (type == 'model_output' || type == 'user_input' || type == 'thought') {
    final key = type == 'thought' ? 'summary' : 'content';
    if (step.json[key] is! List) step.json[key] = <Object?>[];
    final arr = step.json[key] as List;

    switch (delta.type) {
      case 'text':
        // Append to the previous text block so a streamed answer becomes a
        // single block, matching the non-streamed response. This also keeps
        // annotation start/end indices meaningful.
        final text = delta.json['text'] as String? ?? '';
        final last = arr.lastOrNull;
        if (last is Map && last['type'] == 'text') {
          last['text'] = ((last['text'] as String?) ?? '') + text;
        } else {
          arr.add(<String, Object?>{'type': 'text', 'text': text});
        }
      case 'image' || 'audio' || 'video' || 'document':
        // Media deltas have the same shape as the matching content block.
        arr.add({...delta.json});
      case 'text_annotation_delta':
        final annotations = delta.json['annotations'];
        if (annotations is List && annotations.isNotEmpty) {
          var target = arr.reversed
              .whereType<Map>()
              .where((c) => c['type'] == 'text')
              .firstOrNull;
          if (target == null) {
            target = <String, Object?>{'type': 'text', 'text': ''};
            arr.add(target);
          }
          target['annotations'] = [
            ...?(target['annotations'] as List?),
            ...annotations,
          ];
        }
      case 'thought_summary':
        final content = delta.json['content'];
        if (content is Map) {
          // A copy, like the step itself (see step.start).
          arr.add({...content});
        }
      case 'thought_signature':
        if (type == 'thought') {
          _setOrRemove(step.json, 'signature', delta.json['signature']);
        }
    }
  } else if (type == 'function_call' && delta.type == 'arguments_delta') {
    final existing = partialArguments[index] ?? '';
    partialArguments[index] =
        existing + ((delta.json['arguments'] as String?) ?? '');
  } else if (delta.type == type) {
    // Built-in tool steps (google_search_call/result,
    // code_execution_call/result, url_context_*, file_search_*,
    // google_maps_*, mcp_server_tool_*, function_result, ...): step.start
    // carries only ids and an empty signature; the arguments, result and
    // real signature arrive in a delta of the same type. Copy those fields
    // onto the step.
    for (final MapEntry(:key, :value) in delta.json.entries) {
      if (key != 'type' && value != null) step.json[key] = value;
    }
  }
}

/// Interactions API content-policy codes. These are reported in two ways:
///  - prompt blocked before execution: HTTP 400 with `error.code` set;
///  - response blocked after execution: HTTP 200, `status: 'failed'`, with
///    the code in `interaction.errors[]`.
///
/// In the second case the plugin returns `finishReason: blocked` (matching
/// the generateContent path) rather than throwing. When thrown (first case)
/// they map to FAILED_PRECONDITION, which is not retryable: the same input
/// will be blocked again.
const _interactionContentBlockCodes = {
  'safety',
  'recitation',
  'language',
  'prohibited_content',
  'spii',
  'blocklist',
  'image_safety',
  'image_prohibited_content',
  'image_recitation',
  'image_other',
  'content_blocked',
  'jailbreak',
  'model_armor',
};

/// Reports whether an Interactions API error code is a content-policy block
/// (safety, recitation, blocklist, etc.).
bool isInteractionContentBlockCode(Object? code) =>
    code is String &&
    _interactionContentBlockCodes.contains(code.trim().toLowerCase());

/// Interactions API error codes mapped to Genkit statuses.
///
/// The Interactions API reports errors as `{code: string, message: string}`.
/// The public spec documents `code` only as "a URI that identifies the error
/// type" and does not enumerate values; this table is the full set of codes
/// the API returns (with the HTTP status the API pairs each one with).
final _interactionErrorCodeToStatus = <String, StatusCode>{
  // Generation failures reported via `status: 'failed'` + `errors[]` after
  // the server's own internal retries are exhausted. The server message
  // advises retrying, so these map to ABORTED ("retry at a higher level"),
  // which the retry middleware retries by default.
  'malformed_function_call': StatusCode.aborted,
  'unexpected_tool_call': StatusCode.aborted,
  'no_image': StatusCode.aborted,
  // Content-policy blocks; see _interactionContentBlockCodes.
  for (final code in _interactionContentBlockCodes)
    code: StatusCode.failedPrecondition,
  'service_unavailable': StatusCode.unavailable, // 503: overloaded
  'rate_limit_exceeded': StatusCode.resourceExhausted, // 429: RPM/TPM
  'quota_exceeded': StatusCode.resourceExhausted, // 429: RPD/daily
  'invalid_request': StatusCode.invalidArgument, // 400: general bad request
  'parameter_unknown': StatusCode.invalidArgument, // 400: unknown field
  'failed_precondition': StatusCode.failedPrecondition, // 400
  'out_of_range': StatusCode.outOfRange, // 400
  // 400: exceeded the agent's max token limit. Deterministic for a given
  // request, so deliberately not RESOURCE_EXHAUSTED (which is retryable).
  'agent_max_token_limit': StatusCode.invalidArgument,
  'model_not_found': StatusCode.notFound, // 404
  'not_found': StatusCode.notFound, // 404
  'authentication': StatusCode.unauthenticated, // 401
  'permission_denied': StatusCode.permissionDenied, // 403
  'already_exists': StatusCode.alreadyExists, // 409
  'aborted': StatusCode.aborted, // 409
  'cancelled': StatusCode.cancelled, // 499
  'deadline_exceeded': StatusCode.deadlineExceeded, // 504
  'api_error': StatusCode.internal, // 500
  'unimplemented': StatusCode.unimplemented, // 501
};

/// Maps an Interactions API error `code` to a Genkit [StatusCode].
///
/// Looks the code up (case-insensitively) in the known Interactions error
/// codes. Also accepts numeric HTTP codes (e.g. `503` or `"503"`), in case
/// the front end returns a Google-style error body instead. Returns null if
/// it cannot be mapped.
StatusCode? interactionErrorCodeToGenkitStatus(Object? code) {
  if (code is num) {
    final status = _httpStatusToGenkitStatus(code.toInt());
    return status == StatusCode.unknown ? null : status;
  }
  if (code is! String || code.trim().isEmpty) {
    return null;
  }
  final normalized = code.trim().toLowerCase();
  if (RegExp(r'^\d+$').hasMatch(normalized)) {
    return interactionErrorCodeToGenkitStatus(int.parse(normalized));
  }
  return _interactionErrorCodeToStatus[normalized];
}

/// Maps an HTTP status code to the matching Genkit [StatusCode], or
/// [StatusCode.unknown] if there is no mapping.
StatusCode _httpStatusToGenkitStatus(int code) => switch (code) {
  400 => StatusCode.invalidArgument,
  401 => StatusCode.unauthenticated,
  403 => StatusCode.permissionDenied,
  404 => StatusCode.notFound,
  429 => StatusCode.resourceExhausted,
  499 => StatusCode.cancelled,
  500 => StatusCode.internal,
  503 => StatusCode.unavailable,
  504 => StatusCode.deadlineExceeded,
  _ => StatusCode.unknown,
};

/// Cleans a JSON schema by removing specific keys and standardizing types.
///
/// Removes `$schema` and `additionalProperties`, and turns a type list such
/// as `["string", "null"]` (from nullable fields) into its first non-null
/// type, which the model API supports.
Map<String, Object?> cleanSchema(Map<String, Object?> schema) =>
    _cleanSchemaValue(schema) as Map<String, Object?>;

Object? _cleanSchemaValue(Object? value) {
  if (value is List) return value.map(_cleanSchemaValue).toList();
  if (value is! Map) return value;
  final out = <String, Object?>{};
  for (final MapEntry(:key, value: v) in value.entries) {
    if (key == r'$schema' || key == 'additionalProperties') continue;
    if (key == 'type' && v is List) {
      // The first type that's not `null` (JS `find`).
      out[key as String] = v
          .cast<Object?>()
          .where((t) => t != 'null')
          .firstOrNull;
      continue;
    }
    out[key as String] = _cleanSchemaValue(v);
  }
  return out;
}

const _knownMimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'mp4': 'video/mp4',
  'pdf': 'application/pdf',
};

/// The MIME type of a `data:` URL, or of a URL with a known extension; an
/// empty string if it can't be determined.
String extractMimeType(String? url) {
  if (url == null || url.isEmpty) {
    return '';
  }

  const dataPrefix = 'data:';
  if (!url.startsWith(dataPrefix)) {
    // Not a data url, try the suffix.
    final key = url.substring(url.lastIndexOf('.') + 1);
    return _knownMimeTypes[key] ?? '';
  }

  final commaIndex = url.indexOf(',');
  if (commaIndex == -1) {
    // Invalid: missing separator.
    return '';
  }

  // The part between 'data:' and the comma.
  var mimeType = url.substring(dataPrefix.length, commaIndex);
  const base64Marker = ';base64';
  if (mimeType.endsWith(base64Marker)) {
    mimeType = mimeType.substring(0, mimeType.length - base64Marker.length);
  }
  return mimeType.trim();
}

/// Converts a string in camelCase to lowercase snake_case.
String camelToSnakeCase(String str) =>
    str.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

/// Converts a string in snake_case to camelCase.
String snakeToCamelCase(String str) =>
    str.replaceAllMapped(RegExp('_([a-z0-9])'), (m) => m[1]!.toUpperCase());

/// Converts the keys of [obj] (and of nested maps and lists) to snake_case.
Object? convertObjectKeysToSnakeCase(Object? obj) {
  if (obj is List) return obj.map(convertObjectKeysToSnakeCase).toList();
  if (obj is! Map) return obj;
  return <String, Object?>{
    for (final MapEntry(:key, :value) in obj.entries)
      camelToSnakeCase(key as String): convertObjectKeysToSnakeCase(value),
  };
}

/// [val] with its keys in snake_case, or an empty map if it isn't a map.
Map<String, Object?> toSnakeCaseObj(Object? val) {
  final snakeVal = convertObjectKeysToSnakeCase(val);
  return snakeVal is Map<String, Object?> ? snakeVal : {};
}

// Small helpers for JS truthiness checks (`if (value)`, `value || x`).

/// Whether [value] is null or an empty string (falsy for a JS string).
bool _isEmpty(Object? value) => value == null || value == '';

/// [value], or null if it's empty (JS `value || undefined`).
String? _nonEmpty(String? value) => _isEmpty(value) ? null : value;

/// Whether [value] is truthy in JS terms.
bool _isTruthy(Object? value) =>
    value != null && value != false && value != '' && value != 0;

/// [a] if it's truthy, otherwise [b] (JS `a || b`).
Object? _or(Object? a, Object? b) => _isTruthy(a) ? a : b;

/// Sets [key] to [value], or removes it when [value] is null.
void _setOrRemove(Map<String, Object?> json, String key, Object? value) {
  if (value == null) {
    json.remove(key);
  } else {
    json[key] = value;
  }
}

/// A deep copy of decoded JSON (maps and lists are copied).
Map<String, Object?> _deepCopy(Map<String, Object?> json) =>
    (jsonDecode(jsonEncode(json)) as Map).cast<String, Object?>();

/// Assembles the final interaction of a stream from its events (JS
/// `getInteractionResponsePromise`).
///
/// Call [add] with each event in order, then read [interaction]. An `error`
/// event never gets here: the SSE parser throws it.
class InteractionStreamAssembler {
  final _json = <String, Object?>{};
  final _steps = <Step?>[];
  final _partialArguments = <int, String>{};

  /// Applies one stream event.
  void add(InteractionSseEvent event) {
    switch (event.eventType) {
      case 'interaction.created' || 'interaction.completed':
        // Merge metadata (id, status, usage, errors, ...) only. Steps are
        // assembled from step.* events, and these events may carry partial
        // or no steps, which must not overwrite them. Use their steps only
        // if none were streamed.
        final interaction = InteractionEvent.fromJson(event.json).interaction;
        if (interaction == null) return;
        _json.addAll({...interaction.json}..remove('steps'));
        final steps = interaction.steps;
        if (steps != null &&
            steps.isNotEmpty &&
            _steps.every((s) => s == null)) {
          _steps
            ..clear()
            ..addAll(steps);
        }
      case 'interaction.status_update':
        _setOrRemove(
          _json,
          'status',
          InteractionStatusUpdate.fromJson(event.json).status,
        );
      case 'step.start' || 'step.delta' || 'step.stop':
        applyInteractionStepEvent(_steps, _partialArguments, event);
    }
  }

  /// The interaction assembled so far.
  GeminiInteraction get interaction {
    final result = GeminiInteraction.fromJson({..._json});
    if (_steps.isNotEmpty) {
      // JS keeps a sparse array; indexes never started are left out here.
      result.steps = [for (final step in _steps) ?step];
    }
    return result;
  }
}

/// Hints for config fields the Interactions API doesn't support.
const _droppedConfigFieldHints = {
  'thinkingConfig.thinkingBudget':
      " Use thinkingConfig.thinkingLevel ('LOW' | 'MEDIUM' | 'HIGH') instead.",
};

/// `model:field` pairs that have already been warned about.
final _warnedDroppedConfigFields = <String>{};

/// Warns (once per model and field) that a config field isn't supported by
/// the model and was ignored.
void warnDroppedConfigField(String model, String field) {
  if (!_warnedDroppedConfigFields.add('$model:$field')) return;
  logger.warning(
    "$field is not supported by '$model' and was ignored."
    '${_droppedConfigFieldHints[field] ?? ''}',
  );
}

/// Forgets which dropped config fields were warned about.
@visibleForTesting
void resetDroppedConfigFieldWarnings() => _warnedDroppedConfigFields.clear();

/// Inserts raw audio bytes at the end of a WAV file's `data` chunk and
/// updates the RIFF and `data` sizes. Chunks after `data` (the server sends
/// one) stay after the audio. Returns null if [wav] isn't a WAV file with a
/// `data` chunk.
Uint8List? appendToWavData(Uint8List wav, Uint8List audio) {
  String ascii(int start, int end) =>
      String.fromCharCodes(wav.sublist(start, end));
  if (wav.length < 12 || ascii(0, 4) != 'RIFF' || ascii(8, 12) != 'WAVE') {
    return null;
  }
  final view = ByteData.sublistView(wav);
  // Walk the chunks: each is a 4-byte id, a 4-byte little-endian size, then
  // the data, padded to an even length.
  var offset = 12;
  while (offset + 8 <= wav.length) {
    final id = ascii(offset, offset + 4);
    final size = view.getUint32(offset + 4, Endian.little);
    final dataStart = offset + 8;
    if (id == 'data') {
      final dataEnd = math.min(dataStart + size, wav.length);
      final result =
          (BytesBuilder(copy: false)
                ..add(Uint8List.sublistView(wav, 0, dataEnd))
                ..add(audio)
                ..add(Uint8List.sublistView(wav, dataEnd)))
              .takeBytes();
      ByteData.sublistView(result)
        ..setUint32(offset + 4, size + audio.length, Endian.little)
        ..setUint32(4, result.length - 8, Endian.little);
      return result;
    }
    offset = dataStart + size + (size % 2);
  }
  return null;
}

/// Returns [bytes] without any ID3v2 tags at the start. A tag is only
/// removed if its header is valid ("ID3", version 2-4, size bytes below
/// 0x80) and the whole tag fits in [bytes]; otherwise [bytes] itself is
/// returned (the same object, so callers can tell nothing changed).
Uint8List stripLeadingId3Tags(Uint8List bytes) {
  var start = 0;
  while (start + 10 <= bytes.length) {
    final b = Uint8List.sublistView(bytes, start);
    final isTag =
        b[0] == 0x49 && // I
        b[1] == 0x44 && // D
        b[2] == 0x33 && // 3
        b[3] >= 2 &&
        b[3] <= 4 &&
        b[4] != 0xff &&
        b[6] < 0x80 &&
        b[7] < 0x80 &&
        b[8] < 0x80 &&
        b[9] < 0x80;
    if (!isTag) break;
    // The size is "syncsafe" (7 bits per byte) and excludes the 10-byte
    // header and the optional 10-byte footer (flag 0x10).
    final size = (b[6] << 21) | (b[7] << 14) | (b[8] << 7) | b[9];
    final tagLength = 10 + size + ((b[5] & 0x10) != 0 ? 10 : 0);
    if (tagLength > b.length) break;
    start += tagLength;
  }
  return start == 0 ? bytes : Uint8List.sublistView(bytes, start);
}
