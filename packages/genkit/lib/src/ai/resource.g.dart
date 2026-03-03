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

part of 'resource.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ResourceInput {
  factory ResourceInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResourceInput._(this._json);

  ResourceInput({required String uri}) {
    _json = {'uri': uri};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ResourceInput> $schema =
      _ResourceInputTypeFactory();

  String get uri {
    return _json['uri'] as String;
  }

  set uri(String value) {
    _json['uri'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResourceInputTypeFactory extends SchemanticType<ResourceInput> {
  const _ResourceInputTypeFactory();

  @override
  ResourceInput parse(Object? json) {
    return ResourceInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResourceInput',
    definition: $Schema
        .object(properties: {'uri': $Schema.string()}, required: ['uri'])
        .value,
    dependencies: [],
  );
}

base class ResourceOutput {
  factory ResourceOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ResourceOutput._(this._json);

  ResourceOutput({required List<Part> content}) {
    _json = {'content': content.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ResourceOutput> $schema =
      _ResourceOutputTypeFactory();

  List<Part> get content {
    return (_json['content'] as List)
        .map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set content(List<Part> value) {
    _json['content'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ResourceOutputTypeFactory extends SchemanticType<ResourceOutput> {
  const _ResourceOutputTypeFactory();

  @override
  ResourceOutput parse(Object? json) {
    return ResourceOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ResourceOutput',
    definition: $Schema
        .object(
          properties: {
            'content': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Part'}),
            ),
          },
          required: ['content'],
        )
        .value,
    dependencies: [Part.$schema],
  );
}
