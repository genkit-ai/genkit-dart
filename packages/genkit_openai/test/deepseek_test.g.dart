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

part of 'deepseek_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// A trivial output schema, for the response-format assertions.
base class JsonOut {
  /// Creates a [JsonOut] from a JSON map.
  factory JsonOut.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  JsonOut._(this._json);

  JsonOut({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [JsonOut].
  static const SchemanticType<JsonOut> $schema = _JsonOutTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [JsonOut] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _JsonOutTypeFactory extends SchemanticType<JsonOut> {
  const _JsonOutTypeFactory();

  @override
  JsonOut parse(Object? json) {
    return JsonOut._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'JsonOut',
    definition: $Schema
        .object(properties: {'name': $Schema.string()}, required: ['name'])
        .value,
    dependencies: [],
  );
}
