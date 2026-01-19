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

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('Basic Types', () {
    test('stringType()', () {
      expect(stringType().parse('hello'), 'hello');
      final json = jsonDecode(stringType().jsonSchema().toJson());
      expect(json['type'], 'string');
    });

    test('intType()', () {
      expect(intType().parse(123), 123);
      final json = jsonDecode(intType().jsonSchema().toJson());
      expect(json['type'], 'integer');
    });

    test('listType with stringType()', () {
      final stringListParams = listType(stringType());
      final json = ['a', 'b', 'c'];
      final parsed = stringListParams.parse(json);

      expect(parsed, isA<List<String>>());
      expect(parsed, ['a', 'b', 'c']);

      final schema = stringListParams.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());

      // We expect this to be 'array'
      expect(schemaJson['type'], 'array');
      expect(schemaJson['items'], isNotNull);
      expect(schemaJson['items']['type'], 'string');
    });

    test('listType with complex objects', () {
      final nestedList = listType(listType(intType()));
      final json = [
        [1, 2],
        [3, 4],
      ];
      final parsed = nestedList.parse(json);

      expect(parsed, isA<List<List<int>>>());
      expect(parsed, [
        [1, 2],
        [3, 4],
      ]);

      final schema = nestedList.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());

      expect(schemaJson['type'], 'array');
      expect(schemaJson['items']['type'], 'array');
      expect(schemaJson['items']['items']['type'], 'integer');
    });

    test('doubleType()', () {
      expect(doubleType().parse(12.34), 12.34);
      expect(doubleType().parse(10), 10.0); // Test int to double conversion
      final json = jsonDecode(doubleType().jsonSchema().toJson());
      expect(json['type'], 'number');
    });

    test('boolType()', () {
      expect(boolType().parse(true), true);
      expect(boolType().parse(false), false);
      final json = jsonDecode(boolType().jsonSchema().toJson());
      expect(json['type'], 'boolean');
    });

    test('voidType()', () {
      expect(() => voidType().parse(null), returnsNormally);
      expect(() => voidType().parse('anything'), returnsNormally);
      final json = jsonDecode(voidType().jsonSchema().toJson());
      expect(json['type'], 'null');
    });

    test('dynamicType()', () {
      expect(dynamicType().parse(123), 123);
      expect(dynamicType().parse('hello'), 'hello');
      expect(dynamicType().parse(true), true);
      expect(dynamicType().parse(null), null);
      final list = [1, 2];
      expect(dynamicType().parse(list), list);
      final map = {'a': 1};
      expect(dynamicType().parse(map), map);

      final json = jsonDecode(dynamicType().jsonSchema().toJson());
      // schema.any() typically returns an empty schema {} which allows everything
      // In new impl we might return empty map or with description
      expect(json, isEmpty);
    });

    test('MapType replacement', () {
      final mapT = mapType(stringType(), dynamicType());
      final json = {'key': 'value', 'a': 1};
      expect(mapT.parse(json), json);
      final schemaJson = jsonDecode(mapT.jsonSchema().toJson());
      expect(schemaJson['type'], 'object');
    });

    test('Parsing errors', () {
      expect(() => intType().parse('not an int'), throwsA(isA<TypeError>()));
      expect(() => listType(intType()).parse(['a']), throwsA(isA<TypeError>()));
    });

    test('mapType with Strings and Ints', () {
      final mapT = mapType(stringType(), intType());
      final json = {'a': 1, 'b': 2};
      final parsed = mapT.parse(json);
      expect(parsed, {'a': 1, 'b': 2});
      expect(parsed, isA<Map<String, int>>());

      final schemaJson = jsonDecode(mapT.jsonSchema().toJson());
      expect(schemaJson['type'], 'object');
      expect(schemaJson['additionalProperties']['type'], 'integer');
    });

    group('Reference Handling', () {
      test('listType with useRefs=true handles nested defs', () {
        final type = _MockType();
        final list = listType(type);
        final schema = list.jsonSchema(useRefs: true);
        final json = jsonDecode(schema.toJson());

        // We expect $defs to be at the root, not inside items
        expect(json['type'], 'array');
        expect(json[r'$defs'], isNotNull, reason: 'Root should have defs');
        expect(
          json['items'][r'$ref'],
          isNotNull,
          reason: 'Items should refer to def',
        );
        expect(
          json['items'][r'$defs'],
          isNull,
          reason: 'Items should NOT have nested defs',
        );
      });

      test('mapType with useRefs=true handles nested defs', () {
        final type = _MockType();
        final mapT = mapType(stringType(), type);
        final schema = mapT.jsonSchema(useRefs: true);
        final json = jsonDecode(schema.toJson());

        expect(json['type'], 'object');
        expect(json[r'$defs'], isNotNull, reason: 'Root should have defs');
        expect(
          json['additionalProperties'][r'$ref'],
          isNotNull,
          reason: 'additionalProperties should refer to def',
        );
        expect(
          json['additionalProperties'][r'$defs'],
          isNull,
          reason: 'additionalProperties should NOT have nested defs',
        );
      });
    });
  });
}

class _MockType extends SchemanticType<String> {
  @override
  String parse(Object? json) => json as String;

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      JsonSchemaMetadata(name: 'MockType', definition: jsb.Schema.string());
}
