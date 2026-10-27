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
import 'package:genkit_google_genai/common.dart';

/// Gemini models the Vertex AI plugin curates capability metadata for.
///
/// Its own list, not derived from the Gemini API (googleAI) catalog: models
/// come and go differently on the two endpoints, and their stages and routing
/// differ (e.g. `gemini-3.5-flash` is hidden on googleAI but not here). Kept in
/// step with the JS plugin's vertexAI lists
/// (js/plugins/google-genai/src/vertexai/gemini.ts).
///
/// Two things stay out:
/// - Gemma, which Vertex serves through Model Garden rather than as a
///   publisher Gemini model; it still resolves on the Gemini path.
/// - TTS, which Vertex serves under IDs of its own (`gemini-2.5-flash-tts`).
///   Vertex TTS names still get the TTS profile through `modelInfoFor`.
// TODO: bring stages, hidden models and routing in line with the JS vertexAI
// plugin when vertexAI moves to the Interactions API.
enum KnownVertexGeminiModel {
  gemini31ProPreview('gemini-3.1-pro-preview', 'Gemini 3.1 Pro Preview'),
  gemini3FlashPreview('gemini-3-flash-preview', 'Gemini 3 Flash Preview'),
  gemini38Flash('gemini-3.8-flash', 'Gemini 3.8 Flash'),
  gemini37Flash('gemini-3.7-flash', 'Gemini 3.7 Flash'),
  gemini36Flash('gemini-3.6-flash', 'Gemini 3.6 Flash'),
  gemini35Flash('gemini-3.5-flash', 'Gemini 3.5 Flash'),
  gemini35FlashLite('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  gemini31FlashLite('gemini-3.1-flash-lite', 'Gemini 3.1 Flash Lite'),
  gemini25Pro('gemini-2.5-pro', 'Gemini 2.5 Pro'),
  gemini25Flash('gemini-2.5-flash', 'Gemini 2.5 Flash'),
  gemini25FlashLite('gemini-2.5-flash-lite', 'Gemini 2.5 Flash Lite'),
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
  gemini25FlashImage(
    'gemini-2.5-flash-image',
    'Gemini 2.5 Flash Image',
    family: .image,
  );

  const KnownVertexGeminiModel(this.id, this.label, {this.family = .text});

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The modality this model generates in.
  final GeminiModelFamily family;

  /// The lifecycle stage this model is listed with.
  // Every vertexAI model is listed as stable for now. Make this a constructor
  // parameter, as in genkit_google_genai's KnownGeminiModel, when vertexAI
  // gets hidden models (see the TODO above).
  GeminiModelStage get stage => .stable;

  /// Whether this model is no longer suggested (JS `HIDDEN_MODELS`).
  bool get hidden => stage != .stable;

  /// The capability profile for this model.
  ModelInfo get info =>
      ModelInfo(label: label, supports: family.supports, stage: stage.wireName);
}

/// Curated capability metadata for the Vertex AI plugin, keyed by bare model
/// name.
///
/// Derived from [KnownVertexGeminiModel]. Any other model name still resolves
/// dynamically with the common fallback metadata; these entries only give the
/// listed models accurate per-model `supports` and keep them in listings even
/// when model discovery omits them.
final vertexAiKnownModels = Map<String, ModelInfo>.unmodifiable({
  for (final model in KnownVertexGeminiModel.values) model.id: model.info,
});
