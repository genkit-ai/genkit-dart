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

// Each export shows only what genkit_vertexai uses (its lib/ and test/), so
// the shared surface stays small and visible. This package's own tests import
// the src/ files directly. Add a name here when genkit_vertexai needs it.

// The API client vertexAI builds with its own host, auth and paths.
export 'src/api_client.dart' show GenerativeLanguageBaseClient;
// The shared plugin base class (request/response mapping, routing hooks),
// the HTTP helpers and the shared embedder and model-info helpers.
export 'src/common_plugin.dart'
    show
        CommonGoogleGenPlugin,
        CustomClient,
        NonClosingClient,
        commonModelInfo,
        embedWithEmbedContent,
        isEmbedderModelName,
        logger;
// Once-per-model warnings for options a model ignores (and their reset, for
// tests).
export 'src/interaction_converters.dart'
    show resetDroppedConfigFieldWarnings, warnDroppedConfigField;
// Reset for the once-only "steps left out of a stateless resend" warning
// (tests).
export 'src/interaction_model.dart' show resetDroppedResentStepsWarning;
// Request type used by vertexAI's tests.
export 'src/interaction_types.dart' show CreateInteractionRequest;
// The catalog enums stay in src/: vertexai only needs the family rules and the
// stage vocabulary (it keeps its own model list), and the catalog enums would
// invite users to switch over them.
export 'src/known_models.dart'
    show
        GeminiModelFamily,
        GeminiModelStage,
        geminiTtsSupports,
        geminiVideoSupports,
        knownGeminiModels;
// The Lyria model builder and profile (vertexAI keeps its own known list).
export 'src/lyria.dart' show createLyriaModel, isLyriaModelName, lyriaSupports;
// Every options type: the public options surface both plugins share
// (genkit_vertexai re-exports many of them to its users), kept whole so new
// option types don't need a list change here.
export 'src/model.dart';
