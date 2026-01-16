// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'integration_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
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

class _UserTypeFactory extends JsonExtensionType<User> {
  const _UserTypeFactory();

  @override
  User parse(Object? json) {
    return User(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const UserType = _UserTypeFactory();

extension type Group(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Group.from({
    required String groupName,
    required List<User> members,
    User? leader,
  }) {
    return Group({
      'groupName': groupName,
      'members': members.map((e) => e.toJson()).toList(),
      if (leader != null) 'leader': leader.toJson(),
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

class _GroupTypeFactory extends JsonExtensionType<Group> {
  const _GroupTypeFactory();

  @override
  Group parse(Object? json) {
    return Group(json as Map<String, dynamic>);
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
    dependencies: [UserType],
  );
}

// ignore: constant_identifier_names
const GroupType = _GroupTypeFactory();

extension type Node(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Node.from({required String id, List<Node>? children}) {
    return Node({
      'id': id,
      if (children != null)
        'children': children.map((e) => e.toJson()).toList(),
    });
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  List<Node>? get children {
    return (_json['children'] as List?)
        ?.map((e) => Node(e as Map<String, dynamic>))
        .toList();
  }

  set children(List<Node>? value) {
    if (value == null) {
      _json.remove('children');
    } else {
      _json['children'] = value.toList();
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _NodeTypeFactory extends JsonExtensionType<Node> {
  const _NodeTypeFactory();

  @override
  Node parse(Object? json) {
    return Node(json as Map<String, dynamic>);
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
    dependencies: [NodeType],
  );
}

// ignore: constant_identifier_names
const NodeType = _NodeTypeFactory();

extension type Keyed(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Keyed.from({
    required String originalName,
    int? score,
    double? rating,
  }) {
    return Keyed({
      'custom_name': originalName,
      if (score != null) 'score': score,
      if (rating != null) 'rating': rating,
    });
  }

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
    return _json['rating'] as double?;
  }

  set rating(double? value) {
    if (value == null) {
      _json.remove('rating');
    } else {
      _json['rating'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _KeyedTypeFactory extends JsonExtensionType<Keyed> {
  const _KeyedTypeFactory();

  @override
  Keyed parse(Object? json) {
    return Keyed(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const KeyedType = _KeyedTypeFactory();

extension type Comprehensive(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Comprehensive.from({
    required String stringField,
    required int intField,
    required double numberField,
  }) {
    return Comprehensive({
      's_field': stringField,
      'i_field': intField,
      'n_field': numberField,
    });
  }

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
    return _json['n_field'] as double;
  }

  set numberField(double value) {
    _json['n_field'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ComprehensiveTypeFactory extends JsonExtensionType<Comprehensive> {
  const _ComprehensiveTypeFactory();

  @override
  Comprehensive parse(Object? json) {
    return Comprehensive(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const ComprehensiveType = _ComprehensiveTypeFactory();

extension type Description(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Description.from({required String name}) {
    return Description({'name': name});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _DescriptionTypeFactory extends JsonExtensionType<Description> {
  const _DescriptionTypeFactory();

  @override
  Description parse(Object? json) {
    return Description(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const DescriptionType = _DescriptionTypeFactory();
