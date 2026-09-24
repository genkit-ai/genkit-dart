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

part of 'test_live.dart';

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

base class Record {
  /// Creates a [Record] from a JSON map.
  factory Record.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Record._(this._json);

  Record({required String name, dynamic extra}) {
    _json = {'name': name, 'extra': ?extra};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Record].
  static const SchemanticType<Record> $schema = _RecordTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  dynamic get extra {
    return _json['extra'] as dynamic;
  }

  set extra(dynamic value) {
    _json['extra'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Record] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RecordTypeFactory extends SchemanticType<Record> {
  const _RecordTypeFactory();

  @override
  Record parse(Object? json) {
    return Record._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Record',
    definition: $Schema
        .object(
          properties: {'name': $Schema.string(), 'extra': $Schema.any()},
          required: ['name', 'extra'],
        )
        .value,
    dependencies: [],
  );
}

base class Scorecard {
  /// Creates a [Scorecard] from a JSON map.
  factory Scorecard.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Scorecard._(this._json);

  Scorecard({required String name, required Map<String, int> scores}) {
    _json = {'name': name, 'scores': scores};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Scorecard].
  static const SchemanticType<Scorecard> $schema = _ScorecardTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, int> get scores {
    return (_json['scores'] as Map).cast<String, int>();
  }

  set scores(Map<String, int> value) {
    _json['scores'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Scorecard] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ScorecardTypeFactory extends SchemanticType<Scorecard> {
  const _ScorecardTypeFactory();

  @override
  Scorecard parse(Object? json) {
    return Scorecard._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Scorecard',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'scores': $Schema.object(additionalProperties: $Schema.integer()),
          },
          required: ['name', 'scores'],
        )
        .value,
    dependencies: [],
  );
}

base class CalculatorInput {
  /// Creates a [CalculatorInput] from a JSON map.
  factory CalculatorInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CalculatorInput._(this._json);

  CalculatorInput({required int a, required int b}) {
    _json = {'a': a, 'b': b};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [CalculatorInput].
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

  /// Serializes this [CalculatorInput] to a JSON map.
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
