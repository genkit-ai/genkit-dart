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

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('Basic Types', () {
    test('stringSchema()', () {
      expect(SchemanticType.string().parse('hello'), 'hello');
      final json = SchemanticType.string().jsonSchema();
      expect(json['type'], 'string');
    });

    test('intSchema()', () {
      expect(SchemanticType.integer().parse(123), 123);
      final json = SchemanticType.integer().jsonSchema();
      expect(json['type'], 'integer');
    });

    test('listSchema with stringSchema()', () {
      final stringListParams = SchemanticType.list(.string());
      final json = ['a', 'b', 'c'];
      final parsed = stringListParams.parse(json);

      expect(parsed, isA<List<String>>());
      expect(parsed, ['a', 'b', 'c']);

      final schema = stringListParams.jsonSchema();
      final schemaJson = schema;

      // We expect this to be 'array'
      expect(schemaJson['type'], 'array');
      expect(schemaJson['items'], isNotNull);
      expect((schemaJson['items'] as Map)['type'], 'string');
    });

    test('listSchema with complex objects', () {
      final nestedList = SchemanticType.list(.list(.integer()));
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
      final schemaJson = schema;

      expect(schemaJson['type'], 'array');
      expect((schemaJson['items'] as Map)['type'], 'array');
      expect((schemaJson['items'] as Map)['items']['type'], 'integer');
    });

    test('doubleSchema()', () {
      expect(SchemanticType.doubleSchema().parse(12.34), 12.34);
      expect(
        SchemanticType.doubleSchema().parse(10),
        10.0,
      ); // Test int to double conversion
      final json = SchemanticType.doubleSchema().jsonSchema();
      expect(json['type'], 'number');
    });

    test('boolSchema()', () {
      expect(SchemanticType.boolean().parse(true), true);
      expect(SchemanticType.boolean().parse(false), false);
      final json = SchemanticType.boolean().jsonSchema();
      expect(json['type'], 'boolean');
    });

    test('voidSchema()', () {
      expect(() => SchemanticType.voidSchema().parse(null), returnsNormally);
      expect(
        () => SchemanticType.voidSchema().parse('anything'),
        returnsNormally,
      );
      final json = SchemanticType.voidSchema().jsonSchema();
      expect(json['type'], 'null');
    });

    test('dynamicSchema()', () {
      expect(SchemanticType.dynamicSchema().parse(123), 123);
      expect(SchemanticType.dynamicSchema().parse('hello'), 'hello');
      expect(SchemanticType.dynamicSchema().parse(true), true);
      expect(SchemanticType.dynamicSchema().parse(null), null);
      final list = [1, 2];
      expect(SchemanticType.dynamicSchema().parse(list), list);
      final map = {'a': 1};
      expect(SchemanticType.dynamicSchema().parse(map), map);

      final json = SchemanticType.dynamicSchema().jsonSchema();
      // schema.any() typically returns an empty schema {} which allows everything
      // In new impl we might return empty map or with description
      expect(json, isEmpty);
    });

    test('defaultValue in helpers', () {
      final s = SchemanticType.string(defaultValue: 'default');
      expect(s.jsonSchema()['default'], 'default');

      final i = SchemanticType.integer(defaultValue: 42);
      expect(i.jsonSchema()['default'], 42);

      final d = SchemanticType.doubleSchema(defaultValue: 3.14);
      expect(d.jsonSchema()['default'], 3.14);

      final b = SchemanticType.boolean(defaultValue: true);
      expect(b.jsonSchema()['default'], true);
    });

    test('MapType replacement', () {
      final mapT = SchemanticType.map(.string(), .dynamicSchema());
      final json = {'key': 'value', 'a': 1};
      expect(mapT.parse(json), json);
      final schemaJson = mapT.jsonSchema();
      expect(schemaJson['type'], 'object');
    });

    test('Parsing errors', () {
      expect(
        () => SchemanticType.integer().parse('not an int'),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => SchemanticType.list(.integer()).parse(['a']),
        throwsA(isA<TypeError>()),
      );
    });

    test('mapType with Strings and Ints', () {
      final mapT = SchemanticType.map(.string(), .integer());
      final json = {'a': 1, 'b': 2};
      final parsed = mapT.parse(json);
      expect(parsed, {'a': 1, 'b': 2});
      expect(parsed, isA<Map<String, int>>());

      final schemaJson = mapT.jsonSchema();
      expect(schemaJson['type'], 'object');
      expect((schemaJson['additionalProperties'] as Map)['type'], 'integer');
    });

    group('Reference Handling', () {
      test('listSchema with useRefs=true handles nested defs', () {
        final type = _MockType();
        final list = SchemanticType.list(type);
        final schema = list.jsonSchema(useRefs: true);
        final json = schema;

        // We expect $defs to be at the root, not inside items
        expect(json['type'], 'array');
        expect(json[r'$defs'], isNotNull, reason: 'Root should have defs');
        expect(
          (json['items'] as Map)[r'$ref'],
          isNotNull,
          reason: 'Items should refer to def',
        );
        expect(
          (json['items'] as Map)[r'$defs'],
          isNull,
          reason: 'Items should NOT have nested defs',
        );
      });

      test('mapSchema with useRefs=true handles nested defs', () {
        final type = _MockType();
        final mapT = SchemanticType.map(.string(), type);
        final schema = mapT.jsonSchema(useRefs: true);
        final json = schema;

        expect(json['type'], 'object');
        expect(json[r'$defs'], isNotNull, reason: 'Root should have defs');
        expect(
          (json['additionalProperties'] as Map)[r'$ref'],
          isNotNull,
          reason: 'additionalProperties should refer to def',
        );
        expect(
          (json['additionalProperties'] as Map)[r'$defs'],
          isNull,
          reason: 'additionalProperties should NOT have nested defs',
        );
      });
    });

    test('nullable()', () {
      final nullableString = SchemanticType.nullable(.string());
      expect(nullableString.parse('hello'), 'hello');
      expect(nullableString.parse(null), null);

      final json = nullableString.jsonSchema();
      expect(json['oneOf'], isNotNull);
      expect((json['oneOf'] as List)[0]['type'], 'null');
      expect((json['oneOf'] as List)[1]['type'], 'string');
    });

    test('nullable() round trip', () {
      final s = SchemanticType.nullable(.integer());
      expect(s.parse(123), 123);
      expect(s.parse(null), null);
    });

    test('nullable() with mapSchema (object)', () {
      final nullableMap = SchemanticType.nullable(.map(.string(), .integer()));

      // Test parsing map
      final mapValue = {'a': 1, 'b': 2};
      expect(nullableMap.parse(mapValue), mapValue);

      // Test parsing null
      expect(nullableMap.parse(null), null);

      // Test JSON schema
      final json = nullableMap.jsonSchema();
      expect(json['oneOf'], isNotNull);
      final oneOf = (json['oneOf'] as List).cast<Object?>();
      final nullTypeSource = oneOf.firstWhere(
        (s) => (s as Map)['type'] == 'null',
        orElse: () => null,
      );
      final objectTypeSource = oneOf.firstWhere(
        (s) => (s as Map)['type'] == 'object',
        orElse: () => null,
      );

      expect(nullTypeSource, isNotNull);
      expect(objectTypeSource, isNotNull);
      expect(
        (objectTypeSource as Map)['additionalProperties']['type'],
        'integer',
      );
    });

    test('nullable() idempotency', () {
      final s = SchemanticType.string();
      final n1 = SchemanticType.nullable(s);
      final n2 = SchemanticType.nullable(n1);

      expect(n2, same(n1));

      final json = n2.jsonSchema();
      // Should still be just one level of oneOf
      expect(json['oneOf'], isNotNull);
      expect((json['oneOf'] as List).length, 2);
      expect((json['oneOf'] as List)[0]['type'], 'null');
      expect((json['oneOf'] as List)[1]['type'], 'string');
    });
  });
}

final class _MockType extends SchemanticType<String> {
  @override
  String parse(Object? json) => json as String;

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    name: 'MockType',
    definition: jsb.Schema.string().value,
  );
}
