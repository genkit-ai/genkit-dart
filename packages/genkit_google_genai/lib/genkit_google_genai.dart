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

  /// A [ModelRef] for the Gemma model [name] served by the Gemini API.
  ///
  /// Equivalent to [gemini] in every respect: Gemma takes the Gemini request
  /// shape and so is configured with `GeminiOptions`. It exists so that call
  /// sites naming a Gemma model read correctly.
  ModelRef<GeminiOptions> gemma(String name) {
    return modelRef('googleai/$name', customOptions: GeminiOptions.$schema);
  }

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
/// Each entry is equivalent to `googleAI.gemini('<name>')` or
/// `googleAI.gemma('<name>')`, which remain the escape hatch for models not
/// listed here.
abstract final class GoogleAiModels {
  static final ModelRef<GeminiOptions> gemini35Flash = googleAI.gemini(
    KnownGeminiModel.gemini35Flash.id,
  );

  static final ModelRef<GeminiOptions> gemini31FlashLite = googleAI.gemini(
    KnownGeminiModel.gemini31FlashLite.id,
  );

  static final ModelRef<GeminiOptions> gemini31FlashImage = googleAI.gemini(
    KnownGeminiModel.gemini31FlashImage.id,
  );

  static final ModelRef<GeminiOptions> gemini3ProImage = googleAI.gemini(
    KnownGeminiModel.gemini3ProImage.id,
  );

  static final ModelRef<GeminiOptions> gemma431b = googleAI.gemma(
    KnownGemmaModel.gemma431b.id,
  );

  static final ModelRef<GeminiOptions> gemma426bA4b = googleAI.gemma(
    KnownGemmaModel.gemma426bA4b.id,
  );
}
