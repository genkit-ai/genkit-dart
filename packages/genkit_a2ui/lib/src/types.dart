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

/// Shared A2UI protocol types and constants.
///
/// Envelopes are represented as plain `Map<String, dynamic>` values (their raw
/// JSON shape), since they are open-ended and pass straight through to the
/// renderer. The constants and helpers here document and construct those shapes.
library;

/// The MIME type that identifies an A2UI payload. This is stamped onto the
/// `metadata.mimeType` of the Genkit `data` part that carries A2UI envelopes,
/// matching the A2A binding of the A2UI spec exactly.
const String a2uiMimeType = 'application/a2ui+json';

/// The a2ui part `metadata` key holding the A2UI Express source a part's
/// messages were compiled from.
///
/// The middleware replays this source verbatim when the part comes back as
/// history, so the model sees exactly what it wrote. Clients that manage
/// history themselves must send parts back with their metadata intact.
const String a2uiExpressMetadataKey = 'a2uiExpress';

/// The A2UI protocol versions this package supports. A catalog decides which
/// version a turn emits (see `A2uiCatalog.protocolVersion`); passing
/// `version:` to `a2ui()` checks that the configured catalog agrees.
const Set<String> supportedA2uiVersions = {'v0.9', 'v0.9.1', '1.0'};

/// The catalog id of the A2UI v1.0 "Basic Catalog". Surfaces created with the
/// bundled `basicCatalog` reference this id, and the client renderer registers
/// a catalog under the same id.
const String basicCatalogId =
    'https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json';

/// The catalog id of the A2UI v0.9 "Basic Catalog", used by `basicCatalogV09`.
const String basicCatalogV09Id =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// A single agent -> renderer A2UI envelope message, in its raw JSON shape.
///
/// Exactly one of the keys `createSurface`, `updateComponents`,
/// `updateDataModel`, or `deleteSurface` is present, alongside `version`.
/// Renderer -> agent actions use an `action` key.
typedef A2uiEnvelope = Map<String, dynamic>;
