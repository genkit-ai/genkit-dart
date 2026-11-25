// Copyright 2026 Google LLC
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

/// OpenAI only accepts a `json_schema` response format whose root is
/// `type: "object"`. For such a host, a schema with any other root (array,
/// enum, scalar, `anyOf`) is sent wrapped in an object, and the reply is
/// unwrapped before Genkit parses it. See `OpenAIProvider.objectSchemaRoot`.
library;

import 'dart:convert';

import 'package:genkit/plugin.dart';

/// The property that holds the caller's value inside the wrapper object.
const wrapperKey = 'value';

/// Whether [schema]'s root is explicitly an object. Anything else, including
/// `properties` without a `type` (which also allows non-object values), is
/// wrapped.
bool hasObjectRoot(Map<String, dynamic> schema) => schema['type'] == 'object';

/// Wraps [schema] as the single required property of an object schema.
///
/// The schema has already been flattened, so it holds no `$ref` or `$defs`
/// that the move could break. `$schema` stays at the root.
Map<String, dynamic> wrapSchemaRoot(Map<String, dynamic> schema) {
  final inner = Map<String, dynamic>.of(schema)..remove(r'$schema');
  return {
    if (schema.containsKey(r'$schema')) r'$schema': schema[r'$schema'],
    'type': 'object',
    'properties': {wrapperKey: inner},
    'required': [wrapperKey],
    'additionalProperties': false,
  };
}

/// A reply in a markdown code fence; the closing fence may be cut off.
final _fenced = RegExp(r'^\s*```(?:json)?\s*([\s\S]*?)\s*(?:```\s*)?$');

/// Returns the wrapped value's JSON from [text], or [text] unchanged when it
/// isn't a wrapper object (a host that ignored the schema may reply with the
/// bare value, or with an object that merely has a `value` key).
///
/// The wrapper is stripped as text, as [WrapperStreamUnwrapper] does while
/// streaming, so a reply cut off mid-value is unwrapped as far as it goes and
/// the value is never re-encoded.
String unwrapText(String text) {
  final body = _fenced.firstMatch(text)?.group(1) ?? text;
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map ||
        decoded.length != 1 ||
        !decoded.containsKey(wrapperKey)) {
      return text;
    }
  } on FormatException {
    // Incomplete, such as a reply cut off by maxTokens.
  }
  final unwrapper = WrapperStreamUnwrapper();
  final unwrapped = unwrapper.push(body) + unwrapper.flush();
  return unwrapped == body ? text : unwrapped;
}

/// Replaces the text of a wrapped reply with the wrapped value. Text beside
/// a tool call is a preamble, not the output, and is left alone.
Message unwrapMessage(Message message) {
  if (message.content.any((part) => part.isToolRequest)) return message;
  return Message(
    role: message.role,
    metadata: message.metadata,
    content: [
      for (final part in message.content)
        if (part.isText)
          TextPart.fromJson({...part.toJson(), 'text': unwrapText(part.text!)})
        else
          part,
    ],
  );
}

/// The wrapper's opening, as the tokens it is made of. Whitespace may sit
/// before and between them.
const _prefixTokens = ['{', '"$wrapperKey"', ':'];

final _space = RegExp(r'\s');

/// Matches the start of [text] against the wrapper's opening. Returns the
/// opening's length (trailing whitespace included) when it is all there, 0
/// when [text] could still become it, and -1 when it cannot.
int _matchPrefix(String text) {
  var i = 0;
  void skipSpace() {
    while (i < text.length && _space.hasMatch(text[i])) {
      i++;
    }
  }

  for (final token in _prefixTokens) {
    skipSpace();
    final end = i + token.length < text.length ? i + token.length : text.length;
    final rest = text.substring(i, end);
    if (rest != token) {
      return token.startsWith(rest) && end == text.length ? 0 : -1;
    }
    i += token.length;
  }
  skipSpace();
  return i;
}

final _trailing = RegExp(r'[\s}]*$');

/// Strips the `{"value":` prefix and the closing `}` from streamed text, so
/// chunks read as the caller's value (such as `[{...},` for an array) and the
/// format's chunk parser sees what it expects.
///
/// Text is held back for as long as it could still be the start of the
/// wrapper, so the result does not depend on how the stream is split.
/// Trailing whitespace and braces are then held until more text arrives,
/// because the last `}` belongs to the wrapper only if nothing follows it;
/// [flush] drops it. A reply that is not a wrapper passes through unchanged.
class WrapperStreamUnwrapper {
  bool _started = false;
  bool _wrapped = false;
  bool _passing = false;
  bool _valueStarted = false;
  String _head = '';
  String _held = '';

  /// Takes a streamed delta and returns the text to emit for it, which may
  /// be empty.
  String push(String delta) {
    if (_passing) return delta;
    if (_started) return _release(delta);
    _head += delta;
    final match = _matchPrefix(_head);
    if (match == 0) return '';
    _started = true;
    var out = _head;
    _head = '';
    if (match > 0) {
      _wrapped = true;
      out = out.substring(match);
    }
    return _release(out);
  }

  String _release(String text) {
    var all = _held + text;
    // Whitespace after the colon belongs to the wrapper too, however much of
    // it arrives after the opening matched.
    if (_wrapped && !_valueStarted) {
      all = all.trimLeft();
      _valueStarted = all.isNotEmpty;
    }
    final cut = _trailing.firstMatch(all)!.start;
    _held = all.substring(cut);
    return all.substring(0, cut);
  }

  /// Gives up unwrapping, for a reply that turns out not to be the output
  /// (text before a tool call), and returns the text held back so far.
  String passThrough() {
    _started = true;
    _passing = true;
    final out = _head + _held;
    _head = '';
    _held = '';
    return out;
  }

  /// Returns what is left at the end of the stream: anything held except the
  /// wrapper's closing brace and the whitespace around it.
  String flush() {
    if (_passing) return '';
    if (!_started) {
      final out = _head;
      _head = '';
      return out;
    }
    var text = _held;
    _held = '';
    if (!_wrapped) return text;
    final i = text.lastIndexOf('}');
    if (i >= 0) text = text.substring(0, i);
    return text.trimRight();
  }
}
