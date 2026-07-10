// Copyright 2026 Google LLC
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

part of 'weather_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GetWeatherInput {
  /// Creates a [GetWeatherInput] from a JSON map.
  factory GetWeatherInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetWeatherInput._(this._json);

  GetWeatherInput({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetWeatherInput].
  static const SchemanticType<GetWeatherInput> $schema =
      _GetWeatherInputTypeFactory();

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

  /// Serializes this [GetWeatherInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetWeatherInputTypeFactory extends SchemanticType<GetWeatherInput> {
  const _GetWeatherInputTypeFactory();

  @override
  GetWeatherInput parse(Object? json) {
    return GetWeatherInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetWeatherInput',
    definition: $Schema
        .object(
          properties: {'location': $Schema.string()},
          required: ['location'],
        )
        .value,
    dependencies: [],
  );
}

base class GetWeatherOutput {
  /// Creates a [GetWeatherOutput] from a JSON map.
  factory GetWeatherOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetWeatherOutput._(this._json);

  GetWeatherOutput({required String weather, required String temperature}) {
    _json = {'weather': weather, 'temperature': temperature};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetWeatherOutput].
  static const SchemanticType<GetWeatherOutput> $schema =
      _GetWeatherOutputTypeFactory();

  String get weather {
    return _json['weather'] as String;
  }

  set weather(String value) {
    _json['weather'] = value;
  }

  String get temperature {
    return _json['temperature'] as String;
  }

  set temperature(String value) {
    _json['temperature'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetWeatherOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetWeatherOutputTypeFactory
    extends SchemanticType<GetWeatherOutput> {
  const _GetWeatherOutputTypeFactory();

  @override
  GetWeatherOutput parse(Object? json) {
    return GetWeatherOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetWeatherOutput',
    definition: $Schema
        .object(
          properties: {
            'weather': $Schema.string(),
            'temperature': $Schema.string(),
          },
          required: ['weather', 'temperature'],
        )
        .value,
    dependencies: [],
  );
}
