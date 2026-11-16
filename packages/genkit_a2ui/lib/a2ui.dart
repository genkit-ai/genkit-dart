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
/// a one-shot `generate`'s) `use` list. Pair it with `basicCatalog` (v1.0, the
/// default), `basicCatalogV09` (select with `catalog: 'basic-v0.9'`), or your
/// own catalog.
///
/// Clients do not depend on this package. A2UI travels as spec-shaped data
/// parts, so a client needs only `package:genkit` and a renderer such as
/// `a2ui_flutter`; see the README for copy-paste helpers.
library;

export 'src/a2ui_middleware.dart'
    show A2uiMiddleware, A2uiOptions, A2uiPlugin, a2ui;
export 'src/catalog.dart'
    show
        A2uiCatalog,
        A2uiCatalogComponent,
        A2uiCatalogFunction,
        A2uiDynamicType,
        A2uiParam,
        a2uiCatalogValueType,
        basicCatalog,
        basicCatalogV09,
        basicCatalogV09LookupId,
        basicIconNames,
        defaultCatalogId,
        renderCatalogInstructions;
export 'src/loader.dart' show loadCatalog, resolveCatalog;
export 'src/parser.dart'
    show
        A2uiStreamParser,
        A2uiValidateMode,
        EnvelopeSegment,
        ParseResult,
        ParseSegment,
        ProseSegment;
export 'src/part.dart' show a2uiEnvelopesFromParts, a2uiPart, isA2uiPart;
export 'src/types.dart'
    show
        A2uiEnvelope,
        a2uiExpressMetadataKey,
        a2uiMimeType,
        basicCatalogId,
        basicCatalogV09Id;
