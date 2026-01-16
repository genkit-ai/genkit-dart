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
import 'dart:convert';
import 'package:schemantic/schemantic.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

void main() {
  group('Basic Types', () {
    test('StringType', () {
      expect(StringType.parse('hello'), 'hello');
      final json = jsonDecode(StringType.jsonSchema().toJson());
      expect(json['type'], 'string');
    });

    test('IntType', () {
      expect(IntType.parse(123), 123);
      final json = jsonDecode(IntType.jsonSchema().toJson());
      expect(json['type'], 'integer');
    });

    test('listType with StringType', () {
      final stringListParams = listType(StringType);
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
      final nestedList = listType(listType(IntType));
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

    test('DoubleType', () {
      expect(DoubleType.parse(12.34), 12.34);
      expect(DoubleType.parse(10), 10.0); // Test int to double conversion
      final json = jsonDecode(DoubleType.jsonSchema().toJson());
      expect(json['type'], 'number');
    });

    test('BoolType', () {
      expect(BoolType.parse(true), true);
      expect(BoolType.parse(false), false);
      final json = jsonDecode(BoolType.jsonSchema().toJson());
      expect(json['type'], 'boolean');
    });

    test('VoidType', () {
      expect(() => VoidType.parse(null), returnsNormally);
      expect(() => VoidType.parse('anything'), returnsNormally);
      final json = jsonDecode(VoidType.jsonSchema().toJson());
      expect(json['type'], 'null');
    });

    test('DynamicType', () {
      expect(DynamicType.parse(123), 123);
      expect(DynamicType.parse('hello'), 'hello');
      expect(DynamicType.parse(true), true);
      expect(DynamicType.parse(null), null);
      final list = [1, 2];
      expect(DynamicType.parse(list), list);
      final map = {'a': 1};
      expect(DynamicType.parse(map), map);

      final json = jsonDecode(DynamicType.jsonSchema().toJson());
      // schema.any() typically returns an empty schema {} which allows everything
      expect(json, isEmpty);
    });

    test('MapType', () {
      final json = {'key': 'value', 'a': 1};
      expect(MapType.parse(json), json);
      final schemaJson = jsonDecode(MapType.jsonSchema().toJson());
      expect(schemaJson['type'], 'object');
    });

    test('Parsing errors', () {
      expect(() => IntType.parse('not an int'), throwsA(isA<TypeError>()));
      expect(() => listType(IntType).parse(['a']), throwsA(isA<TypeError>()));
    });

    test('mapType with Strings and Ints', () {
      final mapT = mapType(StringType, IntType);
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
        final mapT = mapType(StringType, type);
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

class _MockType extends JsonExtensionType<String> {
  @override
  String parse(Object json) => json as String;

  @override
  JsonSchemaMetadata? get schemaMetadata =>
      JsonSchemaMetadata(name: 'MockType', definition: jsb.Schema.string());
}
