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

import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

void main() {
  group('SchemanticType.from', () {
    final sampleSchema = {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'age': {'type': 'integer'},
      },
    };

    test('parses valid input', () {
      final schema = SchemanticType.from<Map<String, Object?>>(
        jsonSchema: sampleSchema,
        parse: (json) => json as Map<String, Object?>,
      );

      final input = {'name': 'Alice', 'age': 30};
      final parsed = schema.parse(input);

      expect(parsed, input);
    });

    test('returns the correct jsonSchema', () {
      final schema = SchemanticType.from<Map<String, Object?>>(
        jsonSchema: sampleSchema,
        parse: (json) => json as Map<String, Object?>,
      );

      final resultSchema = schema.jsonSchema();

      expect(resultSchema['type'], 'object');
      expect(resultSchema['properties'], contains('name'));
    });

    test('returns a copy of jsonSchema to prevent mutation', () {
      final schema = SchemanticType.from<Map<String, Object?>>(
        jsonSchema: sampleSchema,
        parse: (json) => json as Map<String, Object?>,
      );

      final result1 = schema.jsonSchema();
      result1['new_key'] = 'value';

      final result2 = schema.jsonSchema();
      expect(result2, isNot(contains('new_key')));
    });

    test('works with SchemanticType.list', () {
      final personSchema = SchemanticType.from<_Person>(
        jsonSchema: sampleSchema,
        parse: (json) {
          final map = json as Map<String, Object?>;
          return _Person(name: map['name'] as String, age: map['age'] as int);
        },
      );

      final listSchema = SchemanticType.list(personSchema);
      final parsed = listSchema.parse([
        {'name': 'Bob', 'age': 25},
        {'name': 'Alice', 'age': 30},
      ]);

      expect(parsed, isA<List<_Person>>());
      expect(parsed[0].name, 'Bob');
      expect(parsed[1].name, 'Alice');

      final schemaJson = listSchema.jsonSchema();
      expect(schemaJson['type'], 'array');
    });

    test('works with SchemanticType.map', () {
      final personSchema = SchemanticType.from<_Person>(
        jsonSchema: sampleSchema,
        parse: (json) {
          final map = json as Map<String, Object?>;
          return _Person(name: map['name'] as String, age: map['age'] as int);
        },
      );

      final mapSchema = SchemanticType.map(.string(), personSchema);
      final parsed = mapSchema.parse({
        'p1': {'name': 'Bob', 'age': 25},
        'p2': {'name': 'Alice', 'age': 30},
      });

      expect(parsed, isA<Map<String, _Person>>());
      expect(parsed['p1']!.name, 'Bob');
      expect(parsed['p2']!.name, 'Alice');

      final schemaJson = mapSchema.jsonSchema(useRefs: true);
      expect(schemaJson, {
        'type': 'object',
        'additionalProperties': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'age': {'type': 'integer'},
          },
        },
      });
    });

    test('works with custom classes', () {
      final schema = SchemanticType.from<_Person>(
        jsonSchema: sampleSchema,
        parse: (json) {
          final map = json as Map<String, Object?>;
          return _Person(name: map['name'] as String, age: map['age'] as int);
        },
      );

      final parsed = schema.parse({'name': 'Bob', 'age': 25});

      expect(parsed.name, 'Bob');
      expect(parsed.age, 25);
    });
  });
}

class _Person {
  final String name;
  final int age;

  _Person({required this.name, required this.age});
}
