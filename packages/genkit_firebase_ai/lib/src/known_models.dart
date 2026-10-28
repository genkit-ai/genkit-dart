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
  geminiFlashLatest('gemini-flash-latest'),
  gemini4Argon('gemini-4-argon'),
  gemini38Flash('gemini-3.8-flash'),
  gemini37Flash('gemini-3.7-flash'),
  gemini36Flash('gemini-3.6-flash'),
  gemini35Flash('gemini-3.5-flash'),
  gemini35FlashLite('gemini-3.5-flash-lite'),
  gemini31FlashLite('gemini-3.1-flash-lite'),
  gemini3FlashPreview('gemini-3-flash-preview'),
  gemini31ProPreview('gemini-3.1-pro-preview'),
  geminiNanoBanana21('gemini-nano-banana-2.1'),
  gemini31FlashImage('gemini-3.1-flash-image'),
  gemini31FlashLiteImage('gemini-3.1-flash-lite-image'),
  gemini3ProImage('gemini-3-pro-image'),
  gemini31FlashTtsPreview('gemini-3.1-flash-tts-preview'),
  gemini31FlashLivePreview(
    'gemini-3.1-flash-live-preview',
    live: true,
    backend: .developerApi,
  ),
  gemini25FlashNativeAudioPreview(
    'gemini-2.5-flash-native-audio-preview-12-2025',
    live: true,
    backend: .developerApi,
  ),
  geminiLive25FlashNativeAudio(
    'gemini-live-2.5-flash-native-audio',
    live: true,
    backend: .agentPlatform,
  );

  const KnownFirebaseAiModel(this.id, {this.live = false, this.backend = .any});

  /// Bare model name (no plugin prefix).
  final String id;

  /// Whether this is a Live (bidi) model.
  final bool live;

  /// The backends this model is served on.
  final ModelBackend backend;

  /// Whether this model is served when the plugin uses Agent Platform
  /// ([agentPlatform] true) or the Gemini Developer API.
  bool servedOn({required bool agentPlatform}) => switch (backend) {
    .any => true,
    .developerApi => !agentPlatform,
    .agentPlatform => agentPlatform,
  };
}
