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

base class User {
  factory User.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  User._(this._json);

  User({required String name, int? age, required bool isAdmin}) {
    _json = {'name': name, 'age': ?age, 'isAdmin': isAdmin};
  }

  late final Map<String, dynamic> _json;

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

base class _UserTypeFactory extends SchemanticType<User> {
  const _UserTypeFactory();

  @override
  User parse(Object? json) {
    return User._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'User',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'age': $Schema.integer(),
            'isAdmin': $Schema.boolean(),
          },
          required: ['name', 'isAdmin'],
        )
        .value,
    dependencies: [],
  );
}

base class Group {
  factory Group.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Group._(this._json);

  Group({
    required String groupName,
    required List<User> members,
    User? leader,
  }) {
    _json = {
      'groupName': groupName,
      'members': members.map((e) => e.toJson()).toList(),
      'leader': ?leader?.toJson(),
    };
  }

  late final Map<String, dynamic> _json;

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

base class _GroupTypeFactory extends SchemanticType<Group> {
  const _GroupTypeFactory();

  @override
  Group parse(Object? json) {
    return Group._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Group',
    definition: $Schema
        .object(
          properties: {
            'groupName': $Schema.string(),
            'members': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/User'}),
            ),
            'leader': $Schema.fromMap({'\$ref': r'#/$defs/User'}),
          },
          required: ['groupName', 'members'],
        )
        .value,
    dependencies: [User.$schema],
  );
}

base class Node {
  factory Node.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Node._(this._json);

  Node({required String id, List<Node>? children}) {
    _json = {'id': id, 'children': ?children?.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

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

base class _NodeTypeFactory extends SchemanticType<Node> {
  const _NodeTypeFactory();

  @override
  Node parse(Object? json) {
    return Node._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Node',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.string(),
            'children': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Node'}),
            ),
          },
          required: ['id'],
        )
        .value,
    dependencies: [Node.$schema],
  );
}

base class Keyed {
  factory Keyed.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Keyed._(this._json);

  Keyed({required String originalName, int? score, double? rating}) {
    _json = {'custom_name': originalName, 'score': ?score, 'rating': ?rating};
  }

  late final Map<String, dynamic> _json;

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

base class _KeyedTypeFactory extends SchemanticType<Keyed> {
  const _KeyedTypeFactory();

  @override
  Keyed parse(Object? json) {
    return Keyed._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Keyed',
    definition: $Schema
        .object(
          properties: {
            'custom_name': $Schema.string(
              description: 'A custom named field',
              minLength: 3,
            ),
            'score': $Schema.integer(minimum: 10, maximum: 100),
            'rating': $Schema.number(minimum: 0.5, maximum: 5.5),
          },
          required: ['custom_name'],
        )
        .value,
    dependencies: [],
  );
}

base class Comprehensive {
  factory Comprehensive.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  Comprehensive._(this._json);

  Comprehensive({
    required String stringField,
    required int intField,
    required double numberField,
  }) {
    _json = {
      's_field': stringField,
      'i_field': intField,
      'n_field': numberField,
    };
  }

  late final Map<String, dynamic> _json;

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

base class _ComprehensiveTypeFactory extends SchemanticType<Comprehensive> {
  const _ComprehensiveTypeFactory();

  @override
  Comprehensive parse(Object? json) {
    return Comprehensive._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Comprehensive',
    definition: $Schema
        .object(
          properties: {
            's_field': $Schema.string(
              description: 'A string field',
              minLength: 1,
              maxLength: 10,
              pattern: r'^[a-z]+$',
              format: 'email',
              enumValues: ['a', 'b'],
            ),
            'i_field': $Schema.integer(
              description: 'An integer field',
              minimum: 0,
              maximum: 100,
              exclusiveMinimum: 0,
              exclusiveMaximum: 100,
              multipleOf: 5,
            ),
            'n_field': $Schema.number(
              description: 'A number field',
              minimum: 0.0,
              maximum: 100.0,
              exclusiveMinimum: 0.0,
              exclusiveMaximum: 100.0,
              multipleOf: 0.5,
            ),
          },
          required: ['s_field', 'i_field', 'n_field'],
        )
        .value,
    dependencies: [],
  );
}

base class Description {
  factory Description.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  Description._(this._json);

  Description({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

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

base class _DescriptionTypeFactory extends SchemanticType<Description> {
  const _DescriptionTypeFactory();

  @override
  Description parse(Object? json) {
    return Description._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Description',
    definition: $Schema
        .object(
          properties: {'name': $Schema.string()},
          required: ['name'],
          description: 'A schema with description',
        )
        .value,
    dependencies: [],
  );
}

base class CrossFileParent {
  factory CrossFileParent.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CrossFileParent._(this._json);

  CrossFileParent({required SharedChild child}) {
    _json = {'child': child.toJson()};
  }

  late final Map<String, dynamic> _json;

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

base class _CrossFileParentTypeFactory extends SchemanticType<CrossFileParent> {
  const _CrossFileParentTypeFactory();

  @override
  CrossFileParent parse(Object? json) {
    return CrossFileParent._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CrossFileParent',
    definition: $Schema
        .object(
          properties: {
            'child': $Schema.fromMap({'\$ref': r'#/$defs/SharedChild'}),
          },
          required: ['child'],
        )
        .value,
    dependencies: [SharedChild.$schema],
  );
}

base class Defaults {
  factory Defaults.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Defaults._(this._json);

  Defaults({
    required String env,
    required int port,
    required double ratio,
    required bool flag,
  }) {
    _json = {'env': env, 'port': port, 'ratio': ratio, 'flag': flag};
  }

  late final Map<String, dynamic> _json;

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

base class _DefaultsTypeFactory extends SchemanticType<Defaults> {
  const _DefaultsTypeFactory();

  @override
  Defaults parse(Object? json) {
    return Defaults._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Defaults',
    definition: $Schema
        .object(
          properties: {
            'env': $Schema.fromMap({'default': 'prod', 'type': 'string'}),
            'port': $Schema.fromMap({'default': 8080, 'type': 'integer'}),
            'ratio': $Schema.fromMap({'default': 1.5, 'type': 'number'}),
            'flag': $Schema.fromMap({'default': true, 'type': 'boolean'}),
          },
          required: ['env', 'port', 'ratio', 'flag'],
        )
        .value,
    dependencies: [],
  );
}

base class Poly {
  factory Poly.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Poly._(this._json);

  Poly({PolyId? id}) {
    _json = {if (id != null) 'id': id.value};
  }

  late final Map<String, dynamic> _json;

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

final class PolyId {
  PolyId.int(int this.value);

  PolyId.string(String this.value);

  PolyId.user(User value) : value = value.toJson();

  final Object? value;
}

base class _PolyTypeFactory extends SchemanticType<Poly> {
  const _PolyTypeFactory();

  @override
  Poly parse(Object? json) {
    return Poly._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Poly',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.combined(
              anyOf: [
                $Schema.integer(),
                $Schema.string(),
                $Schema.fromMap({'\$ref': r'#/$defs/User'}),
              ],
            ),
          },
        )
        .value,
    dependencies: [User.$schema],
  );
}

base class MapSchema {
  factory MapSchema.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  MapSchema._(this._json);

  MapSchema({
    required Map<String, int> stringToInt,
    Map<String, User>? stringToUser,
  }) {
    _json = {
      'stringToInt': stringToInt,
      'stringToUser': ?stringToUser?.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MapSchema> $schema = _MapSchemaTypeFactory();

  Map<String, int> get stringToInt {
    return (_json['stringToInt'] as Map).cast<String, int>();
  }

  set stringToInt(Map<String, int> value) {
    _json['stringToInt'] = value;
  }

  Map<String, User>? get stringToUser {
    return (_json['stringToUser'] as Map?)?.map<String, User>(
      (k, v) => MapEntry(k as String, User.fromJson(v as Map<String, dynamic>)),
    );
  }

  set stringToUser(Map<String, User>? value) {
    if (value == null) {
      _json.remove('stringToUser');
    } else {
      _json['stringToUser'] = value;
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

base class _MapSchemaTypeFactory extends SchemanticType<MapSchema> {
  const _MapSchemaTypeFactory();

  @override
  MapSchema parse(Object? json) {
    return MapSchema._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MapSchema',
    definition: $Schema
        .object(
          properties: {
            'stringToInt': $Schema.object(
              additionalProperties: $Schema.integer(),
            ),
            'stringToUser': $Schema.object(
              additionalProperties: $Schema.fromMap({'\$ref': r'#/$defs/User'}),
            ),
          },
          required: ['stringToInt'],
        )
        .value,
    dependencies: [User.$schema],
  );
}

base class StatusContainer {
  factory StatusContainer.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  StatusContainer._(this._json);

  StatusContainer({
    required MyStatus status,
    MyStatus? optionalStatus,
    List<MyStatus>? statusList,
  }) {
    _json = {
      'status': status.value,
      'optionalStatus': ?optionalStatus?.value,
      'statusList': ?statusList,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<StatusContainer> $schema =
      _StatusContainerTypeFactory();

  MyStatus get status {
    final value = _json['status'] as String;
    return MyStatus(value);
  }

  set status(MyStatus value) {
    _json['status'] = value.value;
  }

  MyStatus? get optionalStatus {
    return _json['optionalStatus'] as MyStatus?;
  }

  set optionalStatus(MyStatus? value) {
    if (value == null) {
      _json.remove('optionalStatus');
    } else {
      _json['optionalStatus'] = value;
    }
  }

  List<MyStatus>? get statusList {
    return (_json['statusList'] as List?)?.cast<MyStatus>();
  }

  set statusList(List<MyStatus>? value) {
    if (value == null) {
      _json.remove('statusList');
    } else {
      _json['statusList'] = value;
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

base class _StatusContainerTypeFactory extends SchemanticType<StatusContainer> {
  const _StatusContainerTypeFactory();

  @override
  StatusContainer parse(Object? json) {
    return StatusContainer._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'StatusContainer',
    definition: $Schema
        .object(
          properties: {
            'status': $Schema.any(),
            'optionalStatus': $Schema.any(),
            'statusList': $Schema.list(items: $Schema.any()),
          },
          required: ['status'],
        )
        .value,
    dependencies: [],
  );
}

base class OrderStatus {
  factory OrderStatus.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  OrderStatus._(this._json);

  OrderStatus({
    required String id,
    required Color color,
    Color? nullableColor,
  }) {
    _json = {
      'id': id,
      'color': color.name,
      'nullableColor': ?nullableColor?.name,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<OrderStatus> $schema = _OrderStatusTypeFactory();

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  Color get color {
    return Color.values.byName(_json['color'] as String);
  }

  set color(Color value) {
    _json['color'] = value.name;
  }

  Color? get nullableColor {
    return _json['nullableColor'] == null
        ? null
        : Color.values.byName(_json['nullableColor'] as String);
  }

  set nullableColor(Color? value) {
    if (value == null) {
      _json.remove('nullableColor');
    } else {
      _json['nullableColor'] = value.name;
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

base class _OrderStatusTypeFactory extends SchemanticType<OrderStatus> {
  const _OrderStatusTypeFactory();

  @override
  OrderStatus parse(Object? json) {
    return OrderStatus._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'OrderStatus',
    definition: $Schema
        .object(
          properties: {
            'id': $Schema.string(),
            'color': $Schema.string(enumValues: ['red', 'green', 'blue']),
            'nullableColor': $Schema.string(
              enumValues: ['red', 'green', 'blue'],
            ),
          },
          required: ['id', 'color'],
        )
        .value,
    dependencies: [],
  );
}

base class StrictUser {
  factory StrictUser.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  StrictUser._(this._json);

  StrictUser({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<StrictUser> $schema = _StrictUserTypeFactory();

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

base class _StrictUserTypeFactory extends SchemanticType<StrictUser> {
  const _StrictUserTypeFactory();

  @override
  StrictUser parse(Object? json) {
    return StrictUser._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'StrictUser',
    definition: $Schema.fromMap({
      'type': 'object',
      'properties': {'name': $Schema.string()},
      'required': ['name'],
      'additionalProperties': false,
    }).value,
    dependencies: [],
  );
}
