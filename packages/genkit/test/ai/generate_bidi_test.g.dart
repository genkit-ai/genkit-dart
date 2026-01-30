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

part of 'generate_bidi_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class MyToolInput {
  factory MyToolInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MyToolInput._(this._json);

  MyToolInput({required String location}) {
    _json = {'location': location};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MyToolInput> $schema = _MyToolInputTypeFactory();

  String get location {
    return _json['location'] as String;
  }

  set location(String value) {
    _json['location'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MyToolInputTypeFactory extends SchemanticType<MyToolInput> {
  const _MyToolInputTypeFactory();

  @override
  MyToolInput parse(Object? json) {
    return MyToolInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MyToolInput',
    definition: Schema.object(
      properties: {'location': Schema.string()},
      required: ['location'],
    ),
    dependencies: [],
  );
}
