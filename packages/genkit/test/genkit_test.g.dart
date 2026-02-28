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

part of 'genkit_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TestCustomOptions {
  factory TestCustomOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TestCustomOptions._(this._json);

  TestCustomOptions({required String customField}) {
    _json = {'customField': customField};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TestCustomOptions> $schema =
      _TestCustomOptionsTypeFactory();

  String get customField {
    return _json['customField'] as String;
  }

  set customField(String value) {
    _json['customField'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TestCustomOptionsTypeFactory
    extends SchemanticType<TestCustomOptions> {
  const _TestCustomOptionsTypeFactory();

  @override
  TestCustomOptions parse(Object? json) {
    return TestCustomOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestCustomOptions',
    definition: $Schema
        .object(
          properties: {'customField': $Schema.string()},
          required: ['customField'],
        )
        .value,
    dependencies: [],
  );
}

base class TestToolInput {
  factory TestToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TestToolInput._(this._json);

  TestToolInput({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TestToolInput> $schema =
      _TestToolInputTypeFactory();

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

base class _TestToolInputTypeFactory extends SchemanticType<TestToolInput> {
  const _TestToolInputTypeFactory();

  @override
  TestToolInput parse(Object? json) {
    return TestToolInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestToolInput',
    definition: $Schema
        .object(properties: {'name': $Schema.string()}, required: ['name'])
        .value,
    dependencies: [],
  );
}

base class TestOutputSchema {
  factory TestOutputSchema.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TestOutputSchema._(this._json);

  TestOutputSchema({required String title, required int rating}) {
    _json = {'title': title, 'rating': rating};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<TestOutputSchema> $schema =
      _TestOutputSchemaTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  int get rating {
    return _json['rating'] as int;
  }

  set rating(int value) {
    _json['rating'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TestOutputSchemaTypeFactory
    extends SchemanticType<TestOutputSchema> {
  const _TestOutputSchemaTypeFactory();

  @override
  TestOutputSchema parse(Object? json) {
    return TestOutputSchema._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestOutputSchema',
    definition: $Schema
        .object(
          properties: {'title': $Schema.string(), 'rating': $Schema.integer()},
          required: ['title', 'rating'],
        )
        .value,
    dependencies: [],
  );
}
