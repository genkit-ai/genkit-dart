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

/// Client-side A2UI helpers, copied from the genkit_a2ui README.
///
/// They are copied rather than imported so the client never depends on
/// genkit_a2ui (and so genkit_a2ui's dependencies can never constrain which
/// renderer version the client uses). Keep them in sync with the README.
library;

import 'package:a2ui_core/a2ui_core.dart'
    show ActionMessage, RendererToAgentMessagePayload;
import 'package:genkit/client.dart';

const a2uiMimeType = 'application/a2ui+json';

const _envelopeKeys = {'checks', 'accessibility', 'catalogId', 'metadata'};

/// The A2UI messages carried by a chunk's or message's parts.
Iterable<Map<String, dynamic>> a2uiMessagesFrom(List<Part>? parts) sync* {
  for (final part in parts ?? const <Part>[]) {
    if (part.metadata?['mimeType'] != a2uiMimeType) continue;
    // `envelopes` is the pre-spec key, still written by older agents. Malformed
    // payloads are skipped rather than throwing mid-stream.
    final data = part.data;
    if ((data?['messages'] ?? data?['envelopes']) case final List messages) {
      yield* messages.whereType<Map>().map(
        (m) => _normalizeEnvelopeKeys(
          m is Map<String, dynamic> ? m : m.cast<String, dynamic>(),
        ),
      );
    }
  }
}

bool _hasAtEnvelopeKey(Object? c) =>
    c is Map &&
    c.keys.any(
      (k) =>
          k is String &&
          k.startsWith('@') &&
          _envelopeKeys.contains(k.substring(1)) &&
          !c.containsKey(k.substring(1)),
    );

/// Rewrites `@checks`, `@accessibility`, `@catalogId` and `@metadata` on v1.0
/// components to the bare names that `a2ui_core` 0.7 expects, so this client
/// still renders surfaces if the agent upgrades past it. Delete it once your
/// `a2ui_core` reads the `@` keys itself (a2ui-project/a2ui#4037): after the
/// bare-key fallback is removed (a2ui-project/a2ui#4082), the rewritten keys
/// are read as ordinary component properties and `checks` stop applying.
Map<String, dynamic> _normalizeEnvelopeKeys(Map<String, dynamic> message) {
  if (message['version'] != '1.0') return message;
  for (final kind in const ['createSurface', 'updateComponents']) {
    if (message[kind] case final Map body) {
      if (body['components'] case final List components
          when components.any(_hasAtEnvelopeKey)) {
        return <String, dynamic>{
          ...message,
          kind: <String, dynamic>{
            ...body.cast<String, dynamic>(),
            'components': <Object?>[
              for (final c in components)
                if (c is Map)
                  <String, dynamic>{
                    for (final MapEntry(:key, :value) in c.entries)
                      if (key is String &&
                          key.startsWith('@') &&
                          _envelopeKeys.contains(key.substring(1)) &&
                          !c.containsKey(key.substring(1)))
                        key.substring(1): value
                      else
                        '$key': value,
                  }
                else
                  c,
            ],
          },
        };
      }
    }
  }
  return message;
}

/// Wraps a surface action (e.g. a button press) as the next agent input.
///
/// `a2ui_core` writes the `{messages: [...]}` wrapper the agent reads, with
/// the action in a spec-shaped `{version, action}` message, so it is forwarded
/// as is.
Message a2uiActionToMessage(ActionMessage action) => Message(
  role: .user,
  content: [
    DataPart(
      data: RendererToAgentMessagePayload.of(action).toJson(),
      metadata: {'mimeType': a2uiMimeType},
    ),
  ],
);
