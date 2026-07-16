// Copyright 2026 Google LLC
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

part of 'workspace_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class WriteArtifactInput {
  /// Creates a [WriteArtifactInput] from a JSON map.
  factory WriteArtifactInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WriteArtifactInput._(this._json);

  WriteArtifactInput({required String name, required String content}) {
    _json = {'name': name, 'content': content};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WriteArtifactInput].
  static const SchemanticType<WriteArtifactInput> $schema =
      _WriteArtifactInputTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get content {
    return _json['content'] as String;
  }

  set content(String value) {
    _json['content'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [WriteArtifactInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WriteArtifactInputTypeFactory
    extends SchemanticType<WriteArtifactInput> {
  const _WriteArtifactInputTypeFactory();

  @override
  WriteArtifactInput parse(Object? json) {
    return WriteArtifactInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WriteArtifactInput',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(
              description: 'The name (e.g. filename) of the artifact.',
            ),
            'content': $Schema.string(
              description: 'The full content of the artifact.',
            ),
          },
          required: ['name', 'content'],
        )
        .value,
    dependencies: [],
  );
}

base class ReadArtifactInput {
  /// Creates a [ReadArtifactInput] from a JSON map.
  factory ReadArtifactInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReadArtifactInput._(this._json);

  ReadArtifactInput({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReadArtifactInput].
  static const SchemanticType<ReadArtifactInput> $schema =
      _ReadArtifactInputTypeFactory();

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

  /// Serializes this [ReadArtifactInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReadArtifactInputTypeFactory
    extends SchemanticType<ReadArtifactInput> {
  const _ReadArtifactInputTypeFactory();

  @override
  ReadArtifactInput parse(Object? json) {
    return ReadArtifactInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReadArtifactInput',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(
              description: 'The name of the artifact to read.',
            ),
          },
          required: ['name'],
        )
        .value,
    dependencies: [],
  );
}
