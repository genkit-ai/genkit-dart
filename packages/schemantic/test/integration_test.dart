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

// ignore_for_file: avoid_dynamic_calls, unused_element

import 'dart:convert';

import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';
import 'schemas/shared_test_schema.dart';

part 'integration_test.g.dart';

@Schematic()
abstract class $User {
  String get name;
  int? get age;
  bool get isAdmin;
}

@Schematic()
abstract class $Group {
  String get groupName;
  List<$User> get members;
  $User? get leader;
}

@Schematic()
abstract class $Node {
  String get id;
  List<$Node>? get children;
}

@Schematic()
abstract class $Keyed {
  @StringField(
    name: 'custom_name',
    description: 'A custom named field',
    minLength: 3,
  )
  String get originalName;

  @IntegerField(minimum: 10, maximum: 100)
  int? get score;

  @DoubleField(minimum: 0.5, maximum: 5.5)
  double? get rating;
}

@Schematic()
abstract class $Comprehensive {
  @StringField(
    name: 's_field',
    description: 'A string field',
    minLength: 1,
    maxLength: 10,
    pattern: r'^[a-z]+$',
    format: 'email',
    enumValues: ['a', 'b'],
  )
  String get stringField;

  @IntegerField(
    name: 'i_field',
    description: 'An integer field',
    minimum: 0,
    maximum: 100,
    exclusiveMinimum: 0,
    exclusiveMaximum: 100,
    multipleOf: 5,
  )
  int get intField;

  @DoubleField(
    name: 'n_field',
    description: 'A number field',
    minimum: 0.0,
    maximum: 100.0,
    exclusiveMinimum: 0.0,
    exclusiveMaximum: 100.0,
    multipleOf: 0.5,
  )
  double get numberField;
}

@Schematic(description: 'A schema with description')
abstract class $Description {
  String get name;
}

@Schematic()
abstract class $CrossFileParent {
  $SharedChild get child;
}

@Schematic()
abstract class $Defaults {
  @StringField(defaultValue: 'prod')
  String get env;

  @IntegerField(defaultValue: 8080)
  int get port;

  @DoubleField(defaultValue: 1.5)
  double get ratio;

  @Field(defaultValue: true)
  bool get flag;
}

@Schematic()
abstract class $Poly {
  @AnyOf([int, String, $User])
  Object? get id;
}

@Schematic()
abstract class $MapSchema {
  Map<String, int> get stringToInt;
  Map<String, $User>? get stringToUser;
}

void main() {
  group('Integration Tests', () {
    test('User serialization and deserialization', () {
      final user = User(name: 'Alice', age: 30, isAdmin: true);

      expect(user.name, 'Alice');
      expect(user.age, 30);
      expect(user.isAdmin, isTrue);

      final json = user.toJson();
      expect(json, {'name': 'Alice', 'age': 30, 'isAdmin': true});

      final parsed = User.$schema.parse(json);
      expect(parsed.name, 'Alice');
      expect(parsed.age, 30);
      expect(parsed.isAdmin, isTrue);
    });

    test('User with null optional field', () {
      final user = User(name: 'Bob', isAdmin: false);

      expect(user.name, 'Bob');
      expect(user.age, isNull);
      expect(user.isAdmin, isFalse);

      final json = user.toJson();
      expect(json, {'name': 'Bob', 'isAdmin': false});
      expect(json.containsKey('age'), isFalse);

      final parsed = User.$schema.parse(json);
      expect(parsed.name, 'Bob');
      expect(parsed.age, isNull);
    });

    test('Group serialization with nested objects', () {
      final u1 = User(name: 'A', isAdmin: false);
      final u2 = User(name: 'B', isAdmin: true);
      final group = Group(
        groupName: 'Engineering',
        members: [u1, u2],
        leader: u2,
      );

      expect(group.groupName, 'Engineering');
      expect(group.members.length, 2);
      expect(group.members[0].name, 'A');
      expect(group.leader?.name, 'B');

      final json = group.toJson();
      expect(json['groupName'], 'Engineering');
      expect(json['members'], isA<List>());
      expect((json['members'] as List).length, 2);
      expect(json['leader'], isA<Map>());
      final parsed = Group.$schema.parse(json);
      expect(parsed.groupName, 'Engineering');
      expect(parsed.members.first.name, 'A');
      expect(parsed.leader?.isAdmin, isTrue);

      final schema = Group.$schema.jsonSchema(useRefs: false);
      expect(jsonDecode(jsonEncode(schema)), {
        'type': 'object',
        'properties': {
          'groupName': {'type': 'string'},
          'members': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'age': {'type': 'integer'},
                'isAdmin': {'type': 'boolean'},
              },
              'required': ['name', 'isAdmin'],
            },
          },
          'leader': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'age': {'type': 'integer'},
              'isAdmin': {'type': 'boolean'},
            },
            'required': ['name', 'isAdmin'],
          },
        },
        'required': ['groupName', 'members'],
      });
    });

    test('Recursive Schema Generation', () {
      // 1. Verify refs generation
      // 1. Verify refs generation
      final nodeSchema = Node.$schema.jsonSchema(useRefs: true);
      final json = jsonDecode(jsonEncode(nodeSchema)) as Map<String, dynamic>;

      // Should have a root ref or be a combinator dependent on implementation
      expect(json[r'$ref'], '#/\$defs/Node');

      final defs = json[r'$defs'] ?? json['definitions'];
      expect(defs, isNotNull);
      expect(defs, contains('Node'));

      final nodeDef = defs['Node'];
      // Check children item ref
      expect(
        nodeDef['properties']['children']['items'][r'$ref'],
        '#/\$defs/Node',
      );

      // 2. Verify inline generation throws for recursive schema
      expect(() => Node.$schema.jsonSchema(useRefs: false), throwsStateError);
    });

    test('Schema Validation', () async {
      final schema = User.$schema.jsonSchema();
      // Valid data
      expect(
        await schema.validate({'name': 'Alice', 'age': 30, 'isAdmin': true}),
        isEmpty,
      );
      // Valid data (optional field missing)
      expect(await schema.validate({'name': 'Bob', 'isAdmin': false}), isEmpty);

      // Invalid data: missing required field 'isAdmin'
      expect(await schema.validate({'name': 'Charlie'}), isNotEmpty);

      // Invalid data: wrong type for 'age'
      expect(
        await schema.validate({
          'name': 'Dave',
          'age': 'not an int',
          'isAdmin': true,
        }),
        isNotEmpty,
      );
    });

    test('Schema Validation with useRefs: true', () async {
      final schema = User.$schema.jsonSchema(useRefs: true);
      // Valid data
      expect(
        await schema.validate({'name': 'Alice', 'age': 30, 'isAdmin': true}),
        isEmpty,
      );
      // Invalid data
      expect(await schema.validate({'name': 'Charlie'}), isNotEmpty);

      // Recursive schema valid data
      final nodeSchema = Node.$schema.jsonSchema(useRefs: true);
      expect(
        await nodeSchema.validate({'id': 'root', 'children': []}),
        isEmpty,
      );
      expect(
        await nodeSchema.validate({
          'id': 'root',
          'children': [
            {'id': 'child1', 'children': []},
          ],
        }),
        isEmpty,
      );

      // Recursive invalid (wrong type for child id)
      expect(
        await nodeSchema.validate({
          'id': 'root',
          'children': [
            {'id': 123, 'children': []},
          ],
        }),
        isNotEmpty,
      );
    });
    test('KeyedSchema serialization and deserialization', () {
      final keyed = Keyed(originalName: 'test');
      final json = keyed.toJson();
      expect(json, {'custom_name': 'test'});

      final parsed = Keyed.$schema.parse({'custom_name': 'parsed'});
      expect(parsed.originalName, 'parsed');

      final schema = Keyed.$schema.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());
      expect(
        schemaJson['properties']['custom_name']['description'],
        'A custom named field',
      );
    });

    test('ComprehensiveSchema validation', () {
      final schema = Comprehensive.$schema.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());
      final props = schemaJson['properties'] as Map<String, dynamic>;

      // StringField validation
      final s = props['s_field'];
      expect(s['type'], 'string');
      expect(s['description'], 'A string field');
      expect(s['minLength'], 1);
      expect(s['maxLength'], 10);
      expect(s['pattern'], r'^[a-z]+$');
      expect(s['format'], 'email');
      expect(s['enum'], ['a', 'b']);

      // IntegerField validation
      final i = props['i_field'];
      expect(i['type'], 'integer');
      expect(i['description'], 'An integer field');
      expect(i['minimum'], 0);
      expect(i['maximum'], 100);
      expect(i['exclusiveMinimum'], 0);
      expect(i['exclusiveMaximum'], 100);
      expect(i['multipleOf'], 5);

      // DoubleField validation
      final n = props['n_field'];
      expect(n['type'], 'number');
      expect(n['description'], 'A number field');
      expect(n['minimum'], 0.0);
      expect(n['maximum'], 100.0);
      expect(n['exclusiveMinimum'], 0.0);
      expect(n['exclusiveMaximum'], 100.0);
      expect(n['multipleOf'], 0.5);
    });

    test('DescriptionSchema has description', () {
      final schemaMetadata = Description.$schema.schemaMetadata;
      final definition = schemaMetadata!.definition as Map<String, dynamic>;

      // We expect the definition to have the description directly (if it's an object)
      // The implementation uses Schema.object(description: ...) which produces
      // { "type": "object", "description": "...", ... }
      expect(definition['description'], 'A schema with description');
    });

    test('Cross-file schema reference', () {
      final child = SharedChild(childId: 'c1');
      final parent = CrossFileParent(child: child);

      expect(parent.child.childId, 'c1');
      final json = parent.toJson();
      expect(json, {
        'child': {'childId': 'c1'},
      });

      final parsed = CrossFileParent.$schema.parse(json);
      expect(parsed.child.childId, 'c1');
    });

    test('DefaultsSchema has default values', () {
      final schema = Defaults.$schema.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());
      final props = schemaJson['properties'] as Map<String, dynamic>;

      expect(props['env']['default'], 'prod');
      expect(props['port']['default'], 8080);
      expect(props['ratio']['default'], 1.5);
      expect(props['flag']['default'], true);
    });
  });

  group('Coercion Tests', () {
    test('Double field accepts int value', () {
      final json = {
        's_field': 'a',
        'i_field': 10,
        'n_field': 20, // int value for double field
      };

      final parsed = Comprehensive.$schema.parse(json);
      expect(parsed.numberField, 20.0);
    });
  });

  group('AnyOf Tests', () {
    test('Poly serialization and deserialization', () {
      final p1 = Poly(id: PolyId.int(123));
      expect(p1.id, 123);
      expect(p1.toJson(), {'id': 123});

      final p2 = Poly(id: PolyId.string('abc'));
      expect(p2.id, 'abc');
      expect(p2.toJson(), {'id': 'abc'});

      final parsed1 = Poly.$schema.parse({'id': 123});
      expect(
        parsed1.id,
        isA<int>(),
      ); // Getter returns Object? which is the raw value for now?
      // Wait, let's check generated getter.
      // Getter returns Object? and body is `return _json['id'] as Object?;`
      // So yes, it returns the raw value.
      expect(parsed1.id, 123);

      final parsed2 = Poly.$schema.parse({'id': 'abc'});
      expect(parsed2.id, 'abc');
    });

    test('Poly JSON Schema', () {
      final schema = Poly.$schema.jsonSchema(useRefs: true);
      final json = jsonDecode(schema.toJson());
      final defs = json[r'$defs'] ?? json['definitions'];
      final polyDef = defs['Poly'];
      final props = polyDef['properties'];
      expect(props['id']['anyOf'], [
        {'type': 'integer'},
        {'type': 'string'},
        {r'$ref': r'#/$defs/User'},
      ]);
    });

    test('Poly with Schema type', () {
      final user = User(name: 'UserInPoly', isAdmin: true);
      final p3 = Poly(id: PolyId.user(user));

      // Check it was serialized properly in _json (since we mocked toJson behavior in generator)
      // Actually we need to check if it's stored as Map
      final json = p3.toJson();
      expect(json['id'], isA<Map>());
      expect(json['id']['name'], 'UserInPoly');

      // Check parse
      final parsed = Poly.$schema.parse(json);
      // Because AnyOf getter returns Object?, it will return the Map<String, dynamic> here
      // unless we improve getter to try to match?
      // For now, raw map is expected behavior for AnyOf getter if it's an object.
      expect(parsed.id, isA<Map>());
      expect((parsed.id as Map)['name'], 'UserInPoly');
    });
  });

  group('Map Tests', () {
    test('Map with primitive values', () {
      final m = MapSchema(stringToInt: {'a': 1, 'b': 2});
      final json = m.toJson();
      expect(json, {
        'stringToInt': {'a': 1, 'b': 2},
      });
      final parsed = MapSchema.$schema.parse(json);
      expect(parsed.stringToInt, {'a': 1, 'b': 2});
      expect(parsed.stringToInt, isA<Map<String, int>>());
    });

    test('Map with object values', () {
      final m = MapSchema(
        stringToInt: {},
        stringToUser: <String, User>{
          'admin': User(name: 'Admin', isAdmin: true),
          'guest': User(name: 'Guest', isAdmin: false),
        },
      );
      final json = m.toJson();
      final parsed = MapSchema.$schema.parse(json);

      expect(parsed.stringToUser, isNotNull);
      expect(parsed.stringToUser!['admin']!.isAdmin, true);
      expect(parsed.stringToUser!['guest']!.name, 'Guest');
      expect(parsed.stringToUser, isA<Map<String, User>>());
    });
  });
}
