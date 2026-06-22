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

  /// City name to look up.
  String get location {
    return _json['location'] as String;
  }

  /// City name to look up.
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
    definition: $Schema
        .object(
          properties: {'location': $Schema.string()},
          required: ['location'],
        )
        .value,
    dependencies: [],
  );
}

base class WeatherToolOutput {
  /// Creates a [WeatherToolOutput] from a JSON map.
  factory WeatherToolOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolOutput._(this._json);

  WeatherToolOutput({required double temperature, required String condition}) {
    _json = {'temperature': temperature, 'condition': condition};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WeatherToolOutput].
  static const SchemanticType<WeatherToolOutput> $schema =
      _WeatherToolOutputTypeFactory();

  double get temperature {
    return (_json['temperature'] as num).toDouble();
  }

  set temperature(double value) {
    _json['temperature'] = value;
  }

  String get condition {
    return _json['condition'] as String;
  }

  set condition(String value) {
    _json['condition'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [WeatherToolOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WeatherToolOutputTypeFactory
    extends SchemanticType<WeatherToolOutput> {
  const _WeatherToolOutputTypeFactory();

  @override
  WeatherToolOutput parse(Object? json) {
    return WeatherToolOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherToolOutput',
    definition: $Schema
        .object(
          properties: {
            'temperature': $Schema.number(),
            'condition': $Schema.string(),
          },
          required: ['temperature', 'condition'],
        )
        .value,
    dependencies: [],
  );
}
