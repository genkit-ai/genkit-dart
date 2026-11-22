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

import 'dart:convert';

/// A JSON value kept as the text it was given, so it reaches the server
/// unchanged.
///
/// A state parsed with `stateJSON` is one: decoding it would turn an integer
/// past 2^53 into a rounded double on the web, so the text goes on the wire
/// verbatim. It is checked to be JSON when it is made.
final class RawJson {
  /// Wraps [text], which must be one JSON value.
  ///
  /// Throws a [FormatException] when it is not.
  RawJson(String text) : text = text.trim() {
    jsonDecode(this.text);
  }

  /// The JSON text, trimmed.
  final String text;

  /// The value the text holds, decoded.
  Object? get value => jsonDecode(text);

  @override
  String toString() => text;
}

/// Encodes [value] as JSON, with any [RawJson] in it written as its text.
String encodeJson(Object? value) {
  final out = StringBuffer();
  _write(out, value);
  return out.toString();
}

void _write(StringBuffer out, Object? value) {
  switch (value) {
    case RawJson(:final text):
      out.write(text);
    case Map():
      out.write('{');
      var first = true;
      for (final entry in value.entries) {
        if (!first) out.write(',');
        first = false;
        out.write(jsonEncode(entry.key.toString()));
        out.write(':');
        _write(out, entry.value);
      }
      out.write('}');
    case Iterable():
      out.write('[');
      var first = true;
      for (final item in value) {
        if (!first) out.write(',');
        first = false;
        _write(out, item);
      }
      out.write(']');
    default:
      // Scalars, and objects with a toJson, which jsonEncode calls.
      out.write(jsonEncode(value));
  }
}
