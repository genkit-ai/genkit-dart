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

/// Curated capability metadata for the Vertex AI plugin, keyed by bare model
/// name.
///
/// The Gemini text and image subset of the Gemini API catalog. Any other model
/// name still resolves dynamically with the common fallback metadata; these
/// entries only give the listed models accurate per-model `supports` and keep
/// them in listings even when model discovery omits them.
// Filtered by name, the same rule GeminiModelFamily.of uses, because the
// catalog's enums are internal to genkit_google_genai. Two things stay out:
// - Gemma, which Vertex serves through Model Garden rather than as a
//   publisher Gemini model; it still resolves on the Gemini path.
// - TTS, which Vertex serves under IDs of its own (`gemini-2.5-flash-tts`
//   rather than `gemini-2.5-flash-preview-tts`); those names still get the
//   TTS profile through `modelInfoFor`.
final vertexAiKnownModels = Map<String, ModelInfo>.unmodifiable({
  for (final MapEntry(:key, :value) in knownGeminiModels.entries)
    if (key.startsWith('gemini-') &&
        GeminiModelFamily.of(key) != GeminiModelFamily.tts)
      key: value,
});
