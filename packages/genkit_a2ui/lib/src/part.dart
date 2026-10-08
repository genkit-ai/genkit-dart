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

/// Helpers for working with the canonical "a2ui part": a Genkit `data` part
/// tagged with [a2uiMimeType] whose `data` is `{"messages": [...]}`.
///
/// The A2UI extension spec puts the message list directly in `data`, but a
/// Genkit `DataPart.data` must be an object, so the list is wrapped in the
/// spec's `{messages: [...]}` payload wrapper (which a2ui_core's
/// `AgentToRendererMessagePayload.fromJson` reads as-is).
library;

import 'package:genkit/plugin.dart';

import 'types.dart';

/// Builds an a2ui data part wrapping the given [envelopes].
DataPart a2uiPart(List<A2uiEnvelope> envelopes) {
  return DataPart(
    data: {'messages': envelopes},
    metadata: {'mimeType': a2uiMimeType},
  );
}

/// Reads the message list out of an a2ui data part's `data`, or `null` if the
/// value is not a well-formed a2ui data part.
List<A2uiEnvelope>? _envelopesOf(Map<String, dynamic>? data) {
  // `envelopes` is the pre-spec key. Still read so persisted sessions written
  // before the rename replay instead of silently losing their surfaces.
  final envelopes = data?['messages'] ?? data?['envelopes'];
  if (envelopes is! List) return null;
  return envelopes
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

/// Whether the given [part] is an a2ui data part.
bool isA2uiPart(Part part) {
  if (!part.isData) return false;
  if (part.metadata?['mimeType'] != a2uiMimeType) return false;
  return _envelopesOf(part.data) != null;
}

/// Extracts all A2UI envelopes carried by the given [parts].
///
/// Pass a message's, chunk's, or response's `content`:
///
/// ```dart
/// await for (final chunk in ai.generateStream(..., use: [a2ui()])) {
///   final envelopes = a2uiEnvelopesFromParts(chunk.content);
/// }
/// ```
///
/// [parts] is nullable purely for call-site convenience (a chunk's content can
/// be `null`); a `null` list is treated as empty.
///
/// Returns `[]` for content that carries no a2ui parts (e.g. plain prose).
List<A2uiEnvelope> a2uiEnvelopesFromParts(List<Part>? parts) {
  final out = <A2uiEnvelope>[];
  for (final part in parts ?? const <Part>[]) {
    if (isA2uiPart(part)) {
      final envelopes = _envelopesOf(part.data);
      if (envelopes != null) out.addAll(envelopes);
    }
  }
  return out;
}
