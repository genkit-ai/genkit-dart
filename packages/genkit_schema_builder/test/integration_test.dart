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

      expect(jsonDecode(jsonEncode(GroupType.jsonSchema)), {
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
  });
}
