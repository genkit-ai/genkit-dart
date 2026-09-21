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

import 'src/google_api_client.dart';
import 'src/known_models.dart';
import 'src/model.dart';

export 'src/model.dart';

const GoogleGenAiPluginHandle googleAI = GoogleGenAiPluginHandle();

class GoogleGenAiPluginHandle {
  const GoogleGenAiPluginHandle();

  GenkitPlugin call({String? apiKey}) {
    return GoogleGenAiPluginImpl(apiKey: apiKey);
  }

  ModelRef<GeminiOptions> gemini(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptions.$schema);
  }

  /// A [ModelRef] for the Gemini text-to-speech model [name].
  ///
  /// Carries [GeminiTtsOptions], which adds `speechConfig` on top of
  /// [GeminiOptions]. Use it for any `-tts` name, curated or not, so the
  /// request config is typed to what the model accepts.
  ModelRef<GeminiTtsOptions> geminiTts(String name) {
    return modelRef('googleai/$name', customOptions: GeminiTtsOptions.$schema);
  }

  /// A [ModelRef] for the Gemma model [name] served by the Gemini API.
  ///
  /// An alias of [gemini] that reads correctly at Gemma call sites. Should
  /// Gemma ever gain an options schema of its own, the options type here
  /// narrows to it, which is a breaking change for callers.
  ModelRef<GeminiOptions> gemma(String name) => gemini(name);

  EmbedderRef<TextEmbedderOptions> textEmbedding(String name) {
    return embedderRef(
      'googleai/$name',
      customOptions: TextEmbedderOptions.$schema,
    );
  }
}

/// Typed [ModelRef]s for the Gemini and Gemma models curated by the googleai
/// plugin.
///
/// Each entry is equivalent to `googleAI.gemini('<name>')`,
/// `googleAI.geminiTts('<name>')` or `googleAI.gemma('<name>')`, which remain
/// the escape hatch for models not listed here.
abstract final class GoogleAiModels {
  static final ModelRef<GeminiOptions> gemini25Pro = googleAI.gemini(
    KnownGeminiModel.gemini25Pro.id,
  );

  static final ModelRef<GeminiOptions> gemini25Flash = googleAI.gemini(
    KnownGeminiModel.gemini25Flash.id,
  );

  static final ModelRef<GeminiOptions> gemini25FlashLite = googleAI.gemini(
    KnownGeminiModel.gemini25FlashLite.id,
  );

  static final ModelRef<GeminiOptions> gemini31ProPreview = googleAI.gemini(
    KnownGeminiModel.gemini31ProPreview.id,
  );

  static final ModelRef<GeminiOptions> gemini3FlashPreview = googleAI.gemini(
    KnownGeminiModel.gemini3FlashPreview.id,
  );

  static final ModelRef<GeminiOptions> gemini37Flash = googleAI.gemini(
    KnownGeminiModel.gemini37Flash.id,
  );

  static final ModelRef<GeminiOptions> gemini36Flash = googleAI.gemini(
    KnownGeminiModel.gemini36Flash.id,
  );

  static final ModelRef<GeminiOptions> gemini35Flash = googleAI.gemini(
    KnownGeminiModel.gemini35Flash.id,
  );

  static final ModelRef<GeminiOptions> gemini35FlashLite = googleAI.gemini(
    KnownGeminiModel.gemini35FlashLite.id,
  );

  static final ModelRef<GeminiOptions> gemini31FlashLite = googleAI.gemini(
    KnownGeminiModel.gemini31FlashLite.id,
  );

  static final ModelRef<GeminiOptions> gemini25FlashImage = googleAI.gemini(
    KnownGeminiModel.gemini25FlashImage.id,
  );

  static final ModelRef<GeminiOptions> gemini31FlashImage = googleAI.gemini(
    KnownGeminiModel.gemini31FlashImage.id,
  );

  static final ModelRef<GeminiOptions> gemini31FlashLiteImage = googleAI.gemini(
    KnownGeminiModel.gemini31FlashLiteImage.id,
  );

  static final ModelRef<GeminiOptions> gemini3ProImage = googleAI.gemini(
    KnownGeminiModel.gemini3ProImage.id,
  );

  static final ModelRef<GeminiTtsOptions> gemini25FlashPreviewTts = googleAI
      .geminiTts(KnownGeminiModel.gemini25FlashPreviewTts.id);

  static final ModelRef<GeminiTtsOptions> gemini25ProPreviewTts = googleAI
      .geminiTts(KnownGeminiModel.gemini25ProPreviewTts.id);

  static final ModelRef<GeminiTtsOptions> gemini31FlashTtsPreview = googleAI
      .geminiTts(KnownGeminiModel.gemini31FlashTtsPreview.id);

  static final ModelRef<GeminiOptions> gemma431b = googleAI.gemma(
    KnownGemmaModel.gemma431b.id,
  );

  static final ModelRef<GeminiOptions> gemma426bA4b = googleAI.gemma(
    KnownGemmaModel.gemma426bA4b.id,
  );
}
