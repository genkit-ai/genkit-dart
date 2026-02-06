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

// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('Basic Types', () {
    test('stringSchema()', () {
      expect(stringSchema().parse('hello'), 'hello');
      final json = jsonDecode(stringSchema().jsonSchema().toJson());
      expect(json['type'], 'string');
    });

    test('intSchema()', () {
      expect(intSchema().parse(123), 123);
      final json = jsonDecode(intSchema().jsonSchema().toJson());
      expect(json['type'], 'integer');
    });

    test('listSchema with stringSchema()', () {
      final stringListParams = listSchema(stringSchema());
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

    test('listSchema with complex objects', () {
      final nestedList = listSchema(listSchema(intSchema()));
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

    test('doubleSchema()', () {
      expect(doubleSchema().parse(12.34), 12.34);
      expect(doubleSchema().parse(10), 10.0); // Test int to double conversion
      final json = jsonDecode(doubleSchema().jsonSchema().toJson());
      expect(json['type'], 'number');
    });

    test('boolSchema()', () {
      expect(boolSchema().parse(true), true);
      expect(boolSchema().parse(false), false);
      final json = jsonDecode(boolSchema().jsonSchema().toJson());
      expect(json['type'], 'boolean');
    });

    test('voidSchema()', () {
      expect(() => voidSchema().parse(null), returnsNormally);
      expect(() => voidSchema().parse('anything'), returnsNormally);
      final json = jsonDecode(voidSchema().jsonSchema().toJson());
      expect(json['type'], 'null');
    });

    test('dynamicSchema()', () {
      expect(dynamicSchema().parse(123), 123);
      expect(dynamicSchema().parse('hello'), 'hello');
      expect(dynamicSchema().parse(true), true);
      expect(dynamicSchema().parse(null), null);
      final list = [1, 2];
      expect(dynamicSchema().parse(list), list);
      final map = {'a': 1};
      expect(dynamicSchema().parse(map), map);

      final json = jsonDecode(dynamicSchema().jsonSchema().toJson());
      // schema.any() typically returns an empty schema {} which allows everything
      // In new impl we might return empty map or with description
      expect(json, isEmpty);
    });

    test('defaultValue in helpers', () {
      final s = stringSchema(defaultValue: 'default');
      expect(jsonDecode(s.jsonSchema().toJson())['default'], 'default');

      final i = intSchema(defaultValue: 42);
      expect(jsonDecode(i.jsonSchema().toJson())['default'], 42);

      final d = doubleSchema(defaultValue: 3.14);
      expect(jsonDecode(d.jsonSchema().toJson())['default'], 3.14);

      final b = boolSchema(defaultValue: true);
      expect(jsonDecode(b.jsonSchema().toJson())['default'], true);
    });

    test('MapType replacement', () {
      final mapT = mapSchema(stringSchema(), dynamicSchema());
      final json = {'key': 'value', 'a': 1};
      expect(mapT.parse(json), json);
      final schemaJson = jsonDecode(mapT.jsonSchema().toJson());
      expect(schemaJson['type'], 'object');
    });

    test('Parsing errors', () {
      expect(() => intSchema().parse('not an int'), throwsA(isA<TypeError>()));
      expect(
        () => listSchema(intSchema()).parse(['a']),
        throwsA(isA<TypeError>()),
      );
    });

    test('mapType with Strings and Ints', () {
      final mapT = mapSchema(stringSchema(), intSchema());
      final json = {'a': 1, 'b': 2};
      final parsed = mapT.parse(json);
      expect(parsed, {'a': 1, 'b': 2});
      expect(parsed, isA<Map<String, int>>());

      final schemaJson = jsonDecode(mapT.jsonSchema().toJson());
      expect(schemaJson['type'], 'object');
      expect(schemaJson['additionalProperties']['type'], 'integer');
    });

    group('Reference Handling', () {
      test('listSchema with useRefs=true handles nested defs', () {
        final type = _MockType();
        final list = listSchema(type);
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

      test('mapSchema with useRefs=true handles nested defs', () {
        final type = _MockType();
        final mapT = mapSchema(stringSchema(), type);
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

    test('nullable()', () {
      final nullableString = nullable(stringSchema());
      expect(nullableString.parse('hello'), 'hello');
      expect(nullableString.parse(null), null);

      final json = jsonDecode(nullableString.jsonSchema().toJson());
      expect(json['oneOf'], isNotNull);
      expect(json['oneOf'][0]['type'], 'null');
      expect(json['oneOf'][1]['type'], 'string');
    });

    test('nullable() round trip', () {
      final s = nullable(intSchema());
      expect(s.parse(123), 123);
      expect(s.parse(null), null);
    });

    test('nullable() with mapSchema (object)', () {
      final nullableMap = nullable(mapSchema(stringSchema(), intSchema()));

      // Test parsing map
      final mapValue = {'a': 1, 'b': 2};
      expect(nullableMap.parse(mapValue), mapValue);

      // Test parsing null
      expect(nullableMap.parse(null), null);

      // Test JSON schema
      final json = jsonDecode(nullableMap.jsonSchema().toJson());
      expect(json['oneOf'], isNotNull);
      final nullTypeSource = json['oneOf'].firstWhere(
        (s) => s['type'] == 'null',
        orElse: () => null,
      );
      final objectTypeSource = json['oneOf'].firstWhere(
        (s) => s['type'] == 'object',
        orElse: () => null,
      );

      expect(nullTypeSource, isNotNull);
      expect(objectTypeSource, isNotNull);
      expect(objectTypeSource['additionalProperties']['type'], 'integer');
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
