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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'integration_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type User(Map<String, dynamic> _json) {
  factory User.from({required String name, int? age, required bool isAdmin}) {
    return User({
      'name': name,
      if (age != null) 'age': age,
      'isAdmin': isAdmin,
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  int? get age {
    return _json['age'] as int?;
  }

  set age(int? value) {
    if (value == null) {
      _json.remove('age');
    } else {
      _json['age'] = value;
    }
  }

  bool get isAdmin {
    return _json['isAdmin'] as bool;
  }

  set isAdmin(bool value) {
    _json['isAdmin'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class UserTypeFactory implements JsonExtensionType<User> {
  const UserTypeFactory();

  @override
  User parse(Object json) {
    return User(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'name': Schema.string(),
        'age': Schema.integer(),
        'isAdmin': Schema.boolean(),
      },
      required: ['name', 'isAdmin'],
    );
  }
}

// ignore: constant_identifier_names
const UserType = UserTypeFactory();

extension type Group(Map<String, dynamic> _json) {
  factory Group.from({
    required String groupName,
    required List<User> members,
    User? leader,
  }) {
    return Group({
      'groupName': groupName,
      'members': members.map((e) => e.toJson()).toList(),
      if (leader != null) 'leader': leader?.toJson(),
    });
  }

  String get groupName {
    return _json['groupName'] as String;
  }

  set groupName(String value) {
    _json['groupName'] = value;
  }

  List<User> get members {
    return (_json['members'] as List)
        .map((e) => User(e as Map<String, dynamic>))
        .toList();
  }

  set members(List<User> value) {
    _json['members'] = value.toList();
  }

  User? get leader {
    return _json['leader'] == null
        ? null
        : User(_json['leader'] as Map<String, dynamic>);
  }

  set leader(User? value) {
    if (value == null) {
      _json.remove('leader');
    } else {
      _json['leader'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GroupTypeFactory implements JsonExtensionType<Group> {
  const GroupTypeFactory();

  @override
  Group parse(Object json) {
    return Group(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'groupName': Schema.string(),
        'members': Schema.list(items: UserType.jsonSchema),
        'leader': UserType.jsonSchema,
      },
      required: ['groupName', 'members'],
    );
  }
}

// ignore: constant_identifier_names
const GroupType = GroupTypeFactory();
