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
  group('serialize', () {
    test('scalars round trip', () {
      final s = SchemanticType.string();
      expect(s.serialize(s.parse('hello')), 'hello');

      final i = SchemanticType.integer();
      expect(i.serialize(i.parse(42)), 42);

      final d = SchemanticType.doubleSchema();
      expect(d.serialize(d.parse(12.34)), 12.34);

      final b = SchemanticType.boolean();
      expect(b.serialize(b.parse(true)), true);
    });

    test('list round trips to plain JSON', () {
      final schema = SchemanticType.list(.string());
      final value = schema.parse(['a', 'b', 'c']);
      final serialized = schema.serialize(value);

      expect(serialized, ['a', 'b', 'c']);
      expect(serialized, isA<List<Object?>>());
    });

    test('map round trips to plain JSON', () {
      final schema = SchemanticType.map(.string(), .integer());
      final value = schema.parse({'a': 1, 'b': 2});
      final serialized = schema.serialize(value);

      expect(serialized, {'a': 1, 'b': 2});
      expect(serialized, isA<Map<String, Object?>>());
    });

    test('nested list of maps round trips', () {
      final schema = SchemanticType.list(.map(.string(), .integer()));
      final input = [
        {'a': 1},
        {'b': 2},
      ];
      final serialized = schema.serialize(schema.parse(input));

      expect(serialized, input);
    });

    test('nullable serializes null and value', () {
      final schema = SchemanticType.nullable(.integer());
      expect(schema.serialize(schema.parse(null)), null);
      expect(schema.serialize(schema.parse(7)), 7);
    });

    group('SchemanticType.from', () {
      final personSchema = {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
      };

      test('uses the provided serialize callback (BYO serialization)', () {
        final schema = SchemanticType.from<_Person>(
          jsonSchema: personSchema,
          parse: (json) {
            final map = json as Map<String, Object?>;
            return _Person(name: map['name'] as String, age: map['age'] as int);
          },
          serialize: (p) => {'name': p.name, 'age': p.age},
        );

        final person = schema.parse({'name': 'Bob', 'age': 25});
        final serialized = schema.serialize(person);

        expect(serialized, {'name': 'Bob', 'age': 25});
        // Round trips back into an equal object.
        final reparsed = schema.parse(serialized);
        expect(reparsed.name, 'Bob');
        expect(reparsed.age, 25);
      });

      test('default serialize falls back to toJson()', () {
        final schema = SchemanticType.from<_Widget>(
          jsonSchema: {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
            },
          },
          parse: (json) =>
              _Widget((json as Map<String, Object?>)['id'] as String),
        );

        final serialized = schema.serialize(_Widget('w1'));
        expect(serialized, {'id': 'w1'});
      });
    });
  });
}

class _Person {
  final String name;
  final int age;

  _Person({required this.name, required this.age});
}

class _Widget {
  final String id;

  _Widget(this.id);

  Map<String, Object?> toJson() => {'id': id};
}
