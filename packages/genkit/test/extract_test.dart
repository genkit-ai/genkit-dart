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
    final testCases = [
      (
        description: 'extracts simple object',
        input: '{"a": 1}',
        expected: {'a': 1},
        throws: false,
      ),
      (
        description: 'extracts simple array',
        input: '[1, 2, 3]',
        expected: [1, 2, 3],
        throws: false,
      ),
      (
        description: 'extracts from markdown block',
        input: 'Here is the json:\n```json\n{"a": 1}\n```',
        expected: {'a': 1},
        throws: false,
      ),
      (
        description: 'extracts from markdown block without lang',
        input: '```\n{"a": 1}\n```',
        expected: {'a': 1},
        throws: false,
      ),
      (
        description: 'extracts with surrounding text',
        input: 'prefix {"a": 1} suffix',
        expected: {'a': 1},
        throws: false,
      ),
      (
        description: 'extracts array with surrounding text',
        input: 'prefix [1, 2] suffix',
        expected: [1, 2],
        throws: false,
      ),
      (
        description: 'throws on no json',
        input: 'no json here',
        expected: null,
        throws: true,
      ),
      (
        description: 'throws on unclosed json',
        input: '{"a": 1',
        expected: null,
        throws: true,
      ),
      (
        description: 'throws on malformed json inside text',
        input: 'some text {"a": } end',
        expected: null,
        throws: true,
      ),
    ];

    for (final t in testCases) {
      test(t.description, () {
        if (t.throws) {
          expect(() => extractJson(t.input), throwsFormatException);
        } else {
          expect(extractJson(t.input), equals(t.expected));
        }
      });
    }
  });

  group('extractJson (partial)', () {
    final testCases = [
      (
        description: 'parses complete json',
        input: '{"a": 1}',
        expected: {'a': 1},
      ),
      (description: 'closes unclosed empty object', input: '{', expected: {}),
      (
        description: 'closes unclosed object',
        input: '{"a": 1',
        expected: {'a': 1},
      ),
      (description: 'closes unclosed empty array', input: '[', expected: []),
      (description: 'closes unclosed array', input: '[1, 2', expected: [1, 2]),
      (
        description: 'closes unclosed string',
        input: '{"a": "hello',
        expected: {'a': 'hello'},
      ),
      (
        description: 'closes bare nested array',
        input: '{"a": {"b": [',
        expected: {
          'a': {'b': []},
        },
      ),
      (
        description: 'closes nested array',
        input: '{"a": {"b": [1',
        expected: {
          'a': {
            'b': [1],
          },
        },
      ),
      (
        description: 'handles trailing comma in object',
        input: '{"a": 1,',
        expected: {'a': 1},
      ),
      (
        description: 'handles trailing comma in array',
        input: '[1,',
        expected: [1],
      ),
      (
        description: 'handles incomplete key-value pair',
        input: '{"a":',
        expected: {'a': null},
      ),
      (
        description: 'handles incomplete key-value pair with space',
        input: '{"a": ',
        expected: {'a': null},
      ),
      (
        description: 'handles partial string value with escaped quote',
        input: '{"a": "he\\"Mq',
        expected: {'a': 'he"Mq'},
      ),
      (
        description: 'handles partial string value with escaped characters',
        input: '{"a": "line1\\nline2',
        expected: {'a': 'line1\nline2'},
      ),
      (
        description: 'works with markdown blocks',
        input: '```json\n{"a": 1\n```',
        expected: {'a': 1},
      ),
      (
        description: 'works with unterminated markdown blocks',
        input: '```json\n{"a": "banana',
        expected: {'a': "banana"},
      ),
      (
        description: 'handles partial true',
        input: '{"a": tr',
        expected: {'a': true},
      ),
      (
        description: 'handles partial false',
        input: '{"a": fal',
        expected: {'a': false},
      ),
      (
        description: 'handles partial null',
        input: '{"a": nu',
        expected: {'a': null},
      ),
      (
        description: 'handles partial undefined',
        input: '{"a": unde',
        expected: {'a': null},
      ),
      (
        description: 'handles partial number with decimal point',
        input: '{"a": 12.',
        expected: {'a': 12},
      ),
      (
        description: 'handles deeply nested partial structure',
        input: '{"a": [{"b": {"c": [1, 2,',
        expected: {
          'a': [
            {
              'b': {
                'c': [1, 2],
              },
            },
          ],
        },
      ),
      (
        description: 'handles partial key',
        input: '{"ke',
        expected: {'ke': null},
      ),
      (
        description: 'handles partial key (quoted)',
        input: '{"key"',
        expected: {'key': null},
      ),
      (
        description: 'handles partial key (unquoted start)',
        input: '{"key',
        expected: {'key': null},
      ),
      (
        description: 'handles trailing garbage containing braces',
        input: '{"a": 1} }',
        expected: {'a': 1},
      ),
      (
        description: 'handles trailing garbage containing braces and text',
        input: '{"a": 1} some text }',
        expected: {'a': 1},
      ),
      (
        description: 'handles trailing comma with whitespace',
        input: '  \n\n{   \n    "a"   :       \n  1\n,  \n ',
        expected: {'a': 1},
      ),
      (
        description: 'handles trailing comma in array with whitespace',
        input: '     \n   [  1,  \n\n    2,\n   ',
        expected: [1, 2],
      ),
      (
        description:
            'does not treat array elements as object keys during repair',
        input:
            '{"title": "Creamy Avocado Pasta", "description": "A quick and easy vegetarian pasta dish featuring a rich, creamy sauce made from fresh avocados, lime, and herbs. It\'s a healthy and satisfying meal that comes together in minutes.", "prepTime": "15 minutes", "cookTime": "15 minutes", "servings": 4, "ingredients": ["2 ripe avocados, pitted and scooped", "250',
        expected: {
          "title": "Creamy Avocado Pasta",
          "description":
              "A quick and easy vegetarian pasta dish featuring a rich, creamy sauce made from fresh avocados, lime, and herbs. It's a healthy and satisfying meal that comes together in minutes.",
          "prepTime": "15 minutes",
          "cookTime": "15 minutes",
          "servings": 4,
          "ingredients": ["2 ripe avocados, pitted and scooped", "250"],
        },
      ),
      (
        description: 'handles truncated string with trailing backslash',
        input: '{"a": "hello\\',
        expected: {'a': 'hello'},
      ),
      (
        description: 'handles truncated number with exponent',
        input: '{"a": 1.2e',
        expected: {'a': 1.2},
      ),
      (
        description: 'handles truncated number with exponent and sign',
        input: '{"a": 1.2e+',
        expected: {'a': 1.2},
      ),
      (
        description: 'handles truncated number with capital exponent',
        input: '{"a": 1.2E-',
        expected: {'a': 1.2},
      ),
      (
        description: 'handles multiple objects with partial second one',
        input: '{"a": 1} {"b": 2',
        expected: {'a': 1},
      ),
      (
        description: 'handles partial json in markdown with trailing text',
        input: '```json\n{"a": 1\n``` more text',
        expected: {'a': 1},
      ),
      (
        description: 'closes unclosed nested string',
        input: '{"a": {"b": "hell',
        expected: {
          'a': {'b': 'hell'},
        },
      ),
      (
        description: 'handles partial boolean in array',
        input: '[true, fal',
        expected: [true, false],
      ),
      (
        description: 'handles partial null in array',
        input: '[1, n',
        expected: [1, null],
      ),
      (
        description: 'handles partial number in array',
        input: '[1, 2.',
        expected: [1, 2],
      ),
      (
        description: 'closes partial object in array',
        input: '[{"a": 1, "b"',
        expected: [
          {'a': 1, 'b': null},
        ],
      ),
      (
        description: 'handles partial key in nested object',
        input: '{"a": {"ke',
        expected: {
          'a': {'ke': null},
        },
      ),
      (
        description: 'handles nested incomplete key-value pair',
        input: '{"a": {"b":',
        expected: {
          'a': {'b': null},
        },
      ),
      (
        description: 'handles deeply nested mixed containers',
        input: '{"a": [{"b": {"c": [1, ',
        expected: {
          'a': [
            {
              'b': {
                'c': [1],
              },
            },
          ],
        },
      ),
      (
        description: 'handles multiple nested objects',
        input: '[{"a":1}, {"b":',
        expected: [
          {'a': 1},
          {'b': null},
        ],
      ),
      (
        description: 'handles truncated number in nested object',
        input: '{"a": {"b": 1.2e',
        expected: {
          'a': {'b': 1.2},
        },
      ),
      (
        description: 'handles partial string with space in key',
        input: '{"key with space',
        expected: {'key with space': null},
      ),
      (
        description: 'handles partial emoji in string',
        input: '{"a": "🌟st',
        expected: {'a': '🌟st'},
      ),
      (
        description: 'handles partial non-ASCII characters',
        input: '{"a": "ñó',
        expected: {'a': 'ñó'},
      ),
      (
        description: 'handles partial unicode escape',
        input: '{"a": "u\\u12',
        expected: {'a': "u\\u12"},
      ),
      (
        description: 'handles partial special character escape',
        input: '{"a": "hello\\n',
        expected: {'a': 'hello\n'},
      ),
      (description: 'returns null on empty string', input: '', expected: null),
      (
        description: 'returns null on whitespace-only string',
        input: '   \n  ',
        expected: null,
      ),
      (
        description: 'returns null on text with no JSON characters yet',
        input: 'Hello',
        expected: null,
      ),
    ];

    for (final t in testCases) {
      test(t.description, () {
        expect(extractJson(t.input, allowPartial: true), equals(t.expected));
      });
    }
  });
}
