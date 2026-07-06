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

/// Builds the [ModelInfo] for a multimodal Gemini model.
///
/// Mirrors the `Multimodal` capability preset the Go plugin uses for its
/// curated model list: multiturn chat, media input/output, tool calling and
/// native constrained generation.
ModelInfo multimodalModelInfo(String label) => ModelInfo(
  label: label,
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
  stage: 'stable',
);

/// Curated capability metadata for known Gemini models, keyed by bare model
/// name (no plugin prefix).
///
/// Models are still resolved from raw strings; this map only enriches known
/// names with per-model metadata instead of the shared `commonModelInfo`
/// fallback. Plugins expose a subset via `CommonGoogleGenPlugin.knownModels`.
final knownGeminiModels = <String, ModelInfo>{
  'gemini-3.5-flash': multimodalModelInfo('Gemini 3.5 Flash'),
  'gemini-3.1-flash-lite': multimodalModelInfo('Gemini 3.1 Flash Lite'),
  'gemini-3.1-flash-image': multimodalModelInfo('Gemini 3.1 Flash Image'),
  'gemini-3-pro-image': multimodalModelInfo('Gemini 3 Pro Image'),
};
