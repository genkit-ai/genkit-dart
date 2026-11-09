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

import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('flatten', () {
    test('inlines a \$ref and strips \$defs', () {
      final schema = <String, Object?>{
        r'$ref': r'#/$defs/City',
        r'$defs': {
          'City': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        },
      };

      expect(schema.flatten(), {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
      });
    });

    test('a property named definitions is a property', () {
      final schema = <String, Object?>{
        'type': 'object',
        'properties': {
          'term': {'type': 'string'},
          'definitions': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['term', 'definitions'],
      };

      expect(schema.flatten(), schema);
    });

    test('keeps the keywords beside a \$ref', () {
      final schema = <String, Object?>{
        'type': 'object',
        'properties': {
          'code': {
            r'$ref': r'#/$defs/Code',
            'maxLength': 3,
            'description': 'Three letters',
          },
        },
        r'$defs': {
          'Code': {'type': 'string', 'description': 'A code'},
        },
      };

      expect(schema.flatten(), {
        'type': 'object',
        'properties': {
          'code': {
            'type': 'string',
            'maxLength': 3,
            'description': 'Three letters',
          },
        },
      });
    });

    test('still refuses a recursive schema', () {
      final schema = <String, Object?>{
        r'$ref': r'#/$defs/Node',
        r'$defs': {
          'Node': {
            'type': 'object',
            'properties': {
              'children': {
                'type': 'array',
                'items': {r'$ref': r'#/$defs/Node'},
              },
            },
          },
        },
      };

      expect(schema.flatten, throwsFormatException);
    });
  });
}
