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

class WeatherFlowInput {
  factory WeatherFlowInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherFlowInput._(this._json);

  WeatherFlowInput({required String prompt}) {
    _json = {'prompt': prompt};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WeatherFlowInput> $schema =
      _WeatherFlowInputTypeFactory();

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

class _WeatherFlowInputTypeFactory extends SchemanticType<WeatherFlowInput> {
  const _WeatherFlowInputTypeFactory();

  @override
  WeatherFlowInput parse(Object? json) {
    return WeatherFlowInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherFlowInput',
    definition: Schema.object(
      properties: {'prompt': Schema.string()},
      required: ['prompt'],
    ),
    dependencies: [],
  );
}

class WeatherToolInput {
  factory WeatherToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolInput._(this._json);

  WeatherToolInput({required String location, String? unit}) {
    _json = {'location': location, 'unit': ?unit};
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
        'location': Schema.string(),
        'unit': Schema.string(enumValues: ['celsius', 'fahrenheit']),
      },
      required: ['location'],
    ),
    dependencies: [],
  );
}

class WeatherToolOutput {
  factory WeatherToolOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WeatherToolOutput._(this._json);

  WeatherToolOutput({
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

class _WeatherToolOutputTypeFactory extends SchemanticType<WeatherToolOutput> {
  const _WeatherToolOutputTypeFactory();

  @override
  WeatherToolOutput parse(Object? json) {
    return WeatherToolOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WeatherToolOutput',
    definition: Schema.object(
      properties: {
        'temperature': Schema.number(),
        'condition': Schema.string(),
        'unit': Schema.string(),
        'humidity': Schema.integer(),
      },
      required: ['temperature', 'condition', 'unit'],
    ),
    dependencies: [],
  );
}
