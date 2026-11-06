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
/// genui version the client uses). Keep [a2uiMessagesFrom] and
/// [a2uiSubmitToMessage] in sync with the README.
library;

import 'dart:convert';

import 'package:genkit/client.dart';
// genui also exports `Part`/`DataPart` (from genai_primitives), so take only
// what is needed.
import 'package:genui/genui.dart' show ChatMessage, UiPartExtension;

const a2uiMimeType = 'application/a2ui+json';

/// The A2UI messages carried by a chunk's or message's parts.
Iterable<Map<String, dynamic>> a2uiMessagesFrom(List<Part>? parts) sync* {
  for (final part in parts ?? const <Part>[]) {
    if (part.metadata?['mimeType'] != a2uiMimeType) continue;
    // `envelopes` is the pre-spec key, still written by older agents. Malformed
    // payloads are skipped rather than throwing mid-stream.
    final data = part.data;
    if ((data?['messages'] ?? data?['envelopes']) case final List messages) {
      yield* messages.whereType<Map>().map((m) => m.cast<String, dynamic>());
    }
  }
}

/// Turns a genui surface submission (e.g. a button press) into the next agent
/// input, or null when it carries no user action: genui also reports renderer
/// errors through `onSubmit`, and those are not turns. genui already emits
/// spec-shaped `{version, action}` messages, so they are forwarded untouched.
Message? a2uiSubmitToMessage(ChatMessage submit) {
  final actions = <Map<String, dynamic>>[
    for (final part in submit.parts)
      if (part.asUiInteractionPart case final ui?)
        if (_decodeJson(ui.interaction) case final Map<String, dynamic> m
            when m.containsKey('action'))
          m,
  ];
  if (actions.isEmpty) return null;
  return Message(
    role: Role.user,
    content: [
      DataPart(
        data: {'messages': actions},
        metadata: {'mimeType': a2uiMimeType},
      ),
    ],
  );
}

Object? _decodeJson(String source) {
  try {
    return jsonDecode(source);
  } on FormatException {
    return null;
  }
}

/// The action names in a message built by [a2uiSubmitToMessage], for display.
///
/// Not part of the README helpers: the sample uses it to label the chat log.
List<String> a2uiActionNames(Message message) => [
  for (final m in a2uiMessagesFrom(message.content))
    if (m['action'] case {'name': final String name}) name,
];
