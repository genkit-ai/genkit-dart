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

final class WeatherInputSchema {
  factory WeatherInputSchema.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherInputSchema._(this._json);

  WeatherInputSchema({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WeatherInputSchema> $schema =
      _WeatherInputSchemaTypeFactory();

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

base class _WeatherInputSchemaTypeFactory
    extends SchemanticType<WeatherInputSchema> {
  const _WeatherInputSchemaTypeFactory();

  @override
  WeatherInputSchema parse(Object? json) {
    return WeatherInputSchema._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherInputSchema',
    definition: $Schema
        .object(
          properties: {'location': $Schema.string()},
          required: ['location'],
        )
        .value,
    dependencies: [],
  );
}

final class PersonSchema {
  factory PersonSchema.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PersonSchema._(this._json);

  PersonSchema({required String name, required int age}) {
    _json = {'name': name, 'age': age};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<PersonSchema> $schema =
      _PersonSchemaTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
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

base class _PersonSchemaTypeFactory extends SchemanticType<PersonSchema> {
  const _PersonSchemaTypeFactory();

  @override
  PersonSchema parse(Object? json) {
    return PersonSchema._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PersonSchema',
    definition: $Schema
        .object(
          properties: {'name': $Schema.string(), 'age': $Schema.integer()},
          required: ['name', 'age'],
        )
        .value,
    dependencies: [],
  );
}
