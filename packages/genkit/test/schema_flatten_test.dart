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

import 'package:genkit/src/schema.dart';
import 'package:test/test.dart';

void main() {
  group('flattenSchema', () {
    test('returns simple schema as is', () {
      final schema = {
        'type': 'object',
        'properties': {
          'foo': {'type': 'string'},
        },
      };
      expect(flattenSchema(schema), equals(schema));
    });

    test('dereferences simple ref', () {
      final schema = {
        '\$defs': {
          'Foo': {'type': 'string', 'description': 'A string'},
        },
        'type': 'object',
        'properties': {
          'foo': {'\$ref': '#/\$defs/Foo'},
        },
      };

      final expected = {
        'type': 'object',
        'properties': {
          'foo': {'type': 'string', 'description': 'A string'},
        },
      };

      expect(flattenSchema(schema), equals(expected));
    });

    test('dereferences root ref', () {
      final schema = {
        r'$ref': r'#/$defs/WeatherToolInput',
        r'$defs': {
          'WeatherToolInput': {
            'type': 'object',
            'properties': {
              'location': {
                'type': 'string',
                'description':
                    'The location (ex. city, state, country) to get the weather for',
              },
            },
            'required': ['location'],
          },
        },
        r'$schema': 'http://json-schema.org/draft-07/schema#',
      };

      final expected = {
        'type': 'object',
        'properties': {
          'location': {
            'type': 'string',
            'description':
                'The location (ex. city, state, country) to get the weather for',
          },
        },
        'required': ['location'],
      };
      expect(flattenSchema(schema), equals(expected));
    });

    test('dereferences nested ref (transitive)', () {
      final schema = {
        '\$defs': {
          'Foo': {'\$ref': '#/\$defs/Bar'},
          'Bar': {'type': 'integer'},
        },
        'properties': {
          'item': {'\$ref': '#/\$defs/Foo'},
        },
      };

      final expected = {
        'properties': {
          'item': {'type': 'integer'},
        },
      };

      expect(flattenSchema(schema), equals(expected));
    });

    test('dereferences refs in array items', () {
      final schema = {
        '\$defs': {
          'Item': {'type': 'number'},
        },
        'type': 'array',
        'items': {'\$ref': '#/\$defs/Item'},
      };

      final expected = {
        'type': 'array',
        'items': {'type': 'number'},
      };

      expect(flattenSchema(schema), equals(expected));
    });

    test('dereferences refs in anyOf', () {
      final schema = {
        '\$defs': {
          'StringVal': {'type': 'string'},
          'IntVal': {'type': 'integer'},
        },
        'anyOf': [
          {'\$ref': '#/\$defs/StringVal'},
          {'\$ref': '#/\$defs/IntVal'},
        ],
      };

      final expected = {
        'anyOf': [
          {'type': 'string'},
          {'type': 'integer'},
        ],
      };

      expect(flattenSchema(schema), equals(expected));
    });

    test('throws on direct circular ref', () {
      final schema = {
        '\$defs': {
          'Node': {
            'properties': {
              'child': {'\$ref': '#/\$defs/Node'}, // Direct recursion
            },
          },
        },
        '\$ref': '#/\$defs/Node',
      };

      expect(() => flattenSchema(schema), throwsA(isA<FormatException>()));
    });

    test('throws on transitive circular ref', () {
      final schema = {
        '\$defs': {
          'A': {'\$ref': '#/\$defs/B'},
          'B': {'\$ref': '#/\$defs/A'},
        },
        '\$ref': '#/\$defs/A',
      };

      expect(() => flattenSchema(schema), throwsA(isA<FormatException>()));
    });

    test('handles deep nesting', () {
      final schema = {
        '\$defs': {
          'Leaf': {'type': 'boolean'},
          'Branch': {
            'type': 'object',
            'properties': {
              'leaf': {'\$ref': '#/\$defs/Leaf'},
            },
          },
        },
        'type': 'object',
        'properties': {
          'tree': {
            'type': 'array',
            'items': {'\$ref': '#/\$defs/Branch'},
          },
        },
      };

      final expected = {
        'type': 'object',
        'properties': {
          'tree': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'leaf': {'type': 'boolean'},
              },
            },
          },
        },
      };

      expect(flattenSchema(schema), equals(expected));
    });
  });
}
