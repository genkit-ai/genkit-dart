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

part of 'example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type WeatherToolInput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory WeatherToolInput.from({required String location}) {
    return WeatherToolInput({'location': location});
  }

  String get location {
    return _json['location'] as String;
  }

  set location(String value) {
    _json['location'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _WeatherToolInputTypeFactory extends JsonExtensionType<WeatherToolInput> {
  const _WeatherToolInputTypeFactory();

  @override
  WeatherToolInput parse(Object? json) {
    return WeatherToolInput(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const WeatherToolInputType = _WeatherToolInputTypeFactory();

extension type Category(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Category.from({required String name, List<Category>? subcategories}) {
    return Category({
      'name': name,
      if (subcategories != null)
        'subcategories': subcategories.map((e) => e.toJson()).toList(),
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  List<Category>? get subcategories {
    return (_json['subcategories'] as List?)
        ?.map((e) => Category(e as Map<String, dynamic>))
        .toList();
  }

  set subcategories(List<Category>? value) {
    if (value == null) {
      _json.remove('subcategories');
    } else {
      _json['subcategories'] = value.toList();
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _CategoryTypeFactory extends JsonExtensionType<Category> {
  const _CategoryTypeFactory();

  @override
  Category parse(Object? json) {
    return Category(json as Map<String, dynamic>);
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
    dependencies: [CategoryType],
  );
}

// ignore: constant_identifier_names
const CategoryType = _CategoryTypeFactory();

extension type Weapon(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Weapon.from({
    required String name,
    required double damage,
    required Category category,
  }) {
    return Weapon({
      'name': name,
      'damage': damage,
      'category': category.toJson(),
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  double get damage {
    return _json['damage'] as double;
  }

  set damage(double value) {
    _json['damage'] = value;
  }

  Category get category {
    return Category(_json['category'] as Map<String, dynamic>);
  }

  set category(Category value) {
    _json['category'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _WeaponTypeFactory extends JsonExtensionType<Weapon> {
  const _WeaponTypeFactory();

  @override
  Weapon parse(Object? json) {
    return Weapon(json as Map<String, dynamic>);
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
    dependencies: [CategoryType],
  );
}

// ignore: constant_identifier_names
const WeaponType = _WeaponTypeFactory();

extension type RpgCharacter(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory RpgCharacter.from({
    required String name,
    required String backstory,
    required List<Weapon> weapons,
    required String classType,
    String? affiliation,
  }) {
    return RpgCharacter({
      'name': name,
      'backstory': backstory,
      'weapons': weapons.map((e) => e.toJson()).toList(),
      'classType': classType,
      if (affiliation != null) 'affiliation': affiliation,
    });
  }

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
        .map((e) => Weapon(e as Map<String, dynamic>))
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _RpgCharacterTypeFactory extends JsonExtensionType<RpgCharacter> {
  const _RpgCharacterTypeFactory();

  @override
  RpgCharacter parse(Object? json) {
    return RpgCharacter(json as Map<String, dynamic>);
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
    dependencies: [WeaponType],
  );
}

// ignore: constant_identifier_names
const RpgCharacterType = _RpgCharacterTypeFactory();
