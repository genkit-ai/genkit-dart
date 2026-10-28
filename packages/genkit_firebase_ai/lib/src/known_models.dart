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

// The catalog only decides which models are registered up front so they show
// in the Developer UI; any other name still resolves on demand. Entries follow
// https://firebase.google.com/docs/ai-logic/models and change with it in any
// release, so the enum is not exported.

import 'package:genkit/plugin.dart';

/// What a model generates, which decides its capabilities.
enum ModelFamily {
  /// Conversational text models.
  text,

  /// Image-generating models (`*-image*`, Nano Banana).
  image,

  /// Text-to-speech models (`*-tts*`).
  tts,

  /// Live (bidi) models.
  live;

  /// The family of a bare model name outside the catalog. [live] is true for
  /// a model resolved as a bidi model.
  static ModelFamily of(String modelName, {bool live = false}) {
    if (live) return ModelFamily.live;
    if (modelName.contains('-tts')) return tts;
    if (modelName.contains('-image') || modelName.contains('nano-banana')) {
      return image;
    }
    return text;
  }

  /// The capabilities a model of this family advertises.
  Map<String, dynamic> get supports => switch (this) {
    text => _textSupports,
    image => _imageSupports,
    tts => _ttsSupports,
    live => _liveSupports,
  };
}

// Unmodifiable, since one instance backs many models' metadata.
final _textSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
  'constrained': true,
});

/// Image models take text and images and return both, without tools or
/// constrained output.
final _imageSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': false,
  'toolChoice': false,
  'systemRole': true,
  'constrained': false,
  'output': List<String>.unmodifiable(['text', 'media']),
});

/// Text-to-speech models turn one text prompt into audio.
final _ttsSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': false,
  'media': false,
  'tools': false,
  'toolChoice': false,
  'systemRole': false,
  'constrained': false,
  'output': List<String>.unmodifiable(['media']),
});

/// Live models stream text and audio both ways and can call tools.
final _liveSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': false,
  'systemRole': true,
  'constrained': false,
  'output': List<String>.unmodifiable(['text', 'media']),
});

/// The [ModelInfo] for [modelName]: its catalog entry's, or one built from
/// the name's family for a model outside the catalog.
ModelInfo modelInfoFor(String modelName, {bool live = false}) {
  for (final model in KnownFirebaseAiModel.values) {
    if (model.id == modelName && model.live == live) return model.info;
  }
  return ModelInfo(supports: ModelFamily.of(modelName, live: live).supports);
}

/// The Gemini API backends a model is served on.
enum ModelBackend {
  /// Both the Gemini Developer API and Agent Platform.
  any,

  /// Only the Gemini Developer API.
  developerApi,

  /// Only Agent Platform.
  agentPlatform,
}

/// Models Firebase AI Logic serves, registered when the plugin starts.
enum KnownFirebaseAiModel {
  geminiFlashLatest('gemini-flash-latest', 'Gemini Flash Latest'),
  gemini4Argon('gemini-4-argon', 'Gemini 4 Argon'),
  gemini38Flash('gemini-3.8-flash', 'Gemini 3.8 Flash'),
  gemini37Flash('gemini-3.7-flash', 'Gemini 3.7 Flash'),
  gemini36Flash('gemini-3.6-flash', 'Gemini 3.6 Flash'),
  gemini35Flash('gemini-3.5-flash', 'Gemini 3.5 Flash'),
  gemini35FlashLite('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  gemini31FlashLite('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  gemini3FlashPreview(
    'gemini-3-flash-preview',
    'Gemini 3 Flash Preview',
    preview: true,
  ),
  gemini31ProPreview(
    'gemini-3.1-pro-preview',
    'Gemini 3.1 Pro Preview',
    preview: true,
  ),
  geminiNanoBanana21(
    'gemini-nano-banana-2.1',
    'Nano Banana 2.1',
    family: .image,
  ),
  gemini31FlashImage(
    'gemini-3.1-flash-image',
    'Gemini 3.1 Flash Image',
    family: .image,
  ),
  gemini31FlashLiteImage(
    'gemini-3.1-flash-lite-image',
    'Gemini 3.1 Flash Lite Image',
    family: .image,
  ),
  gemini3ProImage('gemini-3-pro-image', 'Gemini 3 Pro Image', family: .image),
  gemini31FlashTtsPreview(
    'gemini-3.1-flash-tts-preview',
    'Gemini 3.1 Flash TTS Preview',
    family: .tts,
    preview: true,
  ),
  gemini31FlashLivePreview(
    'gemini-3.1-flash-live-preview',
    'Gemini 3.1 Flash Live Preview',
    family: .live,
    preview: true,
    backend: .developerApi,
  ),
  gemini25FlashNativeAudioPreview(
    'gemini-2.5-flash-native-audio-preview-12-2025',
    'Gemini 2.5 Flash Native Audio Preview',
    family: .live,
    preview: true,
    backend: .developerApi,
  ),
  geminiLive25FlashNativeAudio(
    'gemini-live-2.5-flash-native-audio',
    'Gemini Live 2.5 Flash Native Audio',
    family: .live,
    backend: .agentPlatform,
  );

  const KnownFirebaseAiModel(
    this.id,
    this.label, {
    this.family = .text,
    this.preview = false,
    this.backend = .any,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label shown in the Developer UI.
  final String label;

  /// What this model generates.
  final ModelFamily family;

  /// Whether Firebase lists this model as a preview.
  final bool preview;

  /// Whether this is a Live (bidi) model.
  bool get live => family == .live;

  /// The backends this model is served on.
  final ModelBackend backend;

  /// The metadata this model advertises.
  ModelInfo get info => ModelInfo(
    label: label,
    stage: preview ? 'unstable' : 'stable',
    supports: family.supports,
  );

  /// Whether this model is served when the plugin uses Agent Platform
  /// ([agentPlatform] true) or the Gemini Developer API.
  bool servedOn({required bool agentPlatform}) => switch (backend) {
    .any => true,
    .developerApi => !agentPlatform,
    .agentPlatform => agentPlatform,
  };
}
