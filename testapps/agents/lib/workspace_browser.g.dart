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

part of 'workspace_browser.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class WorkspaceFile {
  /// Creates a [WorkspaceFile] from a JSON map.
  factory WorkspaceFile.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WorkspaceFile._(this._json);

  WorkspaceFile({
    required String name,
    required String path,
    required String type,
    List<WorkspaceFile>? children,
  }) {
    _json = {
      'name': name,
      'path': path,
      'type': type,
      'children': ?children?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WorkspaceFile].
  static const SchemanticType<WorkspaceFile> $schema =
      _WorkspaceFileTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get path {
    return _json['path'] as String;
  }

  set path(String value) {
    _json['path'] = value;
  }

  /// `'file'` or `'directory'`.
  String get type {
    return _json['type'] as String;
  }

  /// `'file'` or `'directory'`.
  set type(String value) {
    _json['type'] = value;
  }

  List<WorkspaceFile>? get children {
    return (_json['children'] as List?)
        ?.map((e) => WorkspaceFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set children(List<WorkspaceFile>? value) {
    if (value == null) {
      _json.remove('children');
    } else {
      _json['children'] = value.toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [WorkspaceFile] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WorkspaceFileTypeFactory extends SchemanticType<WorkspaceFile> {
  const _WorkspaceFileTypeFactory();

  @override
  WorkspaceFile parse(Object? json) {
    return WorkspaceFile._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WorkspaceFile',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'path': $Schema.string(),
            'type': $Schema.string(),
            'children': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/WorkspaceFile'}),
            ),
          },
          required: ['name', 'path', 'type'],
        )
        .value,
    dependencies: [WorkspaceFile.$schema],
  );
}

base class ListWorkspaceFilesOutput {
  /// Creates a [ListWorkspaceFilesOutput] from a JSON map.
  factory ListWorkspaceFilesOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ListWorkspaceFilesOutput._(this._json);

  ListWorkspaceFilesOutput({required List<WorkspaceFile> files}) {
    _json = {'files': files.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ListWorkspaceFilesOutput].
  static const SchemanticType<ListWorkspaceFilesOutput> $schema =
      _ListWorkspaceFilesOutputTypeFactory();

  List<WorkspaceFile> get files {
    return (_json['files'] as List)
        .map((e) => WorkspaceFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set files(List<WorkspaceFile> value) {
    _json['files'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [ListWorkspaceFilesOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ListWorkspaceFilesOutputTypeFactory
    extends SchemanticType<ListWorkspaceFilesOutput> {
  const _ListWorkspaceFilesOutputTypeFactory();

  @override
  ListWorkspaceFilesOutput parse(Object? json) {
    return ListWorkspaceFilesOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ListWorkspaceFilesOutput',
    definition: $Schema
        .object(
          properties: {
            'files': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/WorkspaceFile'}),
            ),
          },
          required: ['files'],
        )
        .value,
    dependencies: [WorkspaceFile.$schema],
  );
}

base class ReadWorkspaceFileOutput {
  /// Creates a [ReadWorkspaceFileOutput] from a JSON map.
  factory ReadWorkspaceFileOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReadWorkspaceFileOutput._(this._json);

  ReadWorkspaceFileOutput({required String path, required String content}) {
    _json = {'path': path, 'content': content};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReadWorkspaceFileOutput].
  static const SchemanticType<ReadWorkspaceFileOutput> $schema =
      _ReadWorkspaceFileOutputTypeFactory();

  String get path {
    return _json['path'] as String;
  }

  set path(String value) {
    _json['path'] = value;
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

  /// Serializes this [ReadWorkspaceFileOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReadWorkspaceFileOutputTypeFactory
    extends SchemanticType<ReadWorkspaceFileOutput> {
  const _ReadWorkspaceFileOutputTypeFactory();

  @override
  ReadWorkspaceFileOutput parse(Object? json) {
    return ReadWorkspaceFileOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReadWorkspaceFileOutput',
    definition: $Schema
        .object(
          properties: {'path': $Schema.string(), 'content': $Schema.string()},
          required: ['path', 'content'],
        )
        .value,
    dependencies: [],
  );
}
