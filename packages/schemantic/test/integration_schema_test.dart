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

import 'package:test/test.dart';
import 'package:schemantic/schemantic.dart';

part 'integration_schema_test.schema.g.dart';

@Schematic()
final Schema simpleObjectSchema = Schema.object(
  properties: {
    'name': Schema.string(),
    'count': Schema.integer(),
    'isActive': Schema.boolean(),
  },
  additionalProperties: false,
);

@Schematic()
final Schema nestedObjectSchema = Schema.object(
  properties: {
    'id': Schema.string(),
    'metadata': Schema.object(
      properties: {
        'created': Schema.string(),
        'tags': Schema.list(items: Schema.string()),
      },
      additionalProperties: false,
    ),
  },
  additionalProperties: false,
);

@Schematic()
final Schema arraySchema = Schema.list(
  items: Schema.object(
    properties: {'value': Schema.integer()},
    additionalProperties: false,
  ),
);

void main() {
  group('Simple Object Schema', () {
    test('parses valid json', () {
      final json = {'name': 'test', 'count': 10, 'isActive': true};
      final obj = simpleObjectSchemaType.parse(json);
      expect(obj.name, 'test');
      expect(obj.count, 10);
      expect(obj.isActive, true);
    });

    test('toJson returns correct map', () {
      final obj = SimpleObjectSchema.from(
        name: 'test',
        count: 10,
        isActive: false,
      );
      expect(obj.toJson(), {'name': 'test', 'count': 10, 'isActive': false});
    });
  });

  group('Nested Object Schema', () {
    test('parses nested structure', () {
      final json = {
        'id': '123',
        'metadata': {
          'created': '2025-01-01',
          'tags': ['a', 'b'],
        },
      };
      final obj = nestedObjectSchemaType.parse(json);
      expect(obj.id, '123');
      expect(obj.metadata.created, '2025-01-01');
      expect(obj.metadata.tags, ['a', 'b']);
    });
  });

  group('Array Schema', () {
    test('parses array of objects', () {
      final json = [
        {'value': 1},
        {'value': 2},
      ];
      final list = arraySchemaType.parse(json);
      expect(list, isA<List>());
      expect(list.length, 2);
      expect(list.first, isA<ArraySchemaItem>());
      expect(list[0].value, 1);
      expect(list[1].value, 2);
    });
  });
}
