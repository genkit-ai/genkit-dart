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

/// Normalizes Genkit messages to the OpenTelemetry GenAI content schema.
///
/// Pure mapping logic with no OpenTelemetry dependency, so it can be unit
/// tested directly. Only used when content capture is enabled.
library;

import 'dart:convert';

import 'package:genkit/genkit.dart';

/// The result of splitting a message list into system instructions and the
/// remaining conversation messages, both in the GenAI content schema.
typedef NormalizedMessages = ({
  List<Map<String, Object?>> messages,
  List<Map<String, Object?>> systemInstructions,
});

/// Maps a Genkit [Role] to the GenAI role name.
///
/// Genkit `model` becomes `assistant`; other roles pass through.
String mapRole(Role role) {
  final value = role.value;
  if (value == 'model') return 'assistant';
  return value;
}

/// Converts a single Genkit [Part] to a GenAI content part map.
///
/// The generated [Part] type is a thin wrapper over a JSON map and does not
/// preserve concrete subtypes (a `Message.content` element is always a base
/// [Part]), so this discriminates on the JSON shape via [Part.toJson] rather
/// than on the Dart type. Unknown part kinds fall back to a generic `text` part
/// so nothing is silently dropped from captured content.
Map<String, Object?> mapPart(Part part) {
  final json = part.toJson();

  final text = json['text'];
  if (text != null) {
    return {'type': 'text', 'content': text};
  }

  final reasoning = json['reasoning'];
  if (reasoning != null) {
    return {'type': 'reasoning', 'content': reasoning};
  }

  final toolRequest = json['toolRequest'];
  if (toolRequest is Map) {
    return {
      'type': 'tool_call',
      if (toolRequest['ref'] != null) 'id': toolRequest['ref'],
      'name': toolRequest['name'],
      'arguments': toolRequest['input'],
    };
  }

  final toolResponse = json['toolResponse'];
  if (toolResponse is Map) {
    return {
      'type': 'tool_call_response',
      if (toolResponse['ref'] != null) 'id': toolResponse['ref'],
      'response': toolResponse['output'],
    };
  }

  final media = json['media'];
  if (media is Map) {
    return {
      'type': 'media',
      'content': media['url'],
      if (media['contentType'] != null) 'content_type': media['contentType'],
    };
  }

  // Unknown/opaque part: serialize as JSON so downstream consumers get
  // parseable content, without losing the fact that it existed.
  return {'type': 'text', 'content': jsonEncode(json)};
}

/// Whether [part] is a tool-request part, discriminated on its JSON shape.
bool isToolRequestPart(Part part) => part.toJson()['toolRequest'] is Map;

/// Converts a single Genkit [Message] to a GenAI message map.
Map<String, Object?> mapMessage(Message message) {
  return {
    'role': mapRole(message.role),
    'parts': message.content.map(mapPart).toList(growable: false),
  };
}

/// Splits [messages] into `system_instructions` (messages with role `system`)
/// and the remaining conversation `messages`, each normalized to the GenAI
/// content schema.
NormalizedMessages normalizeMessages(List<Message> messages) {
  final system = <Map<String, Object?>>[];
  final rest = <Map<String, Object?>>[];
  for (final message in messages) {
    if (message.role.value == 'system') {
      // System instructions are represented by their parts directly.
      system.addAll(message.content.map(mapPart));
    } else {
      rest.add(mapMessage(message));
    }
  }
  return (messages: rest, systemInstructions: system);
}

/// Maps a response [message] to a GenAI output message map, attaching the
/// mapped [finishReason].
Map<String, Object?> mapOutputMessage(Message message, String finishReason) {
  return {...mapMessage(message), 'finish_reason': finishReason};
}

/// Resolves the effective response message.
///
/// Prefers the top-level [ModelResponse.message] and falls back to the legacy
/// `candidates[0].message` shape (deprecated, but still possible from some
/// providers / raw JSON). Returns null when neither is present.
///
/// `ModelResponse` has no typed `candidates` getter, so the legacy shape is
/// read from the backing JSON via [ModelResponse.toJson]. Malformed shapes fall
/// through to null rather than throwing.
Message? resolveResponseMessage(ModelResponse response) {
  if (response.message != null) return response.message;

  final candidates = response.toJson()['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final first = candidates.first;
    if (first is Map && first['message'] is Map) {
      return Message.fromJson(
        (first['message'] as Map).cast<String, dynamic>(),
      );
    }
  }
  return null;
}
