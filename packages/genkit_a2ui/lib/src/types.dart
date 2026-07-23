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
/// This module is intentionally free of any server-only dependencies so it can
/// be imported both on the server (the `a2ui()` middleware) and on the client
/// (the transport helpers, including Flutter). It mirrors the wire shapes of the
/// A2UI v0.9 specification.
///
/// Envelopes are represented as plain `Map<String, dynamic>` values (their raw
/// JSON shape), since they are open-ended and pass straight through to the
/// renderer. The constants and helpers here document and construct those shapes.
library;

/// The MIME type that identifies an A2UI payload. This is stamped onto the
/// `metadata.mimeType` of the Genkit `data` part that carries A2UI envelopes,
/// matching the A2A binding of the A2UI spec exactly.
const String a2uiMimeType = 'application/a2ui+json';

/// The default A2UI protocol version stamped on emitted envelopes.
const String a2uiVersion = 'v0.9';

/// The catalog id of the A2UI "Basic Catalog" (v0.9). Surfaces created with the
/// basic catalog reference this id, and the client renderer registers a catalog
/// under the same id.
const String basicCatalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// A single server -> client A2UI envelope message, in its raw JSON shape.
///
/// Exactly one of the keys `createSurface`, `updateComponents`,
/// `updateDataModel`, or `deleteSurface` is present, alongside an optional
/// `version`. Client -> server actions use an `action` key.
typedef A2uiEnvelope = Map<String, dynamic>;

/// A single component entry in an A2UI adjacency list, in its raw JSON shape.
///
/// UI is expressed as a flat list of components; the tree is reconstructed via
/// `id` references. Exactly one component has `id: "root"`. Beyond
/// `component`/`id`/`weight`, every component carries catalog-specific props
/// (e.g. `text`, `children`, `child`, `action`), so this is intentionally
/// open-ended.
typedef A2uiComponent = Map<String, dynamic>;

/// A client -> server user action reported by a rendered surface (e.g. a button
/// press). Sent back to the agent as the next turn's input.
class A2uiClientAction {
  /// The event name declared by the interactive component's `action`.
  final String name;

  /// The id of the surface the action originated from.
  final String surfaceId;

  /// The id of the component that fired the action.
  final String sourceComponentId;

  /// An ISO-8601 timestamp of when the action fired.
  final String timestamp;

  /// The action's context payload (e.g. resolved data-model bindings).
  final Map<String, dynamic> context;

  /// Creates an [A2uiClientAction].
  const A2uiClientAction({
    required this.name,
    required this.surfaceId,
    required this.sourceComponentId,
    required this.timestamp,
    this.context = const {},
  });

  /// Builds an [A2uiClientAction] from its raw JSON shape.
  factory A2uiClientAction.fromJson(Map<String, dynamic> json) {
    return A2uiClientAction(
      name: (json['name'] as String?) ?? '',
      surfaceId: (json['surfaceId'] as String?) ?? '',
      sourceComponentId: (json['sourceComponentId'] as String?) ?? '',
      timestamp: (json['timestamp'] as String?) ?? '',
      context: (json['context'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Serializes this action to its raw JSON shape.
  Map<String, dynamic> toJson() => {
    'name': name,
    'surfaceId': surfaceId,
    'sourceComponentId': sourceComponentId,
    'timestamp': timestamp,
    'context': context,
  };
}
