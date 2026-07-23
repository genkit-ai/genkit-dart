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

/// A2UI (Agent-to-UI) streaming UI protocol support for Genkit Dart.
///
/// The whole server-side integration is the `a2ui()` model middleware; register
/// `A2uiPlugin` in `Genkit(plugins: [...])`, then add `a2ui()` to an agent's (or
/// a one-shot `generate`'s) `use` list. Pair it with `basicCatalog` (or your own
/// catalog) and render on the client with the `genui` package plus the helpers
/// in `package:genkit_a2ui/client.dart`.
library;

export 'src/a2ui_middleware.dart'
    show A2uiMiddleware, A2uiOptions, A2uiPlugin, a2ui;
export 'src/catalog.dart'
    show
        A2uiCatalog,
        A2uiCatalogComponent,
        a2uiCatalogValueType,
        basicCatalog,
        basicIconNames,
        defaultCatalogId,
        renderCatalogInstructions,
        surfaceIdPlaceholder;
export 'src/loader.dart' show loadCatalog, resolveCatalog;
export 'src/parser.dart'
    show
        A2uiStreamParser,
        A2uiValidateMode,
        EnvelopeSegment,
        ParseResult,
        ParseSegment,
        ProseSegment;
export 'src/part.dart'
    show a2uiEnvelopes, a2uiEnvelopesFromParts, a2uiPart, isA2uiPart;
export 'src/types.dart'
    show
        A2uiClientAction,
        A2uiComponent,
        A2uiEnvelope,
        a2uiMimeType,
        a2uiVersion,
        basicCatalogId;
