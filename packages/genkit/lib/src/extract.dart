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

import 'dart:convert';

/// Extracts a JSON object or array from a string.
///
/// This function attempts to find the first JSON object or array in the text
/// and parse it. It handles common cases like markdown code blocks.
///
/// If [allowPartial] is true, it attempts to parse incomplete JSON by
/// repairing it (closing open braces, strings, etc.).
dynamic extractJson(String text, {bool allowPartial = false}) {
  var jsonString = text;

  var jsonBlock = _findJsonBlock(text, allowPartial: allowPartial);
  if (jsonBlock != null) {
    jsonString = jsonBlock;
  }

  // Find the first '{' or '['
  final firstOpenBrace = jsonString.indexOf('{');
  final firstOpenBracket = jsonString.indexOf('[');

  int start;
  bool isObject;

  if (firstOpenBrace < 0 && firstOpenBracket < 0) {
    if (allowPartial) return null;
    throw FormatException('No JSON object or array found');
  } else if (firstOpenBrace != -1 &&
      (firstOpenBracket < 0 || firstOpenBrace < firstOpenBracket)) {
    start = firstOpenBrace;
    isObject = true;
  } else {
    start = firstOpenBracket;
    isObject = false;
  }

  // Find the last matching '}' or ']'
  // Simple implementation: look for the last occurrence of the closing character
  final endChar = isObject ? '}' : ']';
  final end = jsonString.lastIndexOf(endChar);

  String candidate;
  if (end < 0 || end < start) {
    if (allowPartial) {
      candidate = jsonString.substring(start);
    } else {
      throw FormatException('JSON object or array not closed');
    }
  } else {
    candidate = jsonString.substring(start, end + 1);
  }

  try {
    return jsonDecode(candidate);
  } catch (e) {
    if (allowPartial) {
      try {
        // If simple parsing failed, try to repair using the substring from start to end
        // Note: we use substring(start) to include everything after start,
        // in case the found 'end' was premature or incorrect for the partial state.
        final repaired = _repairJson(jsonString.substring(start));
        return jsonDecode(repaired);
      } catch (_) {
        // If repair fails, throw the original error (or maybe the new one?)
        // Throwing original makes more sense if repair was just a best-effort.
        throw FormatException('Failed to parse extracted JSON: $e');
      }
    }
    // If simple extraction fails, throw the original error or a specific one
    throw FormatException('Failed to parse extracted JSON: $e');
  }
}

/// Looks for JSON code fence in text.
///
/// If [allowPartial] is `true`, allows the end delimiter to be missing.
String? _findJsonBlock(String text, {required bool allowPartial}) {
  const delimiter = '```';
  var start = text.indexOf(delimiter);
  if (start < 0) return null;
  start += delimiter.length;
  if (text.startsWith('json', start)) start += 'json'.length;
  var end = text.indexOf(delimiter, start);
  if (end < 0) {
    if (!allowPartial) return null;
    end = text.length;
  }
  return text.substring(start, end).trim();
}

/// Attempts to repair a partial JSON string by closing open strings and containers.
String _repairJson(String json) {
  var inString = false;
  var escaped = false;
  final stack = <String>[];

  for (var i = 0; i < json.length; i++) {
    final char = json[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
    } else {
      if (char == '"') {
        inString = true;
      } else if (char == '{') {
        stack.add('}');
      } else if (char == '[') {
        stack.add(']');
      } else if (char == '}' || char == ']') {
        if (stack.isNotEmpty && stack.last == char) {
          stack.removeLast();
          // If we just closed the last container, we are done!
          // This avoids including trailing garbage.
          if (stack.isEmpty) {
            return json.substring(0, i + 1);
          }
        }
      }
    }
  }

  var repaired = json;
  // 1. Close string if open.
  if (inString) {
    // If the string ends with an unescaped backslash, remove it
    // as it's a partial escape sequence.
    var s = repaired;
    if (escaped) {
      s = s.substring(0, s.length - 1);
    }
    // Handle partial \uXXXX escape by escaping the backslash.
    // Does not recognize if the `\` before `u` is itself escaped.
    s = s.replaceFirst(_unicodeEscapePrefixPattern, r'\');
    repaired = '$s"';
  } else {
    var endsWithWord = false;
    // Attempt to fix partial primitives (true, false, null)
    repaired = repaired.replaceFirstMapped(_trailingWordPattern, (match) {
      endsWithWord = true;
      var word = match[1]!;
      if ('undefined'.startsWith(word) || 'null'.startsWith(word)) {
        return 'null';
      }
      if ('true'.startsWith(word)) return 'true';
      if ('false'.startsWith(word)) return 'false';
      return word;
    });
    if (!endsWithWord) {
      // Remove trailing `.` or `[eE][+-]?`
      repaired = repaired.replaceFirst(_partialNumberSuffixPattern, '');
    }
  }

  // 2. Fix partial keys (e.g. {"key" -> {"key": null)
  if (stack.isNotEmpty &&
      stack.last == '}' &&
      _tailKeyPattern.hasMatch(repaired)) {
    repaired = '$repaired: null';
  }

  // 3. Handle trailing comma or colon
  final trimmed = repaired.trimRight();
  if (trimmed.endsWith(',')) {
    repaired = trimmed.substring(0, trimmed.length - 1);
  } else if (trimmed.endsWith(':')) {
    repaired = '$trimmed null';
  }

  // 4. Close stack
  repaired += stack.reversed.join('');

  return repaired;
}

final _trailingWordPattern = RegExp(r'\b([a-zA-Z]\w*)\s*$');

final _partialNumberSuffixPattern = RegExp(
  r'(?<=\b(?:\d+\.)?\d+)[.eE][\-+]?\s*$',
);

final _unicodeEscapePrefixPattern = RegExp(r'(?=\\u[0-9a-fA-F]{0,3}$)');

final _tailKeyPattern = RegExp(r'([{,])\s*("(?:[^"\\]|\\.)*")\s*$');
