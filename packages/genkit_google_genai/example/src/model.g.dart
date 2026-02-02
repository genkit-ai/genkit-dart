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

part of 'model.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class WeatherToolInput {
  factory WeatherToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolInput._(this._json);

  WeatherToolInput({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WeatherToolInput> $schema =
      _WeatherToolInputTypeFactory();

  String get location {
    return _json['location'] as String;
  }

  set location(String value) {
    _json['location'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _WeatherToolInputTypeFactory extends SchemanticType<WeatherToolInput> {
  const _WeatherToolInputTypeFactory();

  @override
  WeatherToolInput parse(Object? json) {
    return WeatherToolInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherToolInput',
    definition: Schema.object(
      properties: {
        'location': Schema.string(
          description:
              'The location (ex. city, state, country) to get the weather for',
        ),
      },
      required: ['location'],
    ),
    dependencies: [],
  );
}

class Category {
  factory Category.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Category._(this._json);

  Category({required String name, List<Category>? subcategories}) {
    _json = {
      'name': name,
      'subcategories': ?subcategories?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Category> $schema = _CategoryTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  List<Category>? get subcategories {
    return (_json['subcategories'] as List?)
        ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set subcategories(List<Category>? value) {
    if (value == null) {
      _json.remove('subcategories');
    } else {
      _json['subcategories'] = value.toList();
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

class _CategoryTypeFactory extends SchemanticType<Category> {
  const _CategoryTypeFactory();

  @override
  Category parse(Object? json) {
    return Category._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Category',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'subcategories': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Category'}),
        ),
      },
      required: ['name'],
    ),
    dependencies: [Category.$schema],
  );
}

class Weapon {
  factory Weapon.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Weapon._(this._json);

  Weapon({
    required String name,
    required double damage,
    required Category category,
  }) {
    _json = {'name': name, 'damage': damage, 'category': category.toJson()};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Weapon> $schema = _WeaponTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  double get damage {
    return (_json['damage'] as num).toDouble();
  }

  set damage(double value) {
    _json['damage'] = value;
  }

  Category get category {
    return Category.fromJson(_json['category'] as Map<String, dynamic>);
  }

  set category(Category value) {
    _json['category'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _WeaponTypeFactory extends SchemanticType<Weapon> {
  const _WeaponTypeFactory();

  @override
  Weapon parse(Object? json) {
    return Weapon._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Weapon',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'damage': Schema.number(),
        'category': Schema.fromMap({'\$ref': r'#/$defs/Category'}),
      },
      required: ['name', 'damage', 'category'],
    ),
    dependencies: [Category.$schema],
  );
}

class RpgCharacter {
  factory RpgCharacter.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RpgCharacter._(this._json);

  RpgCharacter({
    required String name,
    required String backstory,
    required List<Weapon> weapons,
    required String classType,
    String? affiliation,
  }) {
    _json = {
      'name': name,
      'backstory': backstory,
      'weapons': weapons.map((e) => e.toJson()).toList(),
      'classType': classType,
      'affiliation': ?affiliation,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<RpgCharacter> $schema =
      _RpgCharacterTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get backstory {
    return _json['backstory'] as String;
  }

  set backstory(String value) {
    _json['backstory'] = value;
  }

  List<Weapon> get weapons {
    return (_json['weapons'] as List)
        .map((e) => Weapon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set weapons(List<Weapon> value) {
    _json['weapons'] = value.toList();
  }

  String get classType {
    return _json['classType'] as String;
  }

  set classType(String value) {
    _json['classType'] = value;
  }

  String? get affiliation {
    return _json['affiliation'] as String?;
  }

  set affiliation(String? value) {
    if (value == null) {
      _json.remove('affiliation');
    } else {
      _json['affiliation'] = value;
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

class _RpgCharacterTypeFactory extends SchemanticType<RpgCharacter> {
  const _RpgCharacterTypeFactory();

  @override
  RpgCharacter parse(Object? json) {
    return RpgCharacter._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RpgCharacter',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'backstory': Schema.string(),
        'weapons': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Weapon'}),
        ),
        'classType': Schema.string(
          enumValues: ['RANGER', 'WIZZARD', 'TANK', 'HEALER', 'ENGINEER'],
        ),
        'affiliation': Schema.string(),
      },
      required: ['name', 'backstory', 'weapons', 'classType'],
    ),
    dependencies: [Weapon.$schema],
  );
}

class CharacterProfile {
  factory CharacterProfile.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CharacterProfile._(this._json);

  CharacterProfile({
    required String name,
    required String bio,
    required int age,
  }) {
    _json = {'name': name, 'bio': bio, 'age': age};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<CharacterProfile> $schema =
      _CharacterProfileTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get bio {
    return _json['bio'] as String;
  }

  set bio(String value) {
    _json['bio'] = value;
  }

  int get age {
    return _json['age'] as int;
  }

  set age(int value) {
    _json['age'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _CharacterProfileTypeFactory extends SchemanticType<CharacterProfile> {
  const _CharacterProfileTypeFactory();

  @override
  CharacterProfile parse(Object? json) {
    return CharacterProfile._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CharacterProfile',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'bio': Schema.string(),
        'age': Schema.integer(),
      },
      required: ['name', 'bio', 'age'],
    ),
    dependencies: [],
  );
}
