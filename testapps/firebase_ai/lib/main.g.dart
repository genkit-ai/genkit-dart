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

part of 'main.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class WeatherToolInput {
  factory WeatherToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolInput._(this._json);

  WeatherToolInput({required String city}) {
    _json = {'city': city};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WeatherToolInput> $schema =
      _WeatherToolInputTypeFactory();

  String get city {
    return _json['city'] as String;
  }

  set city(String value) {
    _json['city'] = value;
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
    definition: $Schema
        .object(
          properties: {
            'city': $Schema.string(
              description: 'The city to get the weather for',
            ),
          },
          required: ['city'],
        )
        .value,
    dependencies: [],
  );
}

class RpgCharacter {
  factory RpgCharacter.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RpgCharacter._(this._json);

  RpgCharacter({
    required String name,
    required String description,
    required String background,
    required List<String> skills,
    required List<String> inventory,
  }) {
    _json = {
      'name': name,
      'description': description,
      'background': background,
      'skills': skills,
      'inventory': inventory,
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

  String get description {
    return _json['description'] as String;
  }

  set description(String value) {
    _json['description'] = value;
  }

  String get background {
    return _json['background'] as String;
  }

  set background(String value) {
    _json['background'] = value;
  }

  List<String> get skills {
    return (_json['skills'] as List).cast<String>();
  }

  set skills(List<String> value) {
    _json['skills'] = value;
  }

  List<String> get inventory {
    return (_json['inventory'] as List).cast<String>();
  }

  set inventory(List<String> value) {
    _json['inventory'] = value;
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
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'description': $Schema.string(),
            'background': $Schema.string(),
            'skills': $Schema.list(items: $Schema.string()),
            'inventory': $Schema.list(items: $Schema.string()),
          },
          required: [
            'name',
            'description',
            'background',
            'skills',
            'inventory',
          ],
        )
        .value,
    dependencies: [],
  );
}
