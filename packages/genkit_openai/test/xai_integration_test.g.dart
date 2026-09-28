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

part of 'xai_integration_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class CityQuery {
  /// Creates a [CityQuery] from a JSON map.
  factory CityQuery.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  CityQuery._(this._json);

  CityQuery({required String city}) {
    _json = {'city': city};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [CityQuery].
  static const SchemanticType<CityQuery> $schema = _CityQueryTypeFactory();

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

  /// Serializes this [CityQuery] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CityQueryTypeFactory extends SchemanticType<CityQuery> {
  const _CityQueryTypeFactory();

  @override
  CityQuery parse(Object? json) {
    return CityQuery._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CityQuery',
    definition: $Schema
        .object(properties: {'city': $Schema.string()}, required: ['city'])
        .value,
    dependencies: [],
  );
}

base class CityFact {
  /// Creates a [CityFact] from a JSON map.
  factory CityFact.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  CityFact._(this._json);

  CityFact({required String city, required String country}) {
    _json = {'city': city, 'country': country};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [CityFact].
  static const SchemanticType<CityFact> $schema = _CityFactTypeFactory();

  String get city {
    return _json['city'] as String;
  }

  set city(String value) {
    _json['city'] = value;
  }

  String get country {
    return _json['country'] as String;
  }

  set country(String value) {
    _json['country'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [CityFact] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CityFactTypeFactory extends SchemanticType<CityFact> {
  const _CityFactTypeFactory();

  @override
  CityFact parse(Object? json) {
    return CityFact._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CityFact',
    definition: $Schema
        .object(
          properties: {'city': $Schema.string(), 'country': $Schema.string()},
          required: ['city', 'country'],
        )
        .value,
    dependencies: [],
  );
}
