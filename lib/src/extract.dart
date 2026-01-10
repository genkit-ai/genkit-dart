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
dynamic extractJson(String text) {
  var jsonString = text;

  // Pattern to match markdown code blocks
  final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
  final match = codeBlockPattern.firstMatch(text);
  if (match != null) {
    jsonString = match.group(1)!;
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
  // A robust implementation would count braces, but this is often sufficient for extraction
  // from LLM output where the JSON is usually at the end or well-formed.
  final endChar = isObject ? '}' : ']';
  final end = jsonString.lastIndexOf(endChar);

  if (end == -1 || end < start) {
    throw FormatException('JSON object or array not closed');
  }

  final candidate = jsonString.substring(start, end + 1);

  try {
    return jsonDecode(candidate);
  } catch (e) {
    // If simple extraction fails, throw the original error or a specific one
    throw FormatException('Failed to parse extracted JSON: $e');
  }
}
