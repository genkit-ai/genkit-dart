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

    test('nested custom serialized types inside list, map, and nullable', () {
      final customInt = SchemanticType.from<int>(
        jsonSchema: {'type': 'integer'},
        parse: (json) => (json as int) + 1,
        serialize: (val) => val - 1,
      );

      final listSchema = SchemanticType.list(customInt);
      expect(listSchema.serialize([3, 4]), [2, 3]);

      final mapSchema = SchemanticType.map(SchemanticType.string(), customInt);
      expect(mapSchema.serialize({'a': 3}), {'a': 2});

      final nullableSchema = SchemanticType.nullable(customInt);
      expect(nullableSchema.serialize(3), 2);
      expect(nullableSchema.serialize(null), null);
    });

    test('throws ArgumentError when value cannot be serialized', () {
      final schema = SchemanticType.from<_Opaque>(
        jsonSchema: {'type': 'object'},
        parse: (json) => _Opaque(),
      );

      expect(() => schema.serialize(_Opaque()), throwsArgumentError);
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

      test('default serialize recurses into nested toJson() results', () {
        // _Container.toJson() returns a map holding a raw _Widget (a non-JSON
        // domain object). The default serializer should normalize it to plain
        // JSON rather than leaking the object.
        final schema = SchemanticType.from<_Container>(
          jsonSchema: {'type': 'object'},
          parse: (json) => _Container(_Widget('w1')),
        );

        final serialized = schema.serialize(_Container(_Widget('w2')));
        expect(serialized, {
          'widget': {'id': 'w2'},
        });
      });

      test('default serialize throws for nested non-serializable values', () {
        final schema = SchemanticType.from<_OpaqueContainer>(
          jsonSchema: {'type': 'object'},
          parse: (json) => _OpaqueContainer(),
        );

        expect(() => schema.serialize(_OpaqueContainer()), throwsArgumentError);
      });
    });

    group('generated schema types', () {
      // Mirrors the shape of code emitted by schemantic_builder: a
      // SchemanticType factory whose parse() wraps the JSON map and whose
      // values expose a toJson(). This exercises the default serialize path
      // (the headline use case) end to end.
      test('default serialize round trips a generated-style type', () {
        final person = _GeneratedPerson.$schema.parse({
          'name': 'Alice',
          'age': 30,
        });

        final serialized = _GeneratedPerson.$schema.serialize(person);

        expect(serialized, {'name': 'Alice', 'age': 30});
        // Round trips back into an equal object.
        final reparsed = _GeneratedPerson.$schema.parse(serialized);
        expect(reparsed.name, 'Alice');
        expect(reparsed.age, 30);
      });

      test('generated-style types serialize inside list and map', () {
        final listSchema = SchemanticType.list(_GeneratedPerson.$schema);
        final list = listSchema.parse([
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ]);
        expect(listSchema.serialize(list), [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ]);

        final mapSchema = SchemanticType.map(
          SchemanticType.string(),
          _GeneratedPerson.$schema,
        );
        final map = mapSchema.parse({
          'a': {'name': 'Alice', 'age': 30},
        });
        expect(mapSchema.serialize(map), {
          'a': {'name': 'Alice', 'age': 30},
        });
      });
    });
  });
}

/// A stand-in for a `@Schema`-generated data class (see the shape produced by
/// schemantic_builder): backed by a JSON map with a `toJson()` method.
class _GeneratedPerson {
  _GeneratedPerson._(this._json);

  static const SchemanticType<_GeneratedPerson> $schema =
      _GeneratedPersonFactory();

  final Map<String, dynamic> _json;

  String get name => _json['name'] as String;
  int get age => _json['age'] as int;

  Map<String, dynamic> toJson() => _json;
}

final class _GeneratedPersonFactory extends SchemanticType<_GeneratedPerson> {
  const _GeneratedPersonFactory();

  @override
  _GeneratedPerson parse(Object? json) =>
      _GeneratedPerson._(json as Map<String, dynamic>);

  @override
  JsonSchemaMetadata get schemaMetadata => const JsonSchemaMetadata(
    name: 'GeneratedPerson',
    definition: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'age': {'type': 'integer'},
      },
      'required': ['name', 'age'],
    },
  );
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

/// A hand-rolled type whose `toJson()` returns a nested non-JSON value.
class _Container {
  final _Widget widget;

  _Container(this.widget);

  Map<String, Object?> toJson() => {'widget': widget};
}

/// A hand-rolled type whose `toJson()` returns a nested non-serializable value.
class _OpaqueContainer {
  Map<String, Object?> toJson() => {'value': _Opaque()};
}

class _Opaque {}
