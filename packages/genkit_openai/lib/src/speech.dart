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
  /// Not supported by `gpt-4o-mini-tts`, which rejects the field outright.
  @DoubleField(minimum: 0.25, maximum: 4.0)
  double? get speed;

  /// Audio container for the generated speech. Defaults to 'mp3'.
  @StringField(enumValues: ['mp3', 'opus', 'aac', 'flac', 'wav', 'pcm'])
  String? get responseFormat;
}

/// Maps an OpenAI speech `response_format` to the MIME type used on the
/// returned [MediaPart].
const Map<String, String> speechResponseFormatMediaTypes = {
  'mp3': 'audio/mpeg',
  'opus': 'audio/opus',
  'aac': 'audio/aac',
  'flac': 'audio/flac',
  'wav': 'audio/wav',
  'pcm': 'audio/L16',
};

/// Speech models registered eagerly, even when absent from `GET /models`.
const List<String> knownSpeechModels = ['tts-1', 'tts-1-hd', 'gpt-4o-mini-tts'];

/// Default audio container when the caller does not pick one.
const String defaultSpeechResponseFormat = 'mp3';

/// Default voice when the caller does not pick one.
const String defaultSpeechVoice = 'alloy';

/// Returns true when [modelId] is a text-to-speech model.
///
/// [getModelType] lumps every audio model together, so the extra `tts` check
/// is what separates speech synthesis from transcription (`whisper-1`,
/// `gpt-4o-transcribe`), realtime, and audio-in chat models.
bool isSpeechModel(String modelId) {
  return getModelType(modelId) == 'audio' &&
      modelId.toLowerCase().contains('tts');
}

/// Returns true when [info] declares audio output.
///
/// Speech models on OpenAI-compatible providers are not always named
/// `*tts*`, so a caller registering one through `CustomModelDefinition` says
/// so with `supports: {'output': ['media']}`. That declaration is the only
/// signal available for those models.
bool declaresMediaOutput(ModelInfo? info) {
  final output = info?.supports?['output'];
  return output is List && output.contains('media');
}

/// Returns true when [modelId] rejects the `speed` parameter.
bool speechModelRejectsSpeed(String modelId) {
  return modelId.toLowerCase().contains('gpt-4o-mini-tts');
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
