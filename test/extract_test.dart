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

import 'package:genkit/src/extract.dart';
import 'package:test/test.dart';

void main() {
  group('extractJson', () {
    test('extracts simple object', () {
      final input = '{"a": 1}';
      expect(extractJson(input), equals({'a': 1}));
    });

    test('extracts simple array', () {
      final input = '[1, 2, 3]';
      expect(extractJson(input), equals([1, 2, 3]));
    });

    test('extracts from markdown block', () {
      final input = 'Here is the json:\n```json\n{"a": 1}\n```';
      expect(extractJson(input), equals({'a': 1}));
    });

    test('extracts from markdown block without lang', () {
      final input = '```\n{"a": 1}\n```';
      expect(extractJson(input), equals({'a': 1}));
    });

    test('extracts with surrounding text', () {
      final input = 'prefix {"a": 1} suffix';
      expect(extractJson(input), equals({'a': 1}));
    });

    test('extracts array with surrounding text', () {
      final input = 'prefix [1, 2] suffix';
      expect(extractJson(input), equals([1, 2]));
    });

    test('throws on no json', () {
      final input = 'no json here';
      expect(() => extractJson(input), throwsFormatException);
    });

    test('throws on unclosed json', () {
      final input = '{"a": 1';
      expect(() => extractJson(input), throwsFormatException);
    });

    test('throws on malformed json inside text', () {
      final input = 'some text {"a": } end';
      expect(() => extractJson(input), throwsFormatException);
    });
  });
}
