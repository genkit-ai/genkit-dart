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
    ),
  },
);

@Schematic()
final Schema arraySchema = Schema.list(
  items: Schema.object(properties: {'value': Schema.integer()}),
);

@Schematic()
final Schema allPrimitivesSchema = Schema.object(
  properties: {
    'str': Schema.string(),
    'intNum': Schema.integer(),
    'dblNum': Schema.number(),
    'isTruth': Schema.boolean(),
  },
);

@Schematic()
final Schema complexCollectionsSchema = Schema.object(
  properties: {
    'matrix': Schema.list(items: Schema.list(items: Schema.string())),
    'objectList': Schema.list(
      items: Schema.object(properties: {'id': Schema.string()}),
    ),
  },
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

  group('All Primitives Schema', () {
    test('parses all primitives', () {
      final json = {
        'str': 'hello',
        'intNum': 42,
        'dblNum': 3.14,
        'isTruth': true,
      };
      final obj = allPrimitivesSchemaType.parse(json);
      expect(obj.str, 'hello');
      expect(obj.intNum, 42);
      expect(obj.dblNum, 3.14);
      expect(obj.isTruth, true);
    });

    test('validates types strictly (runtime)', () {
      final json = {
        'str': 123, // Invalid
        'intNum': 42,
        'dblNum': 3.14,
        'isTruth': true,
      };
      // Expect type error on access because properties cast on access
      final obj = allPrimitivesSchemaType.parse(json);
      expect(() => obj.str, throwsA(isA<TypeError>()));
    });
  });

  group('Complex Collections Schema', () {
    test('parses matrix (List<List<String>>)', () {
      final json = {
        'matrix': [
          ['a', 'b'],
          ['c', 'd'],
        ],
        'objectList': [],
      };
      final obj = complexCollectionsSchemaType.parse(json);
      expect(obj.matrix, isA<List<List<String>>>());
      expect(obj.matrix[0], ['a', 'b']);
      expect(obj.matrix[1], ['c', 'd']);
    });

    test('parses object list', () {
      final json = {
        'matrix': [],
        'objectList': [
          {'id': '1'},
          {'id': '2'},
        ],
      };
      final obj = complexCollectionsSchemaType.parse(json);
      expect(
        obj.objectList,
        isA<List<ComplexCollectionsSchemaObjectListItem>>(),
      );
      expect(obj.objectList.length, 2);
      expect(obj.objectList[0].id, '1');
      expect(obj.objectList[1].id, '2');
    });
  });
}
