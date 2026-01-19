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

import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';
import 'schemas/shared_test_schema.dart';

part 'integration_test.schema.g.dart';

@Schematic()
abstract class UserSchema {
  String get name;
  int? get age;
  bool get isAdmin;
}

@Schematic()
abstract class GroupSchema {
  String get groupName;
  List<UserSchema> get members;
  UserSchema? get leader;
}

@Schematic()
abstract class NodeSchema {
  String get id;
  List<NodeSchema>? get children;
}

@Schematic()
abstract class KeyedSchema {
  @StringField(
    name: 'custom_name',
    description: 'A custom named field',
    minLength: 3,
  )
  String get originalName;

  @IntegerField(minimum: 10, maximum: 100)
  int? get score;

  @NumberField(minimum: 0.5, maximum: 5.5)
  double? get rating;
}

@Schematic()
abstract class ComprehensiveSchema {
  @StringField(
    name: 's_field',
    description: 'A string field',
    minLength: 1,
    maxLength: 10,
    pattern: '^[a-z]+\$',
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

  @NumberField(
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
abstract class DescriptionSchema {
  String get name;
}

@Schematic()
abstract class CrossFileParentSchema {
  SharedChildSchema get child;
}

void main() {
  group('Integration Tests', () {
    test('User serialization and deserialization', () {
      final user = User.from(name: 'Alice', age: 30, isAdmin: true);

      expect(user.name, 'Alice');
      expect(user.age, 30);
      expect(user.isAdmin, isTrue);

      final json = user.toJson();
      expect(json, {'name': 'Alice', 'age': 30, 'isAdmin': true});

      final parsed = UserType.parse(json);
      expect(parsed.name, 'Alice');
      expect(parsed.age, 30);
      expect(parsed.isAdmin, isTrue);
    });

    test('User with null optional field', () {
      final user = User.from(name: 'Bob', isAdmin: false);

      expect(user.name, 'Bob');
      expect(user.age, isNull);
      expect(user.isAdmin, isFalse);

      final json = user.toJson();
      expect(json, {'name': 'Bob', 'isAdmin': false});
      expect(json.containsKey('age'), isFalse);

      final parsed = UserType.parse(json);
      expect(parsed.name, 'Bob');
      expect(parsed.age, isNull);
    });

    test('Group serialization with nested objects', () {
      final u1 = User.from(name: 'A', isAdmin: false);
      final u2 = User.from(name: 'B', isAdmin: true);
      final group = Group.from(
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
      final parsed = GroupType.parse(json);
      expect(parsed.groupName, 'Engineering');
      expect(parsed.members.first.name, 'A');
      expect(parsed.leader?.isAdmin, isTrue);

      final schema = GroupType.jsonSchema(useRefs: false);
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
      final nodeSchema = NodeType.jsonSchema(useRefs: true);
      final json = jsonDecode(jsonEncode(nodeSchema));

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
      expect(() => NodeType.jsonSchema(useRefs: false), throwsStateError);
    });

    test('Schema Validation', () async {
      final schema = UserType.jsonSchema();
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
      final schema = UserType.jsonSchema(useRefs: true);
      // Valid data
      expect(
        await schema.validate({'name': 'Alice', 'age': 30, 'isAdmin': true}),
        isEmpty,
      );
      // Invalid data
      expect(await schema.validate({'name': 'Charlie'}), isNotEmpty);

      // Recursive schema valid data
      final nodeSchema = NodeType.jsonSchema(useRefs: true);
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
      final keyed = Keyed.from(originalName: 'test');
      final json = keyed.toJson();
      expect(json, {'custom_name': 'test'});

      final parsed = KeyedType.parse({'custom_name': 'parsed'});
      expect(parsed.originalName, 'parsed');

      final schema = KeyedType.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());
      expect(
        schemaJson['properties']['custom_name']['description'],
        'A custom named field',
      );
    });

    test('ComprehensiveSchema validation', () {
      final schema = ComprehensiveType.jsonSchema();
      final schemaJson = jsonDecode(schema.toJson());
      final props = schemaJson['properties'] as Map<String, dynamic>;

      // StringField validation
      final s = props['s_field'];
      expect(s['type'], 'string');
      expect(s['description'], 'A string field');
      expect(s['minLength'], 1);
      expect(s['maxLength'], 10);
      expect(s['pattern'], '^[a-z]+\$');
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

      // NumberField validation
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
      final schemaMetadata = DescriptionType.schemaMetadata;
      final definition = schemaMetadata.definition as Map<String, dynamic>;

      // We expect the definition to have the description directly (if it's an object)
      // The implementation uses Schema.object(description: ...) which produces
      // { "type": "object", "description": "...", ... }
      expect(definition['description'], 'A schema with description');
    });

    test('Cross-file schema reference', () {
      final child = SharedChild.from(childId: 'c1');
      final parent = CrossFileParent.from(child: child);

      expect(parent.child.childId, 'c1');
      final json = parent.toJson();
      expect(json, {
        'child': {'childId': 'c1'},
      });

      final parsed = CrossFileParentType.parse(json);
      expect(parsed.child.childId, 'c1');
    });
  });
}
