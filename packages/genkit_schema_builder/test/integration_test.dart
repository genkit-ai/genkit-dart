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
import 'package:test/test.dart';
import 'package:genkit_schema_builder/genkit_schema_builder.dart';

part 'integration_test.schema.g.dart';

@GenkitSchema()
abstract class UserSchema {
  String get name;
  int? get age;
  bool get isAdmin;
}

@GenkitSchema()
abstract class GroupSchema {
  String get groupName;
  List<UserSchema> get members;
  UserSchema? get leader;
}

@GenkitSchema()
abstract class NodeSchema {
  String get id;
  List<NodeSchema>? get children;
}

void main() {
  group('Integration Tests', () {
    test('User serialization and deserialization', () {
      final user = User.from(name: 'Alice', age: 30, isAdmin: true);

      expect(user.name, 'Alice');
      expect(user.age, 30);
      expect(user.isAdmin, isTrue);

      final json = user.toJson();
      expect(json, {
        'name': 'Alice',
        'age': 30,
        'isAdmin': true,
      });

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
      expect(json, {
        'name': 'Bob',
        'isAdmin': false,
      });
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
                'isAdmin': {'type': 'boolean'}
              },
              'required': ['name', 'isAdmin']
            }
          },
          'leader': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'age': {'type': 'integer'},
              'isAdmin': {'type': 'boolean'}
            },
            'required': ['name', 'isAdmin']
          }
        },
        'required': ['groupName', 'members']
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
          nodeDef['properties']['children']['items'][r'$ref'], '#/\$defs/Node');

      // 2. Verify inline generation throws for recursive schema
      expect(() => NodeType.jsonSchema(useRefs: false), throwsStateError);
    });

    test('Schema Validation', () async {
      final schema = UserType.jsonSchema();
      // Valid data
      expect(
          await schema.validate({'name': 'Alice', 'age': 30, 'isAdmin': true}),
          isEmpty);
      // Valid data (optional field missing)
      expect(await schema.validate({'name': 'Bob', 'isAdmin': false}), isEmpty);

      // Invalid data: missing required field 'isAdmin'
      expect(await schema.validate({'name': 'Charlie'}), isNotEmpty);

      // Invalid data: wrong type for 'age'
      expect(
          await schema
              .validate({'name': 'Dave', 'age': 'not an int', 'isAdmin': true}),
          isNotEmpty);
    });

    test('Schema Validation with useRefs: true', () async {
      final schema = UserType.jsonSchema(useRefs: true);
      // Valid data
      expect(
          await schema.validate({'name': 'Alice', 'age': 30, 'isAdmin': true}),
          isEmpty);
      // Invalid data
      expect(await schema.validate({'name': 'Charlie'}), isNotEmpty);

      // Recursive schema valid data
      final nodeSchema = NodeType.jsonSchema(useRefs: true);
      expect(
          await nodeSchema.validate({'id': 'root', 'children': []}), isEmpty);
      expect(
          await nodeSchema.validate({
            'id': 'root',
            'children': [
              {'id': 'child1', 'children': []}
            ]
          }),
          isEmpty);

      // Recursive invalid (wrong type for child id)
      expect(
          await nodeSchema.validate({
            'id': 'root',
            'children': [
              {'id': 123, 'children': []}
            ]
          }),
          isNotEmpty);
    });
  });
}
