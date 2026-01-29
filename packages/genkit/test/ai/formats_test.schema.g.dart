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

part of 'formats_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class TestObject implements TestObjectSchema {
  TestObject(this._json);

  factory TestObject.from({required String foo, required int bar}) {
    return TestObject({'foo': foo, 'bar': bar});
  }

  Map<String, dynamic> _json;

  @override
  String get foo {
    return _json['foo'] as String;
  }

  set foo(String value) {
    _json['foo'] = value;
  }

  @override
  int get bar {
    return _json['bar'] as int;
  }

  set bar(int value) {
    _json['bar'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _TestObjectTypeFactory extends SchemanticType<TestObject> {
  const _TestObjectTypeFactory();

  @override
  TestObject parse(Object? json) {
    return TestObject(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TestObject',
    definition: Schema.object(
      properties: {'foo': Schema.string(), 'bar': Schema.integer()},
      required: ['foo', 'bar'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const TestObjectType = _TestObjectTypeFactory();
