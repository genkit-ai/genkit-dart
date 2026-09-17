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

/// The multimodal capability profile curated models advertise.
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

/// Gemini models the Google generative-AI plugins curate capability metadata
/// for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label]; [info] builds the shared multimodal capability preset. Other model
/// names still resolve dynamically via the plugin's `commonModelInfo`
/// fallback, so this enum only enriches the names listed here.
enum KnownGeminiModel {
  gemini35Flash('gemini-3.5-flash', 'Gemini 3.5 Flash'),
  gemini31FlashLite('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  gemini31FlashImage('gemini-3.1-flash-image', 'Gemini 3.1 Flash Image'),
  gemini3ProImage('gemini-3-pro-image', 'Gemini 3 Pro Image');

  const KnownGeminiModel(this.id, this.label);

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The multimodal capability profile for this model.
  ModelInfo get info =>
      ModelInfo(label: label, supports: _multimodalSupports, stage: 'stable');
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
