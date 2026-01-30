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
//
// GENERATED CODE BY schemantic - DO NOT MODIFY BY HAND
// To regenerate, run `dart run build_runner build -d`

part of 'integration_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class User {
  factory User.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  User._(this._json);

  factory User({required String name, int? age, required bool isAdmin}) {
    return User._({
      'name': name,
      if (age != null) 'age': age,
      'isAdmin': isAdmin,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<User> $schema = _UserTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _UserTypeFactory extends SchemanticType<User> {
  const _UserTypeFactory();

  @override
  User parse(Object? json) {
    return User._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'User',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'age': Schema.integer(),
        'isAdmin': Schema.boolean(),
      },
      required: ['name', 'isAdmin'],
    ),
    dependencies: [],
  );
}

class Group {
  factory Group.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Group._(this._json);

  factory Group({
    required String groupName,
    required List<User> members,
    User? leader,
  }) {
    return Group._({
      'groupName': groupName,
      'members': members.map((e) => e.toJson()).toList(),
      if (leader != null) 'leader': leader.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Group> $schema = _GroupTypeFactory();

  String get groupName {
    return _json['groupName'] as String;
  }

  set groupName(String value) {
    _json['groupName'] = value;
  }

  List<User> get members {
    return (_json['members'] as List)
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set members(List<User> value) {
    _json['members'] = value.toList();
  }

  User? get leader {
    return _json['leader'] == null
        ? null
        : User.fromJson(_json['leader'] as Map<String, dynamic>);
  }

  set leader(User? value) {
    if (value == null) {
      _json.remove('leader');
    } else {
      _json['leader'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _GroupTypeFactory extends SchemanticType<Group> {
  const _GroupTypeFactory();

  @override
  Group parse(Object? json) {
    return Group._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Group',
    definition: Schema.object(
      properties: {
        'groupName': Schema.string(),
        'members': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/User'}),
        ),
        'leader': Schema.fromMap({'\$ref': r'#/$defs/User'}),
      },
      required: ['groupName', 'members'],
    ),
    dependencies: [User.$schema],
  );
}

class Node {
  factory Node.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Node._(this._json);

  factory Node({required String id, List<Node>? children}) {
    return Node._({
      'id': id,
      if (children != null)
        'children': children.map((e) => e.toJson()).toList(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Node> $schema = _NodeTypeFactory();

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  List<Node>? get children {
    return (_json['children'] as List?)
        ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set children(List<Node>? value) {
    if (value == null) {
      _json.remove('children');
    } else {
      _json['children'] = value.toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _NodeTypeFactory extends SchemanticType<Node> {
  const _NodeTypeFactory();

  @override
  Node parse(Object? json) {
    return Node._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Node',
    definition: Schema.object(
      properties: {
        'id': Schema.string(),
        'children': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Node'}),
        ),
      },
      required: ['id'],
    ),
    dependencies: [Node.$schema],
  );
}

class Keyed {
  factory Keyed.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Keyed._(this._json);

  factory Keyed({required String originalName, int? score, double? rating}) {
    return Keyed._({
      'custom_name': originalName,
      if (score != null) 'score': score,
      if (rating != null) 'rating': rating,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Keyed> $schema = _KeyedTypeFactory();

  String get originalName {
    return _json['custom_name'] as String;
  }

  set originalName(String value) {
    _json['custom_name'] = value;
  }

  int? get score {
    return _json['score'] as int?;
  }

  set score(int? value) {
    if (value == null) {
      _json.remove('score');
    } else {
      _json['score'] = value;
    }
  }

  double? get rating {
    return (_json['rating'] as num?)?.toDouble();
  }

  set rating(double? value) {
    if (value == null) {
      _json.remove('rating');
    } else {
      _json['rating'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _KeyedTypeFactory extends SchemanticType<Keyed> {
  const _KeyedTypeFactory();

  @override
  Keyed parse(Object? json) {
    return Keyed._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Keyed',
    definition: Schema.object(
      properties: {
        'custom_name': Schema.string(
          description: 'A custom named field',
          minLength: 3,
        ),
        'score': Schema.integer(minimum: 10, maximum: 100),
        'rating': Schema.number(minimum: 0.5, maximum: 5.5),
      },
      required: ['custom_name'],
    ),
    dependencies: [],
  );
}

class Comprehensive {
  factory Comprehensive.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  Comprehensive._(this._json);

  factory Comprehensive({
    required String stringField,
    required int intField,
    required double numberField,
  }) {
    return Comprehensive._({
      's_field': stringField,
      'i_field': intField,
      'n_field': numberField,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Comprehensive> $schema =
      _ComprehensiveTypeFactory();

  String get stringField {
    return _json['s_field'] as String;
  }

  set stringField(String value) {
    _json['s_field'] = value;
  }

  int get intField {
    return _json['i_field'] as int;
  }

  set intField(int value) {
    _json['i_field'] = value;
  }

  double get numberField {
    return (_json['n_field'] as num).toDouble();
  }

  set numberField(double value) {
    _json['n_field'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ComprehensiveTypeFactory extends SchemanticType<Comprehensive> {
  const _ComprehensiveTypeFactory();

  @override
  Comprehensive parse(Object? json) {
    return Comprehensive._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Comprehensive',
    definition: Schema.object(
      properties: {
        's_field': Schema.string(
          description: 'A string field',
          minLength: 1,
          maxLength: 10,
          pattern: r'^[a-z]+$',
          format: 'email',
          enumValues: ['a', 'b'],
        ),
        'i_field': Schema.integer(
          description: 'An integer field',
          minimum: 0,
          maximum: 100,
          exclusiveMinimum: 0,
          exclusiveMaximum: 100,
          multipleOf: 5,
        ),
        'n_field': Schema.number(
          description: 'A number field',
          minimum: 0.0,
          maximum: 100.0,
          exclusiveMinimum: 0.0,
          exclusiveMaximum: 100.0,
          multipleOf: 0.5,
        ),
      },
      required: ['s_field', 'i_field', 'n_field'],
    ),
    dependencies: [],
  );
}

class Description {
  factory Description.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  Description._(this._json);

  factory Description({required String name}) {
    return Description._({'name': name});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Description> $schema = _DescriptionTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DescriptionTypeFactory extends SchemanticType<Description> {
  const _DescriptionTypeFactory();

  @override
  Description parse(Object? json) {
    return Description._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Description',
    definition: Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
      description: 'A schema with description',
    ),
    dependencies: [],
  );
}

class CrossFileParent {
  factory CrossFileParent.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CrossFileParent._(this._json);

  factory CrossFileParent({required SharedChild child}) {
    return CrossFileParent._({'child': child.toJson()});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<CrossFileParent> $schema =
      _CrossFileParentTypeFactory();

  SharedChild get child {
    return SharedChild.fromJson(_json['child'] as Map<String, dynamic>);
  }

  set child(SharedChild value) {
    _json['child'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _CrossFileParentTypeFactory extends SchemanticType<CrossFileParent> {
  const _CrossFileParentTypeFactory();

  @override
  CrossFileParent parse(Object? json) {
    return CrossFileParent._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CrossFileParent',
    definition: Schema.object(
      properties: {
        'child': Schema.fromMap({'\$ref': r'#/$defs/SharedChild'}),
      },
      required: ['child'],
    ),
    dependencies: [SharedChild.$schema],
  );
}

class Defaults {
  factory Defaults.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Defaults._(this._json);

  factory Defaults({
    required String env,
    required int port,
    required double ratio,
    required bool flag,
  }) {
    return Defaults._({'env': env, 'port': port, 'ratio': ratio, 'flag': flag});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Defaults> $schema = _DefaultsTypeFactory();

  String get env {
    return _json['env'] as String;
  }

  set env(String value) {
    _json['env'] = value;
  }

  int get port {
    return _json['port'] as int;
  }

  set port(int value) {
    _json['port'] = value;
  }

  double get ratio {
    return (_json['ratio'] as num).toDouble();
  }

  set ratio(double value) {
    _json['ratio'] = value;
  }

  bool get flag {
    return _json['flag'] as bool;
  }

  set flag(bool value) {
    _json['flag'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DefaultsTypeFactory extends SchemanticType<Defaults> {
  const _DefaultsTypeFactory();

  @override
  Defaults parse(Object? json) {
    return Defaults._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Defaults',
    definition: Schema.object(
      properties: {
        'env': Schema.fromMap({'default': 'prod', 'type': 'string'}),
        'port': Schema.fromMap({'default': 8080, 'type': 'integer'}),
        'ratio': Schema.fromMap({'default': 1.5, 'type': 'number'}),
        'flag': Schema.fromMap({'default': true, 'type': 'boolean'}),
      },
      required: ['env', 'port', 'ratio', 'flag'],
    ),
    dependencies: [],
  );
}

class Poly {
  factory Poly.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Poly._(this._json);

  factory Poly({required PolyId id}) {
    return Poly._({'id': id.value});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Poly> $schema = _PolyTypeFactory();

  set id(PolyId value) {
    _json['id'] = value.value;
  }

  // Possible return values are `int`, `String`, `$User`
  Object? get id {
    return _json['id'] as Object?;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class PolyId {
  PolyId.int(int this.value);

  PolyId.string(String this.value);

  PolyId.user(User value) : value = value.toJson();

  final Object? value;
}

class _PolyTypeFactory extends SchemanticType<Poly> {
  const _PolyTypeFactory();

  @override
  Poly parse(Object? json) {
    return Poly._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Poly',
    definition: Schema.object(
      properties: {
        'id': Schema.combined(
          anyOf: [
            Schema.integer(),
            Schema.string(),
            Schema.fromMap({'\$ref': r'#/$defs/User'}),
          ],
        ),
      },
      required: [],
    ),
    dependencies: [User.$schema],
  );
}
