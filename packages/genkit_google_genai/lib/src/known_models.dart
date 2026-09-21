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

import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

import 'model.dart';

/// The multimodal capability profile curated text and image models advertise.
///
/// Mirrors the `Multimodal` preset the Go plugin uses for its curated model
/// list: multiturn chat, media input/output, tool calling with tool choice, a
/// system role, and native constrained generation.
// Unmodifiable: one instance backs every curated model in both enums, so
// accidental mutation through action metadata must fail loudly.
final _multimodalSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
  'constrained': true,
});

/// The capability profile every `-tts` Gemini model advertises, curated or
/// not.
///
/// Text-to-speech models emit audio only: no multiturn history, no media
/// input, no tools, no system role and no constrained generation.
final geminiTtsSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': false,
  'media': false,
  'tools': false,
  'toolChoice': false,
  'systemRole': false,
  'constrained': false,
  'output': List<String>.unmodifiable(['media']),
});

/// The generation modality a Gemini model name denotes.
///
/// The family decides which capability profile and which options schema a
/// model gets, whether or not the name is curated.
enum GeminiModelFamily {
  /// Conversational text models, including Gemma.
  text,

  /// Image-generating models (`gemini-*-image*`).
  image,

  /// Text-to-speech models (`gemini-*-tts*`).
  tts;

  /// Classifies a bare model name by its Gemini modality marker.
  ///
  /// `-tts` wins over `-image`, and any name outside the `gemini-` namespace
  /// is text.
  static GeminiModelFamily of(String modelName) {
    if (!modelName.startsWith('gemini-')) return text;
    if (modelName.contains('-tts')) return tts;
    if (modelName.contains('-image')) return image;
    return text;
  }

  /// The capability profile a model of this family advertises.
  Map<String, dynamic> get supports => switch (this) {
    text || image => _multimodalSupports,
    tts => geminiTtsSupports,
  };

  /// The request options schema a model of this family accepts.
  SchemanticType get customOptions => switch (this) {
    text || image => GeminiOptions.$schema,
    tts => GeminiTtsOptions.$schema,
  };
}

/// Gemini models the Google generative-AI plugins curate capability metadata
/// for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label], a [family] and a [stage]; [info] builds the capability preset for
/// that family. Other model names still resolve dynamically via the plugin's
/// `modelInfoFor` fallback, so this enum only enriches the names listed here.
enum KnownGeminiModel {
  gemini25Pro('gemini-2.5-pro', 'Gemini 2.5 Pro', stage: 'unstable'),
  gemini25Flash('gemini-2.5-flash', 'Gemini 2.5 Flash', stage: 'unstable'),
  gemini25FlashLite(
    'gemini-2.5-flash-lite',
    'Gemini 2.5 Flash Lite',
    stage: 'unstable',
  ),
  gemini31ProPreview(
    'gemini-3.1-pro-preview',
    'Gemini 3.1 Pro Preview',
    stage: 'unstable',
  ),
  gemini3FlashPreview(
    'gemini-3-flash-preview',
    'Gemini 3 Flash Preview',
    stage: 'unstable',
  ),
  gemini37Flash('gemini-3.7-flash', 'Gemini 3.7 Flash', stage: 'unstable'),
  gemini36Flash('gemini-3.6-flash', 'Gemini 3.6 Flash', stage: 'unstable'),
  gemini35Flash('gemini-3.5-flash', 'Gemini 3.5 Flash', stage: 'stable'),
  gemini35FlashLite(
    'gemini-3.5-flash-lite',
    'Gemini 3.5 Flash Lite',
    stage: 'unstable',
  ),
  gemini31FlashLite(
    'gemini-3.1-flash-lite',
    'Gemini 3.1 Flash Lite',
    stage: 'stable',
  ),
  gemini25FlashImage(
    'gemini-2.5-flash-image',
    'Gemini 2.5 Flash Image',
    family: .image,
    stage: 'unstable',
  ),
  gemini31FlashImage(
    'gemini-3.1-flash-image',
    'Gemini 3.1 Flash Image',
    family: .image,
    stage: 'stable',
  ),
  gemini31FlashLiteImage(
    'gemini-3.1-flash-lite-image',
    'Gemini 3.1 Flash Lite Image',
    family: .image,
    stage: 'unstable',
  ),
  gemini3ProImage(
    'gemini-3-pro-image',
    'Gemini 3 Pro Image',
    family: .image,
    stage: 'stable',
  ),
  gemini25FlashPreviewTts(
    'gemini-2.5-flash-preview-tts',
    'Gemini 2.5 Flash Preview TTS',
    family: .tts,
    stage: 'unstable',
  ),
  gemini25ProPreviewTts(
    'gemini-2.5-pro-preview-tts',
    'Gemini 2.5 Pro Preview TTS',
    family: .tts,
    stage: 'unstable',
  ),
  gemini31FlashTtsPreview(
    'gemini-3.1-flash-tts-preview',
    'Gemini 3.1 Flash TTS Preview',
    family: .tts,
    stage: 'unstable',
  );

  const KnownGeminiModel(
    this.id,
    this.label, {
    this.family = .text,
    required this.stage,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The modality this model generates in.
  final GeminiModelFamily family;

  /// Lifecycle stage surfaced in listings.
  ///
  /// `stable` is only claimed for names a live `ListModels` probe has served;
  /// every other curated name is `unstable`.
  final String stage;

  /// The capability profile for this model.
  ModelInfo get info =>
      ModelInfo(label: label, supports: family.supports, stage: stage);
}

/// Gemma models the Gemini API serves, curated the same way as
/// [KnownGeminiModel].
enum KnownGemmaModel {
  gemma431b('gemma-4-31b-it', 'Gemma 4 31B'),
  gemma426bA4b('gemma-4-26b-a4b-it', 'Gemma 4 26B A4B');

  const KnownGemmaModel(this.id, this.label);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The multimodal capability profile for this model.
  ModelInfo get info =>
      ModelInfo(label: label, supports: _multimodalSupports, stage: 'stable');
}

/// Curated capability metadata for the Gemini and Gemma models known to the
/// Google generative-AI plugins, keyed by bare model name (no plugin prefix).
///
/// Derived from [KnownGeminiModel] and [KnownGemmaModel]; models are still
/// resolved from raw strings, this map only enriches known names with per-model
/// metadata instead of the shared `commonModelInfo` fallback. Plugins expose a
/// subset via `CommonGoogleGenPlugin.knownModels`.
final knownGeminiModels = <String, ModelInfo>{
  for (final model in KnownGeminiModel.values) model.id: model.info,
  for (final model in KnownGemmaModel.values) model.id: model.info,
};
