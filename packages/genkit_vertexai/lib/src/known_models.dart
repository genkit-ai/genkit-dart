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
/// step with the JS plugin's vertexAI lists (KNOWN_*_MODELS and HIDDEN_MODELS
/// in js/plugins/google-genai/src/vertexai/gemini.ts): same names, same
/// stages, same routing. Newer JS models not listed here yet still resolve
/// and route the same way (see [vertexUsesInteractions]).
///
/// Two things stay out:
/// - Gemma, which Vertex serves through Model Garden rather than as a
///   publisher Gemini model; it still resolves on the Gemini path.
/// - TTS, which Vertex serves under IDs of its own (`gemini-2.5-flash-tts`).
///   Vertex TTS names still get the TTS profile through `modelInfoFor`.
// Only list a model when the entry changes something: its metadata, its
// stage or its routing. `gemini-3.6-flash` is left out, as in JS (it shuts
// down Nov 19 2026); unlisted, it uses the Interactions API.
enum KnownVertexGeminiModel {
  gemini38Flash('gemini-3.8-flash', 'Gemini 3.8 Flash'),
  // Allowlist only.
  gemini38FlashCyber(
    'gemini-3.8-flash-cyber',
    'Gemini 3.8 Flash Cyber',
    interactions: false,
  ),
  gemini37Flash('gemini-3.7-flash', 'Gemini 3.7 Flash'),
  gemini35FlashLite('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  gemini35Flash('gemini-3.5-flash', 'Gemini 3.5 Flash', interactions: false),
  gemini31FlashLite(
    'gemini-3.1-flash-lite',
    'Gemini 3.1 Flash Lite',
    interactions: false,
  ),
  gemini31ProPreview(
    'gemini-3.1-pro-preview',
    'Gemini 3.1 Pro Preview',
    interactions: false,
  ),
  // Optimized for custom tools (an extra endpoint of 3.1 Pro).
  gemini31ProPreviewCustomtools(
    'gemini-3.1-pro-preview-customtools',
    'Gemini 3.1 Pro Preview Custom Tools',
    interactions: false,
  ),
  gemini3FlashPreview(
    'gemini-3-flash-preview',
    'Gemini 3 Flash Preview',
    interactions: false,
  ),

  // Image models stay on generateContent: the platform's Interactions API
  // doesn't support them (see [vertexUsesInteractions]).
  gemini31FlashLiteImage(
    'gemini-3.1-flash-lite-image',
    'Gemini 3.1 Flash Lite Image',
    family: .image,
    interactions: false,
  ),
  gemini31FlashImage(
    'gemini-3.1-flash-image',
    'Gemini 3.1 Flash Image',
    family: .image,
    interactions: false,
  ),
  gemini3ProImage(
    'gemini-3-pro-image',
    'Gemini 3 Pro Image',
    family: .image,
    interactions: false,
  ),
  gemini25FlashImage(
    'gemini-2.5-flash-image',
    'Gemini 2.5 Flash Image',
    family: .image,
    interactions: false,
  ),

  // Hidden (JS HIDDEN_MODELS): no longer suggested, but still served. They
  // still resolve and are still listed, with their stage. Retirement date
  // Oct 20 2026; kept until the server stops serving them. They aren't on
  // the Interactions API, so they must stay listed: unlisted names would be
  // sent to the Interactions API.
  gemini25Pro(
    'gemini-2.5-pro',
    'Gemini 2.5 Pro',
    stage: .deprecated,
    interactions: false,
  ),
  gemini25Flash(
    'gemini-2.5-flash',
    'Gemini 2.5 Flash',
    stage: .deprecated,
    interactions: false,
  ),
  gemini25FlashLite(
    'gemini-2.5-flash-lite',
    'Gemini 2.5 Flash Lite',
    stage: .deprecated,
    interactions: false,
  );

  const KnownVertexGeminiModel(
    this.id,
    this.label, {
    this.family = .text,
    this.stage = .stable,
    this.interactions = true,
  });

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The modality this model generates in.
  final GeminiModelFamily family;

  /// The lifecycle stage this model is listed with.
  final GeminiModelStage stage;

  /// Whether this model is called through the Interactions API rather than
  /// generateContent (the 4th argument of JS `commonRef`).
  final bool interactions;

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

/// Whether each curated vertexAI model is called through the Interactions
/// API, keyed by bare model name.
final vertexAiKnownInteractions = Map<String, bool>.unmodifiable({
  for (final model in KnownVertexGeminiModel.values)
    model.id: model.interactions,
});

/// Whether [modelName] is called through the Interactions API on the
/// Gemini Enterprise Agent Platform (JS vertexai `usesInteractions`).
///
/// Curated models use their [KnownVertexGeminiModel.interactions] flag.
/// Other names use the Interactions API, except image and TTS models: the
/// platform's Interactions API doesn't support them (it returns 400 "Model
/// '...' is not supported by the Interactions API"; checked live by the JS
/// plugin, Oct 2026), so they stay on generateContent.
bool vertexUsesInteractions(String modelName) =>
    vertexAiKnownInteractions[modelName] ??
    switch (GeminiModelFamily.of(modelName)) {
      .image || .tts => false,
      .text || .video => true,
    };
