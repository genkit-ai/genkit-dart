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

part of 'model.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class WeatherToolInput {
  /// Creates a [WeatherToolInput] from a JSON map.
  factory WeatherToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolInput._(this._json);

  WeatherToolInput({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WeatherToolInput].
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

  /// Serializes this [WeatherToolInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WeatherToolInputTypeFactory
    extends SchemanticType<WeatherToolInput> {
  const _WeatherToolInputTypeFactory();

  @override
  WeatherToolInput parse(Object? json) {
    return WeatherToolInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherToolInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'location': <String, Object?>{
          'type': 'string',
          'description':
              'The location (ex. city, state, country) to get the weather for',
        },
      },
      'required': ['location'],
    },
    dependencies: [],
  );
}

base class Category {
  /// Creates a [Category] from a JSON map.
  factory Category.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Category._(this._json);

  Category({required String name, List<Category>? subcategories}) {
    _json = {
      'name': name,
      'subcategories': ?subcategories?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Category].
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
      _json['subcategories'] = value.map((e) => e.toJson()).toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Category] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CategoryTypeFactory extends SchemanticType<Category> {
  const _CategoryTypeFactory();

  @override
  Category parse(Object? json) {
    return Category._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Category',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'name': <String, Object?>{'type': 'string'},
        'subcategories': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/Category'},
        },
      },
      'required': ['name'],
    },
    dependencies: [Category.$schema],
  );
}

base class Weapon {
  /// Creates a [Weapon] from a JSON map.
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

  /// The JSON schema and type descriptor for [Weapon].
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
    _json['category'] = value.toJson();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Weapon] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WeaponTypeFactory extends SchemanticType<Weapon> {
  const _WeaponTypeFactory();

  @override
  Weapon parse(Object? json) {
    return Weapon._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Weapon',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'name': <String, Object?>{'type': 'string'},
        'damage': <String, Object?>{'type': 'number'},
        'category': <String, Object?>{r'$ref': r'#/$defs/Category'},
      },
      'required': ['name', 'damage', 'category'],
    },
    dependencies: [Category.$schema],
  );
}

base class RpgCharacter {
  /// Creates a [RpgCharacter] from a JSON map.
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

  /// The JSON schema and type descriptor for [RpgCharacter].
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
    _json['weapons'] = value.map((e) => e.toJson()).toList();
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

  /// Serializes this [RpgCharacter] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RpgCharacterTypeFactory extends SchemanticType<RpgCharacter> {
  const _RpgCharacterTypeFactory();

  @override
  RpgCharacter parse(Object? json) {
    return RpgCharacter._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RpgCharacter',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'name': <String, Object?>{'type': 'string'},
        'backstory': <String, Object?>{'type': 'string'},
        'weapons': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{r'$ref': r'#/$defs/Weapon'},
        },
        'classType': <String, Object?>{
          'type': 'string',
          'enum': ['RANGER', 'WIZZARD', 'TANK', 'HEALER', 'ENGINEER'],
        },
        'affiliation': <String, Object?>{'type': 'string'},
      },
      'required': ['name', 'backstory', 'weapons', 'classType'],
    },
    dependencies: [Weapon.$schema],
  );
}

base class CharacterProfile {
  /// Creates a [CharacterProfile] from a JSON map.
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

  /// The JSON schema and type descriptor for [CharacterProfile].
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

  /// Serializes this [CharacterProfile] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CharacterProfileTypeFactory
    extends SchemanticType<CharacterProfile> {
  const _CharacterProfileTypeFactory();

  @override
  CharacterProfile parse(Object? json) {
    return CharacterProfile._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CharacterProfile',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'name': <String, Object?>{'type': 'string'},
        'bio': <String, Object?>{'type': 'string'},
        'age': <String, Object?>{'type': 'integer'},
      },
      'required': ['name', 'bio', 'age'],
    },
    dependencies: [],
  );
}

base class MultimodalEmbeddingInput {
  /// Creates a [MultimodalEmbeddingInput] from a JSON map.
  factory MultimodalEmbeddingInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MultimodalEmbeddingInput._(this._json);

  MultimodalEmbeddingInput({
    required String caption,
    required String imageUri,
  }) {
    _json = {'caption': caption, 'imageUri': imageUri};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [MultimodalEmbeddingInput].
  static const SchemanticType<MultimodalEmbeddingInput> $schema =
      _MultimodalEmbeddingInputTypeFactory();

  String get caption {
    return _json['caption'] as String;
  }

  set caption(String value) {
    _json['caption'] = value;
  }

  String get imageUri {
    return _json['imageUri'] as String;
  }

  set imageUri(String value) {
    _json['imageUri'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [MultimodalEmbeddingInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _MultimodalEmbeddingInputTypeFactory
    extends SchemanticType<MultimodalEmbeddingInput> {
  const _MultimodalEmbeddingInputTypeFactory();

  @override
  MultimodalEmbeddingInput parse(Object? json) {
    return MultimodalEmbeddingInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MultimodalEmbeddingInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'caption': <String, Object?>{
          'type': 'string',
          'description': 'Text to embed alongside the image.',
          'default': 'a plate of scones',
        },
        'imageUri': <String, Object?>{
          'type': 'string',
          'description':
              'gs:// (or data:) URI of an image to embed as a separate modality from the caption.',
          'default': 'gs://cloud-samples-data/generative-ai/image/scones.jpg',
        },
      },
      'required': ['caption', 'imageUri'],
    },
    dependencies: [],
  );
}
