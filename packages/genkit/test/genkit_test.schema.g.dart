// dart format width=80
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

// GENERATED CODE BY schemantic - DO NOT MODIFY BY HAND
// To regenerate, run `dart run build_runner build -d`

part of 'genkit_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class TestCustomOptions implements TestCustomOptionsSchema {
  TestCustomOptions(this._json);

  factory TestCustomOptions.from({required String customField}) {
    return TestCustomOptions({'customField': customField});
  }

  Map<String, dynamic> _json;

  @override
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

class _TestCustomOptionsTypeFactory extends SchemanticType<TestCustomOptions> {
  const _TestCustomOptionsTypeFactory();

  @override
  TestCustomOptions parse(Object? json) {
    return TestCustomOptions(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestCustomOptions',
    definition: Schema.object(
      properties: {'customField': Schema.string()},
      required: ['customField'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TestCustomOptionsType = _TestCustomOptionsTypeFactory();

class TestToolInput implements TestToolInputSchema {
  TestToolInput(this._json);

  factory TestToolInput.from({required String name}) {
    return TestToolInput({'name': name});
  }

  Map<String, dynamic> _json;

  @override
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

class _TestToolInputTypeFactory extends SchemanticType<TestToolInput> {
  const _TestToolInputTypeFactory();

  @override
  TestToolInput parse(Object? json) {
    return TestToolInput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestToolInput',
    definition: Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TestToolInputType = _TestToolInputTypeFactory();
