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

part of 'generate_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type TestToolInput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory TestToolInput.from({required String name}) {
    return TestToolInput({'name': name});
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

class TestToolInputTypeFactory extends JsonExtensionType<TestToolInput> {
  const TestToolInputTypeFactory();

  @override
  TestToolInput parse(Object json) {
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
const TestToolInputType = TestToolInputTypeFactory();
