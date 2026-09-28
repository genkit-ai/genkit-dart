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

/// Shared implementation for Genkit's Google model plugins.
///
/// **Not public API.** This library exists so `genkit_vertexai` can reuse the
/// Gemini request/response mapping, model catalog, and API client from this
/// package. It is not covered by this package's semantic-versioning
/// guarantees: anything here may change or disappear in any release, including
/// patch releases.
///
/// Applications should import `package:genkit_google_genai/genkit_google_genai.dart`
/// (or `package:genkit_vertexai/genkit_vertexai.dart`) instead.
// Kept as a public library (rather than `src/`) because a sibling package
// needs it and `implementation_imports` forbids importing another package's
// `src/`. Deliberately not annotated `@internal`: that annotation means
// "this package only", so it would flag the one intended consumer. Internal
// changes here land together with the matching change in genkit_vertexai.
library;

export 'src/api_client.dart';
export 'src/common_plugin.dart';
export 'src/known_models.dart';
export 'src/model.dart';
