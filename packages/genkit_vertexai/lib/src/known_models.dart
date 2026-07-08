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
/// Any other model name still resolves dynamically with the common fallback
/// metadata; this list only controls which names get accurate per-model
/// `supports` and appear in listings even when model discovery omits them.
const vertexAiKnownModelNames = [
  'gemini-3.5-flash',
  'gemini-3.1-flash-lite',
  'gemini-3.1-flash-image',
  'gemini-3-pro-image',
];

/// Curated capability metadata for the Vertex AI plugin, keyed by bare model
/// name.
final vertexAiKnownModels = <String, ModelInfo>{
  for (final name in vertexAiKnownModelNames) name: knownGeminiModels[name]!,
};
