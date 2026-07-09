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
  ///
  /// Mirrors the `Multimodal` preset the Go plugin uses for its curated model
  /// list: multiturn chat, media input/output, tool calling with tool choice,
  /// a system role, and native constrained generation.
  ModelInfo get info => ModelInfo(
    label: label,
    // Unmodifiable: curated entries are shared across every resolution of the
    // model, so accidental mutation through action metadata must fail loudly.
    supports: Map.unmodifiable({
      'multiturn': true,
      'media': true,
      'tools': true,
      'toolChoice': true,
      'systemRole': true,
      'constrained': true,
    }),
    stage: 'stable',
  );
}

/// Curated capability metadata for known Gemini models, keyed by bare model
/// name (no plugin prefix).
///
/// Derived from [KnownGeminiModel]; models are still resolved from raw strings,
/// this map only enriches known names with per-model metadata instead of the
/// shared `commonModelInfo` fallback. Plugins expose a subset via
/// `CommonGoogleGenPlugin.knownModels`.
final knownGeminiModels = <String, ModelInfo>{
  for (final model in KnownGeminiModel.values) model.id: model.info,
};
