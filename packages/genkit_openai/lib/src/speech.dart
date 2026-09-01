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

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'utils.dart';

part 'speech.g.dart';

/// Speech-specific options for OpenAI text-to-speech models.
@Schema()
abstract class $OpenAISpeechOptions {
  /// Model version override (e.g., 'tts-1-1106')
  String? get version;

  /// Voice used to render the audio (e.g. 'alloy', 'sage', 'coral').
  ///
  /// Left free-form on purpose: OpenAI adds voices without warning, and an
  /// enum here would reject them until the plugin shipped a new release.
  /// Defaults to 'alloy' when unset.
  String? get voice;

  /// Tone and delivery guidance, e.g. 'Speak in a calm, warm tone.'
  ///
  /// Only honored by `gpt-4o-mini-tts`; the `tts-1` family ignores it.
  String? get instructions;

  /// Playback speed multiplier (0.25 - 4.0).
  ///
  /// Accepted by every speech model; the OpenAPI spec attaches no model
  /// restriction, and it states them where they exist.
  @DoubleField(minimum: 0.25, maximum: 4.0)
  double? get speed;

  /// Audio container for the generated speech. Defaults to 'mp3'.
  @StringField(enumValues: ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'])
  String? get responseFormat;
}

/// Maps an OpenAI speech `response_format` to the MIME type used on the
/// returned [MediaPart].
///
/// This is the only description of the bytes a caller ever sees — the type is
/// derived from the format that was requested, since `openai_dart` hands back
/// bytes with no response headers — so two of these are worth spelling out.
///
/// `opus` is Ogg-encapsulated, and `audio/ogg` is the registered type for
/// that; `audio/opus` is unregistered and browsers refuse to play it. `pcm` is
/// deliberately not `audio/L16`: that type is defined big-endian and defaults
/// to 8 kHz, while OpenAI returns little-endian 24 kHz samples, so a consumer
/// decoding to spec would get static at the wrong rate.
const Map<String, String> speechResponseFormatMediaTypes = {
  'mp3': 'audio/mpeg',
  'opus': 'audio/ogg',
  'aac': 'audio/aac',
  'flac': 'audio/flac',
  'wav': 'audio/wav',
  'pcm': 'audio/pcm',
};

/// Speech models registered eagerly, even when absent from `GET /models`.
const List<String> knownSpeechModels = ['tts-1', 'tts-1-hd', 'gpt-4o-mini-tts'];

/// Default audio container when the caller does not pick one.
const String defaultSpeechResponseFormat = 'mp3';

/// Default voice when the caller does not pick one.
const String defaultSpeechVoice = 'alloy';

/// Returns true when [modelId] is a text-to-speech model.
///
/// The name is the whole test. [getModelType] already answers `audio` for
/// anything containing `tts`, so that half never decides a case on its own —
/// it is kept as a guard for the day the classifier splits the audio bucket
/// into synthesis and transcription, which is what `whisper` support needs.
bool isSpeechModel(String modelId) {
  return getModelType(modelId) == 'audio' &&
      modelId.toLowerCase().contains('tts');
}

/// Returns true when [info] declares audio output and nothing else.
///
/// Speech models on OpenAI-compatible providers are not always named `*tts*`,
/// so a caller registering one through `CustomModelDefinition` says so with
/// `supports: {'output': ['media']}`. That declaration is the only signal
/// available for those models.
///
/// Exclusivity, not membership: `supports.output` is free-form, so a chat
/// model may legitimately declare `['text', 'json', 'media']`, and treating
/// that as speech would route every call to `/audio/speech` and hand the
/// caller an empty `response.text`. Only a model that produces media and
/// nothing else can be one.
bool declaresMediaOutput(ModelInfo? info) {
  final output = info?.supports?['output'];
  return output is List && output.length == 1 && output.first == 'media';
}

/// Validates the options a speech request carries.
///
/// The schema annotations are documentation, not enforcement: schemantic's
/// `parse` accepts any string for `responseFormat` and any double for `speed`,
/// so an unknown container reaches `SpeechResponseFormat.fromJson` and throws
/// a `FormatException` that surfaces as INTERNAL — the plugin blaming itself
/// for the caller's typo — and a `speed` of 99 reaches the wire.
void validateSpeechOptions(OpenAISpeechOptions options) {
  final format = options.responseFormat;
  if (format != null && !speechResponseFormatMediaTypes.containsKey(format)) {
    throw GenkitException(
      'Unknown responseFormat "$format". Accepted formats: '
      '${speechResponseFormatMediaTypes.keys.join(', ')}.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final speed = options.speed;
  if (speed != null && (speed < 0.25 || speed > 4.0)) {
    throw GenkitException(
      'speed must be between 0.25 and 4.0; got $speed.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// Capability metadata for a text-to-speech model.
///
/// Speech models take text in and hand back a single audio [MediaPart], so
/// they advertise `output: ['media']` and opt out of everything conversational.
ModelInfo speechModelInfo(String modelId) {
  return ModelInfo(
    label: modelId,
    supports: {
      'media': false,
      'output': ['media'],
      'multiturn': false,
      'systemRole': false,
      'tools': false,
    },
  );
}

/// Returns custom options schema for speech models.
SchemanticType<OpenAISpeechOptions> speechModelOptionsSchema() =>
    OpenAISpeechOptions.$schema;

/// Parses speech-model options from action config.
OpenAISpeechOptions parseSpeechModelOptions(Map<String, dynamic>? config) {
  return config != null
      ? OpenAISpeechOptions.$schema.parse(config)
      : OpenAISpeechOptions();
}
