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
import 'package:schemantic/src/basic_types.dart';

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
  });
}
