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

part 'transcription.g.dart';

/// Transcription-specific options for OpenAI speech-to-text models.
@Schema()
abstract class $OpenAITranscriptionOptions {
  /// Model version override (e.g., 'whisper-1').
  String? get version;

  /// ISO-639-1 code of the spoken language, e.g. 'en', 'es'.
  ///
  /// Supplying it improves accuracy and latency. Not accepted by the
  /// translation endpoint, which always outputs English.
  String? get language;

  /// Decoding hint: vocabulary, names, or the expected style.
  ///
  /// Distinct from the Genkit prompt. When unset, the text content of the
  /// request message is used instead.
  String? get prompt;

  /// Sampling temperature (0.0 - 1.0).
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get temperature;

  /// Transcript format. Defaults to 'json'.
  ///
  /// 'srt' and 'vtt' return subtitle markup, 'verbose_json' adds timing
  /// metadata. Whatever the format, the transcript is returned as a single
  /// text part; the untouched payload is available on `ModelResponse.raw`.
  @StringField(enumValues: ['json', 'text', 'srt', 'verbose_json', 'vtt'])
  String? get responseFormat;

  /// Timestamp detail to include: 'word' and/or 'segment'.
  ///
  /// Requires `responseFormat: 'verbose_json'`, and is only supported by
  /// `whisper-1`.
  List<String>? get timestampGranularities;

  /// How to split long audio: the string 'auto', or a map such as
  /// `{'type': 'server_vad', 'prefix_padding_ms': 300}`.
  ///
  /// Only supported by the `gpt-4o-transcribe` family.
  Object? get chunkingStrategy;

  /// Extra fields to include in the response, e.g. `['logprobs']`.
  List<String>? get include;

  /// Translate the audio into English instead of transcribing it verbatim.
  ///
  /// Routes to `/audio/translations`, which only `whisper-1` supports.
  bool? get translate;
}

/// Transcript format used when the caller does not pick one.
///
/// The OpenAI default is 'json', which every model supports and which yields
/// a `{"text": ...}` body.
const String defaultTranscriptionResponseFormat = 'json';

/// Transcription models registered eagerly, even when absent from
/// `GET /models`.
const List<String> knownTranscriptionModels = [
  'whisper-1',
  'gpt-4o-transcribe',
  'gpt-4o-mini-transcribe',
];

/// Maps an audio MIME type to the filename sent with the upload.
///
/// OpenAI infers the codec from this filename, so it has to be a real audio
/// extension. A generic `type/subtype` split is not good enough: `audio/x-m4a`
/// would yield `x-m4a`, which the API rejects.
const Map<String, String> _audioMimeExtensions = {
  'audio/flac': 'flac',
  'audio/mp4': 'mp4',
  'audio/mpeg': 'mp3',
  'audio/mpga': 'mpga',
  'audio/m4a': 'm4a',
  'audio/x-m4a': 'm4a',
  'audio/oga': 'oga',
  'audio/ogg': 'ogg',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/webm': 'webm',
};

/// Filename to upload audio of [mimeType] under.
String audioFilenameFor(String mimeType) {
  final ext = _audioMimeExtensions[mimeType.toLowerCase()];
  return ext == null ? 'input' : 'input.$ext';
}

/// Returns true when [modelId] transcribes audio into text.
///
/// [getModelType] returns 'audio' for speech synthesis, realtime and
/// audio-in chat models too, so the name check is what keeps those on their
/// own paths.
bool isTranscriptionModel(String modelId) {
  final id = modelId.toLowerCase();
  return getModelType(modelId) == 'audio' &&
      (id.contains('transcribe') || id.contains('whisper'));
}

/// Returns true when [modelId] can translate audio to English.
///
/// Only the whisper family is served by `/audio/translations`.
bool supportsTranslation(String modelId) {
  return modelId.toLowerCase().contains('whisper');
}

/// Returns true when [info] declares audio input.
///
/// The input-side mirror of `declaresMediaOutput`: a caller registering a
/// transcription model on an OpenAI-compatible provider whose name is not
/// `*whisper*` or `*transcribe*` says so with `supports: {'media': true}`.
bool declaresMediaInput(ModelInfo? info) {
  return info?.supports?['media'] == true;
}

/// Capability metadata for a transcription model.
ModelInfo transcriptionModelInfo(String modelId) {
  return ModelInfo(
    label: modelId,
    supports: {
      'media': true,
      'output': ['text', 'json'],
      'multiturn': false,
      'systemRole': false,
      'tools': false,
    },
  );
}

/// Returns custom options schema for transcription models.
SchemanticType<OpenAITranscriptionOptions> transcriptionModelOptionsSchema() =>
    OpenAITranscriptionOptions.$schema;

/// Parses transcription-model options from action config.
OpenAITranscriptionOptions parseTranscriptionModelOptions(
  Map<String, dynamic>? config,
) {
  return config != null
      ? OpenAITranscriptionOptions.$schema.parse(config)
      : OpenAITranscriptionOptions();
}
