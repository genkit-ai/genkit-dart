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

part of 'tool_calling.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ToolCallingInput {
  factory ToolCallingInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolCallingInput._(this._json);

  ToolCallingInput({required String prompt}) {
    _json = {'prompt': prompt};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolCallingInput> $schema =
      _ToolCallingInputTypeFactory();

  String get prompt {
    return _json['prompt'] as String;
  }

  set prompt(String value) {
    _json['prompt'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolCallingInputTypeFactory extends SchemanticType<ToolCallingInput> {
  const _ToolCallingInputTypeFactory();

  @override
  ToolCallingInput parse(Object? json) {
    return ToolCallingInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolCallingInput',
    definition: $Schema
        .object(properties: {'prompt': $Schema.string()}, required: ['prompt'])
        .value,
    dependencies: [],
  );
}

class ToolCallingWeatherInput {
  factory ToolCallingWeatherInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolCallingWeatherInput._(this._json);

  ToolCallingWeatherInput({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolCallingWeatherInput> $schema =
      _ToolCallingWeatherInputTypeFactory();

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

class _ToolCallingWeatherInputTypeFactory
    extends SchemanticType<ToolCallingWeatherInput> {
  const _ToolCallingWeatherInputTypeFactory();

  @override
  ToolCallingWeatherInput parse(Object? json) {
    return ToolCallingWeatherInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolCallingWeatherInput',
    definition: $Schema
        .object(
          properties: {'location': $Schema.string()},
          required: ['location'],
        )
        .value,
    dependencies: [],
  );
}
