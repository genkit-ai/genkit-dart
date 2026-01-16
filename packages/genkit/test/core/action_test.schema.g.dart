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

extension type TestInput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory TestInput.from({required String name}) {
    return TestInput({'name': name});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TestInputTypeFactory extends JsonExtensionType<TestInput> {
  const _TestInputTypeFactory();

  @override
  TestInput parse(Object? json) {
    return TestInput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestInput',
    definition: Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TestInputType = _TestInputTypeFactory();

extension type TestOutput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory TestOutput.from({required String greeting}) {
    return TestOutput({'greeting': greeting});
  }

  String get greeting {
    return _json['greeting'] as String;
  }

  set greeting(String value) {
    _json['greeting'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TestOutputTypeFactory extends JsonExtensionType<TestOutput> {
  const _TestOutputTypeFactory();

  @override
  TestOutput parse(Object? json) {
    return TestOutput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestOutput',
    definition: Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TestOutputType = _TestOutputTypeFactory();
