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

part of 'simulate_constrained_generation_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class Person {
  /// Creates a [Person] from a JSON map.
  factory Person.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Person._(this._json);

  Person({required String name, required int age}) {
    _json = {'name': name, 'age': age};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Person].
  static const SchemanticType<Person> $schema = _PersonTypeFactory();

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

  /// Serializes this [Person] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _PersonTypeFactory extends SchemanticType<Person> {
  const _PersonTypeFactory();

  @override
  Person parse(Object? json) {
    return Person._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Person',
    definition: $Schema
        .object(
          properties: {'name': $Schema.string(), 'age': $Schema.integer()},
          required: ['name', 'age'],
        )
        .value,
    dependencies: [],
  );
}
