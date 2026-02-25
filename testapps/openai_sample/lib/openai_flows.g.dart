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

part of 'openai_flows.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class WeatherInputSchema {
  factory WeatherInputSchema.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherInputSchema._(this._json);

  WeatherInputSchema({required String location, String? unit}) {
    _json = {'location': location, 'unit': ?unit};
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

  String? get unit {
    return _json['unit'] as String?;
  }

  set unit(String? value) {
    if (value == null) {
      _json.remove('unit');
    } else {
      _json['unit'] = value;
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

class _WeatherInputSchemaTypeFactory
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
          properties: {
            'location': $Schema.string(),
            'unit': $Schema.string(enumValues: ['celsius', 'fahrenheit']),
          },
          required: ['location'],
        )
        .value,
    dependencies: [],
  );
}

class WeatherOutputSchema {
  factory WeatherOutputSchema.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherOutputSchema._(this._json);

  WeatherOutputSchema({
    required double temperature,
    required String condition,
    required String unit,
    int? humidity,
  }) {
    _json = {
      'temperature': temperature,
      'condition': condition,
      'unit': unit,
      'humidity': ?humidity,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WeatherOutputSchema> $schema =
      _WeatherOutputSchemaTypeFactory();

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

  String get unit {
    return _json['unit'] as String;
  }

  set unit(String value) {
    _json['unit'] = value;
  }

  int? get humidity {
    return _json['humidity'] as int?;
  }

  set humidity(int? value) {
    if (value == null) {
      _json.remove('humidity');
    } else {
      _json['humidity'] = value;
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

class _WeatherOutputSchemaTypeFactory
    extends SchemanticType<WeatherOutputSchema> {
  const _WeatherOutputSchemaTypeFactory();

  @override
  WeatherOutputSchema parse(Object? json) {
    return WeatherOutputSchema._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherOutputSchema',
    definition: $Schema
        .object(
          properties: {
            'temperature': $Schema.number(),
            'condition': $Schema.string(),
            'unit': $Schema.string(),
            'humidity': $Schema.integer(),
          },
          required: ['temperature', 'condition', 'unit'],
        )
        .value,
    dependencies: [],
  );
}
