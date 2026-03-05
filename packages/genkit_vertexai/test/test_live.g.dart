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

part of 'test_live.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class Person {
  factory Person.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Person._(this._json);

  Person({required String name, required int age}) {
    _json = {'name': name, 'age': age};
  }

  late final Map<String, dynamic> _json;

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

base class CalculatorInput {
  factory CalculatorInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CalculatorInput._(this._json);

  CalculatorInput({required int a, required int b}) {
    _json = {'a': a, 'b': b};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<CalculatorInput> $schema =
      _CalculatorInputTypeFactory();

  int get a {
    return _json['a'] as int;
  }

  set a(int value) {
    _json['a'] = value;
  }

  int get b {
    return _json['b'] as int;
  }

  set b(int value) {
    _json['b'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CalculatorInputTypeFactory extends SchemanticType<CalculatorInput> {
  const _CalculatorInputTypeFactory();

  @override
  CalculatorInput parse(Object? json) {
    return CalculatorInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CalculatorInput',
    definition: $Schema
        .object(
          properties: {'a': $Schema.integer(), 'b': $Schema.integer()},
          required: ['a', 'b'],
        )
        .value,
    dependencies: [],
  );
}
