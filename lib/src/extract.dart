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

  // Pattern to match markdown code blocks
  final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
  final match = codeBlockPattern.firstMatch(text);
  if (match != null) {
    jsonString = match.group(1)!;
  } else if (allowPartial) {
    // If partial allowed, try to match start of code block
    final startPattern = RegExp(r'```(?:json)?\s*([\s\S]*)');
    final startMatch = startPattern.firstMatch(text);
    if (startMatch != null) {
      jsonString = startMatch.group(1)!;
    }
  }

  // Find the first '{' or '['
  final firstOpenBrace = jsonString.indexOf('{');
  final firstOpenBracket = jsonString.indexOf('[');

  int start;
  bool isObject;

  if (firstOpenBrace == -1 && firstOpenBracket == -1) {
    throw FormatException('No JSON object or array found');
  } else if (firstOpenBrace != -1 &&
      (firstOpenBracket == -1 || firstOpenBrace < firstOpenBracket)) {
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
  if (end == -1 || end < start) {
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

/// Attempts to repair a partial JSON string by closing open strings and containers.
String _repairJson(String json) {
  var inString = false;
  var escaped = false;
  final stack = <String>[];
  final buffer = StringBuffer();

  for (var i = 0; i < json.length; i++) {
    final char = json[i];
    buffer.write(char);

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
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
            return buffer.toString();
          }
        }
      }
    }
  }

  var repaired = buffer.toString();

  // 1. Close string if open
  if (inString) {
    repaired += '"';
  } else {
    // Attempt to fix partial primitives (true, false, null)
    // and partial numbers.
    final truePattern = RegExp(r'(^|[\s{\[,:])(t(?:r(?:u(?:e)?)?)?)\s*$');
    final falsePattern = RegExp(
      r'(^|[\s{\[,:])(f(?:a(?:l(?:s(?:e)?)?)?)?)\s*$',
    );
    final nullPattern = RegExp(r'(^|[\s{\[,:])(n(?:u(?:l(?:l)?)?)?)\s*$');
    // undefined -> null
    final undefinedPattern = RegExp(
      r'(^|[\s{\[,:])(u(?:n(?:d(?:e(?:f(?:i(?:n(?:e(?:d)?)?)?)?)?)?)?)?)\s*$',
    );

    if (truePattern.hasMatch(repaired)) {
      repaired = repaired.replaceFirstMapped(
        truePattern,
        (m) => '${m.group(1)}true',
      );
    } else if (falsePattern.hasMatch(repaired)) {
      repaired = repaired.replaceFirstMapped(
        falsePattern,
        (m) => '${m.group(1)}false',
      );
    } else if (nullPattern.hasMatch(repaired)) {
      repaired = repaired.replaceFirstMapped(
        nullPattern,
        (m) => '${m.group(1)}null',
      );
    } else if (undefinedPattern.hasMatch(repaired)) {
      repaired = repaired.replaceFirstMapped(
        undefinedPattern,
        (m) => '${m.group(1)}null',
      );
    }

    // Fix partial number ending with dot
    final numberDotPattern = RegExp(r'(-?\d+)\.\s*$');
    if (numberDotPattern.hasMatch(repaired)) {
      repaired = repaired.replaceFirstMapped(
        numberDotPattern,
        (m) => '${m.group(1)}',
      );
    }
  }

  // 2. Fix partial keys (e.g. {"key" -> {"key": null)
  final tailStringPattern = RegExp(r'([{,])\s*("(?:[^"\\]|\\.)*")\s*$');
  if (tailStringPattern.hasMatch(repaired)) {
    repaired += ': null';
  }

  // 3. Handle trailing comma or colon
  final trimmed = repaired.trimRight();
  if (trimmed.isNotEmpty) {
    if (trimmed.endsWith(',')) {
      repaired = trimmed.substring(0, trimmed.length - 1);
    } else if (trimmed.endsWith(':')) {
      repaired = '${trimmed}null';
    }
  }

  // 4. Close stack
  while (stack.isNotEmpty) {
    repaired += stack.removeLast();
  }

  return repaired;
}
