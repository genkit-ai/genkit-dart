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

/// Helpers for working with the canonical "a2ui part" - a Genkit `data` part
/// whose `data` is an object `{ envelopes }` wrapping an array of A2UI
/// envelopes, tagged with [a2uiMimeType].
///
/// These helpers operate on plain Genkit [Part]s (and part-shaped JSON maps), so
/// they are safe to use on both the server and the client (including Flutter).
library;

import 'package:genkit/plugin.dart';

import 'types.dart';

/// Builds an a2ui data part wrapping the given [envelopes].
DataPart a2uiPart(List<A2uiEnvelope> envelopes) {
  return DataPart(
    data: {'envelopes': envelopes},
    metadata: {'mimeType': a2uiMimeType},
  );
}

/// Reads the `envelopes` array out of an a2ui data part's `data`, or `null` if
/// the value is not a well-formed a2ui data part.
List<A2uiEnvelope>? _envelopesOf(Map<String, dynamic>? data) {
  final envelopes = data?['envelopes'];
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
/// Returns `[]` for content that carries no a2ui parts (e.g. plain prose).
List<A2uiEnvelope> a2uiEnvelopesFromParts(List<Part> parts) {
  final out = <A2uiEnvelope>[];
  for (final part in parts) {
    if (isA2uiPart(part)) {
      final envelopes = _envelopesOf(part.data);
      if (envelopes != null) out.addAll(envelopes);
    }
  }
  return out;
}

/// Extracts all A2UI envelopes from a [Message], a [ModelResponseChunk], or a
/// [ModelResponse]'s message.
///
/// Returns `[]` for anything that carries no a2ui parts.
List<A2uiEnvelope> a2uiEnvelopes(Object? value) {
  switch (value) {
    case Message m:
      return a2uiEnvelopesFromParts(m.content);
    case ModelResponseChunk c:
      return a2uiEnvelopesFromParts(c.content);
    case ModelResponse r:
      final content = r.message?.content;
      return content == null ? [] : a2uiEnvelopesFromParts(content);
    case Part p:
      return a2uiEnvelopesFromParts([p]);
    default:
      return [];
  }
}
