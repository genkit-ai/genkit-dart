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

// The curated catalog is internal metadata, not API: it only enriches the
// labels, stages and capabilities of names that resolve anyway. Entries are
// added and removed with the upstream model list in any release, which is why
// neither enum is exported. Callers name models by string
// (`googleAI.gemini('gemini-flash-latest')`).

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

/// The capability profile every video generation model (`gemini-omni-*`)
/// advertises, curated or not (as in the JS plugin).
///
/// Per the Omni guide: text, image and video in, video (with audio) out;
/// edits continue a stored interaction. Tools and structured output aren't
/// documented for video generation. System instructions are applied
/// (checked live by the JS plugin, Oct 2026).
final geminiVideoSupports = Map<String, dynamic>.unmodifiable({
  'multiturn': true,
  'media': true,
  'tools': false,
  'toolChoice': false,
  'systemRole': true,
  'constrained': false,
  'output': List<String>.unmodifiable(['media']),
});

/// The image profile without native constrained generation, for image models
/// whose structured output doesn't work (with a schema they still return
/// only an image; checked live by the JS plugin, Oct 2026). Genkit then asks
/// for JSON in the prompt instead (with the `simulateConstrainedGeneration`
/// middleware).
const _imageWithoutConstrainedSupports = <String, dynamic>{
  'multiturn': true,
  'media': true,
  'tools': true,
  'toolChoice': true,
  'systemRole': true,
  'constrained': false,
};

/// The generation modality a Gemini model name denotes.
///
/// The family decides which capability profile and which options schema a
/// model gets, whether or not the name is curated.
enum GeminiModelFamily {
  /// Conversational text models, including Gemma.
  text,

  /// Image-generating models (`gemini-*-image*` and `gemini-nano-banana-*`).
  image,

  /// Text-to-speech models (`gemini-*-tts*`).
  tts,

  /// Video generation models (`gemini-omni-*`).
  video;

  /// Classifies a bare model name by its Gemini modality marker.
  ///
  /// `-tts` wins over `-image`, Nano Banana names are image models and Omni
  /// names video models (as in the JS plugins), and any name outside the
  /// `gemini-` namespace is text.
  static GeminiModelFamily of(String modelName) {
    if (!modelName.startsWith('gemini-')) return text;
    if (modelName.contains('-tts')) return tts;
    if (modelName.contains('-image') ||
        modelName.startsWith('gemini-nano-banana-')) {
      return image;
    }
    if (modelName.startsWith('gemini-omni-')) return video;
    return text;
  }

  /// The capability profile a model of this family advertises.
  Map<String, dynamic> get supports => switch (this) {
    text || image => _multimodalSupports,
    tts => geminiTtsSupports,
    video => geminiVideoSupports,
  };

  /// The request options schema a model of this family accepts.
  SchemanticType get customOptions => switch (this) {
    text => GeminiOptions.$schema,
    image => GeminiImageOptions.$schema,
    tts => GeminiTtsOptions.$schema,
    video => GeminiVideoOptions.$schema,
  };
}

/// Lifecycle stage of a curated model, in Genkit's `ModelInfo.stage`
/// vocabulary.
///
/// Matches the stages the JS plugin sets on its hidden models. A model that
/// isn't [stable] is "hidden": it still resolves and is still listed, but it
/// is no longer suggested (e.g. samples and docs must not use it).
enum GeminiModelStage {
  /// Generally available.
  stable,

  /// Not deprecated, but no longer offered to new projects: still served to
  /// projects that used it before.
  legacy,

  /// Deprecated by Google, or less than a month from shutdown.
  deprecated;

  /// The `stage` string carried in [ModelInfo].
  String get wireName => name;
}

// Kept in step with the JS plugin's googleAI lists (KNOWN_*_MODELS and
// HIDDEN_MODELS in js/plugins/google-genai/src/googleai/gemini.ts): same names,
// same stages, same routing. genkit_vertexai keeps its own list, because models
// come and go differently on the two endpoints.
//
// Only list a model when the entry changes something: its metadata, its stage
// or its routing. A deprecated model that already routes the right way when
// unlisted (e.g. gemini-3.7-flash, whose endpoint now serves gemini-3.8-flash)
// is left out, as in JS.

/// Gemini models the Gemini API (googleAI) plugin curates capability metadata
/// for.
///
/// Each value pairs a bare model [id] (no plugin prefix) with a display
/// [label], a [family], a lifecycle [stage] and whether it is called through
/// the Interactions API ([interactions]); [info] builds the capability preset
/// for that family. Other model names still resolve dynamically via the
/// plugin's `modelInfoFor` fallback, so this enum only enriches the names
/// listed here.
enum KnownGeminiModel {
  geminiProLatest('gemini-pro-latest', 'Gemini Pro (latest)'),
  geminiFlashLatest('gemini-flash-latest', 'Gemini Flash (latest)'),
  geminiFlashLiteLatest(
    'gemini-flash-lite-latest',
    'Gemini Flash Lite (latest)',
  ),
  gemini4Argon('gemini-4-argon', 'Gemini 4 Argon'),
  gemini38Flash('gemini-3.8-flash', 'Gemini 3.8 Flash'),
  gemini36Flash('gemini-3.6-flash', 'Gemini 3.6 Flash'),
  gemini35FlashLite('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite'),
  gemini31FlashLite(
    'gemini-3.1-flash-lite',
    'Gemini 3.1 Flash Lite',
    interactions: false,
  ),
  gemini31ProPreviewCustomTools(
    'gemini-3.1-pro-preview-customtools',
    'Gemini 3.1 Pro Preview Custom Tools',
    interactions: false,
  ),
  gemini31ProPreview(
    'gemini-3.1-pro-preview',
    'Gemini 3.1 Pro Preview',
    interactions: false,
  ),
  gemini3FlashPreview(
    'gemini-3-flash-preview',
    'Gemini 3 Flash Preview',
    interactions: false,
  ),
  gemini31FlashLiteImage(
    'gemini-3.1-flash-lite-image',
    'Gemini 3.1 Flash Lite Image',
    family: .image,
  ),
  geminiNanoBanana21(
    'gemini-nano-banana-2.1',
    'Nano Banana 2.1',
    family: .image,
    supportsOverride: _imageWithoutConstrainedSupports,
  ),
  gemini3ProImage(
    'gemini-3-pro-image',
    'Gemini 3 Pro Image',
    family: .image,
    interactions: false,
  ),
  geminiOmni11Flash(
    'gemini-omni-1.1-flash',
    'Gemini Omni 1.1 Flash',
    family: .video,
  ),
  gemini38FlashTts(
    'gemini-3.8-flash-tts',
    'Gemini 3.8 Flash TTS',
    family: .tts,
  ),
  gemini38FlashLiteTts(
    'gemini-3.8-flash-lite-tts',
    'Gemini 3.8 Flash Lite TTS',
    family: .tts,
  ),

  // Hidden models (JS HIDDEN_MODELS): models we no longer suggest, but that
  // still work. They still resolve and are still listed, with their stage.
  // Each stays on generateContent: listing it is what keeps it off the
  // Interactions API, which unlisted names default to. Remove an entry once
  // the server returns 404 for it.

  // Gemini 2.5: Google limits access to projects that used it before; new
  // projects should use newer models.
  gemini25Pro(
    'gemini-2.5-pro',
    'Gemini 2.5 Pro',
    stage: .legacy,
    interactions: false,
  ),
  gemini25Flash(
    'gemini-2.5-flash',
    'Gemini 2.5 Flash',
    stage: .legacy,
    interactions: false,
  ),
  gemini25FlashLite(
    'gemini-2.5-flash-lite',
    'Gemini 2.5 Flash Lite',
    stage: .legacy,
    interactions: false,
  ),
  gemini25FlashImage(
    'gemini-2.5-flash-image',
    'Gemini 2.5 Flash Image',
    family: .image,
    stage: .legacy,
    interactions: false,
  ),

  // Shut down on Nov 17 2026.
  gemini25FlashPreviewTts(
    'gemini-2.5-flash-preview-tts',
    'Gemini 2.5 Flash Preview TTS',
    family: .tts,
    stage: .deprecated,
    interactions: false,
  ),
  gemini25ProPreviewTts(
    'gemini-2.5-pro-preview-tts',
    'Gemini 2.5 Pro Preview TTS',
    family: .tts,
    stage: .deprecated,
    interactions: false,
  ),
  gemini31FlashTtsPreview(
    'gemini-3.1-flash-tts-preview',
    'Gemini 3.1 Flash TTS Preview',
    family: .tts,
    stage: .deprecated,
    interactions: false,
  ),

  // Deprecated, not shutting down: the server routes requests for it to
  // gemini-3.6-flash. Still sent through generateContent, as before: the
  // routing happens on the server.
  gemini35Flash(
    'gemini-3.5-flash',
    'Gemini 3.5 Flash',
    stage: .deprecated,
    interactions: false,
  ),

  // Deprecated (no shutdown date yet); replaced by gemini-nano-banana-2.1.
  gemini31FlashImage(
    'gemini-3.1-flash-image',
    'Gemini 3.1 Flash Image',
    family: .image,
    stage: .deprecated,
    interactions: false,
  );

  const KnownGeminiModel(
    this.id,
    this.label, {
    this.family = .text,
    this.stage = .stable,
    this.interactions = true,
    this.supportsOverride,
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

  /// This model's capability profile when it differs from its family's.
  final Map<String, dynamic>? supportsOverride;

  /// Whether this model is no longer suggested (JS `HIDDEN_MODELS`).
  bool get hidden => stage != .stable;

  /// The capability profile for this model.
  ModelInfo get info => ModelInfo(
    label: label,
    supports: supportsOverride ?? family.supports,
    stage: stage.wireName,
  );
}

/// Gemma models the Gemini API serves, curated the same way as
/// [KnownGeminiModel].
enum KnownGemmaModel {
  gemma431b('gemma-4-31b-it', 'Gemma 4 31B', interactions: false),
  gemma426bA4b('gemma-4-26b-a4b-it', 'Gemma 4 26B A4B', interactions: false);

  const KnownGemmaModel(this.id, this.label, {this.interactions = true});

  /// Bare model name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The lifecycle stage this model is listed with.
  // No Gemma model is hidden yet. Make this a constructor parameter, as in
  // [KnownGeminiModel], when one is.
  GeminiModelStage get stage => .stable;

  /// Whether this model is called through the Interactions API rather than
  /// generateContent (the 4th argument of JS `commonRef`).
  final bool interactions;

  /// Whether this model is no longer suggested (JS `HIDDEN_MODELS`).
  bool get hidden => stage != .stable;

  /// The multimodal capability profile for this model.
  ModelInfo get info => ModelInfo(
    label: label,
    supports: _multimodalSupports,
    stage: stage.wireName,
  );
}

/// Curated capability metadata for the Gemini and Gemma models known to the
/// Gemini API (googleAI) plugin, keyed by bare model name (no plugin prefix).
///
/// Derived from [KnownGeminiModel] and [KnownGemmaModel], hidden models
/// included; models are still resolved from raw strings, this map only enriches
/// known names with per-model metadata instead of the shared `commonModelInfo`
/// fallback. Exposed via `CommonGoogleGenPlugin.knownModels`.
final knownGeminiModels = <String, ModelInfo>{
  for (final model in KnownGeminiModel.values) model.id: model.info,
  for (final model in KnownGemmaModel.values) model.id: model.info,
};

/// Whether each curated googleAI model is called through the Interactions API,
/// keyed by bare model name.
///
/// Names not listed here use the Interactions API, as in the JS plugin.
final knownGeminiInteractions = Map<String, bool>.unmodifiable({
  for (final model in KnownGeminiModel.values) model.id: model.interactions,
  for (final model in KnownGemmaModel.values) model.id: model.interactions,
});

/// Embedders the Gemini API (googleAI) plugin curates, kept in step with the
/// JS plugin's googleAI embedder list (js/plugins/google-genai/src/googleai/
/// embedder.ts).
///
/// Like the model catalog, this only adds metadata and keeps the listed
/// embedders in listings when discovery omits them; any embedding model name
/// still resolves.
enum KnownGeminiEmbedder {
  geminiEmbedding001('gemini-embedding-001', 'Gemini Embedding 001', ['text']),
  geminiEmbedding2('gemini-embedding-2', 'Gemini Embedding 2', [
    'text',
    'image',
    'video',
  ]);

  const KnownGeminiEmbedder(this.id, this.label, this.input);

  /// Bare embedder name (no plugin prefix).
  final String id;

  /// Human-readable label surfaced in listings.
  final String label;

  /// The kinds of input this embedder accepts.
  final List<String> input;

  /// The embedder metadata (`info`) for this embedder, as in JS: 3072
  /// dimensions and the accepted input kinds.
  Map<String, dynamic> get info => {
    'label': label,
    'dimensions': 3072,
    'supports': {'input': input},
  };
}

/// Curated embedder metadata for the googleAI plugin, keyed by bare name.
final knownGeminiEmbedders = Map<String, Map<String, dynamic>>.unmodifiable({
  for (final embedder in KnownGeminiEmbedder.values) embedder.id: embedder.info,
});
