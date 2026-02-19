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

  group('extractJson (partial)', () {
    test('parses complete json', () {
      expect(extractJson('{"a": 1}', allowPartial: true), equals({'a': 1}));
    });

    test('closes unclosed object', () {
      expect(extractJson('{"a": 1', allowPartial: true), equals({'a': 1}));
    });

    test('closes unclosed array', () {
      expect(extractJson('[1, 2', allowPartial: true), equals([1, 2]));
    });

    test('closes unclosed string', () {
      expect(
        extractJson('{"a": "hello', allowPartial: true),
        equals({'a': 'hello'}),
      );
    });

    test('closes nested structures', () {
      expect(
        extractJson('{"a": {"b": [1', allowPartial: true),
        equals({
          'a': {
            'b': [1],
          },
        }),
      );
    });

    test('handles trailing comma in object', () {
      expect(extractJson('{"a": 1,', allowPartial: true), equals({'a': 1}));
    });

    test('handles trailing comma in array', () {
      expect(extractJson('[1,', allowPartial: true), equals([1]));
    });

    test('handles incomplete key-value pair', () {
      expect(extractJson('{"a":', allowPartial: true), equals({'a': null}));
    });

    test('handles incomplete key-value pair with space', () {
      expect(extractJson('{"a": ', allowPartial: true), equals({'a': null}));
    });

    test('handles partial string value with escaped quote', () {
      expect(
        extractJson('{"a": "he\\"Mq', allowPartial: true),
        equals({'a': 'he"Mq'}),
      );
    });

    test('handles partial string value with escaped characters', () {
      expect(
        extractJson('{"a": "line1\\nline2', allowPartial: true),
        equals({'a': 'line1\nline2'}),
      );
    });

    test('works with markdown blocks', () {
      expect(
        extractJson('```json\n{"a": 1\n```', allowPartial: true),
        equals({'a': 1}),
      );
    });

    test('works with unterminated markdown blocks', () {
      expect(
        extractJson('```json\n{"a": "banana', allowPartial: true),
        equals({'a': "banana"}),
      );
    });

    test('handles partial true', () {
      expect(extractJson('{"a": tr', allowPartial: true), equals({'a': true}));
    });

    test('handles partial false', () {
      expect(
        extractJson('{"a": fal', allowPartial: true),
        equals({'a': false}),
      );
    });

    test('handles partial null', () {
      expect(extractJson('{"a": nu', allowPartial: true), equals({'a': null}));
    });

    test('handles partial undefined', () {
      expect(
        extractJson('{"a": unde', allowPartial: true),
        equals({'a': null}),
      );
    });

    test('handles partial number with decimal point', () {
      expect(extractJson('{"a": 12.', allowPartial: true), equals({'a': 12}));
    });

    test('handles deeply nested partial structure', () {
      final input = '{"a": [{"b": {"c": [1, 2,';
      // expect closing ] } ] }
      expect(
        extractJson(input, allowPartial: true),
        equals({
          'a': [
            {
              'b': {
                'c': [1, 2],
              },
            },
          ],
        }),
      );
    });

    test('handles partial key', () {
      expect(extractJson('{"ke', allowPartial: true), equals({'ke': null}));
    });

    test('handles partial key (quoted)', () {
      // '{"key"' -> '{"key": null}'
      expect(extractJson('{"key"', allowPartial: true), equals({'key': null}));
    });

    test('handles partial key (unquoted start)', () {
      // '{"key' -> '{"key": null}'
      expect(extractJson('{"key', allowPartial: true), equals({'key': null}));
    });

    test('handles trailing garbage containing braces', () {
      expect(extractJson('{"a": 1} }', allowPartial: true), equals({'a': 1}));
    });

    test('handles trailing garbage containing braces and text', () {
      expect(
        extractJson('{"a": 1} some text }', allowPartial: true),
        equals({'a': 1}),
      );
    });

    test('handles trailing comma with whitespace', () {
      expect(
        extractJson(
          '  \n\n{   \n    "a"   :       \n  1\n,  \n ',
          allowPartial: true,
        ),
        equals({'a': 1}),
      );
    });

    test('handles trailing comma in array with whitespace', () {
      expect(
        extractJson('     \n   [  1,  \n\n    2,\n   ', allowPartial: true),
        equals([1, 2]),
      );
    });

    test('handles incomplete string inside an array', () {
      expect(
        extractJson(
          '["1/4 cup lemon juice", "1/4 cup olive oil", "1/4 cup nutritional yeast (optional, for cheesy',
          allowPartial: true,
        ),
        equals([
          "1/4 cup lemon juice",
          "1/4 cup olive oil",
          "1/4 cup nutritional yeast (optional, for cheesy",
        ]),
      );
    });
  });
}
