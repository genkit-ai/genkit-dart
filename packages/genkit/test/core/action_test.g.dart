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

part of 'action_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TestInput {
  factory TestInput.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TestInput._(this._json);

  TestInput({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TestInput> $schema = _TestInputTypeFactory();

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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TestInputTypeFactory extends SchemanticType<TestInput> {
  const _TestInputTypeFactory();

  @override
  TestInput parse(Object? json) {
    return TestInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestInput',
    definition: $Schema
        .object(properties: {'name': $Schema.string()}, required: ['name'])
        .value,
    dependencies: [],
  );
}

base class TestOutput {
  factory TestOutput.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  TestOutput._(this._json);

  TestOutput({required String greeting}) {
    _json = {'greeting': greeting};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TestOutput> $schema = _TestOutputTypeFactory();

  String get greeting {
    return _json['greeting'] as String;
  }

  set greeting(String value) {
    _json['greeting'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TestOutputTypeFactory extends SchemanticType<TestOutput> {
  const _TestOutputTypeFactory();

  @override
  TestOutput parse(Object? json) {
    return TestOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestOutput',
    definition: $Schema
        .object(
          properties: {'greeting': $Schema.string()},
          required: ['greeting'],
        )
        .value,
    dependencies: [],
  );
}
