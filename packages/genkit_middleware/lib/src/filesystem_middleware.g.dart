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

part of 'filesystem_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class FilesystemOptions {
  factory FilesystemOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  FilesystemOptions._(this._json);

  FilesystemOptions({required String rootDirectory}) {
    _json = {'rootDirectory': rootDirectory};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<FilesystemOptions> $schema =
      _FilesystemOptionsTypeFactory();

  String get rootDirectory {
    return _json['rootDirectory'] as String;
  }

  set rootDirectory(String value) {
    _json['rootDirectory'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _FilesystemOptionsTypeFactory extends SchemanticType<FilesystemOptions> {
  const _FilesystemOptionsTypeFactory();

  @override
  FilesystemOptions parse(Object? json) {
    return FilesystemOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'FilesystemOptions',
    definition: $Schema
        .object(
          properties: {
            'rootDirectory': $Schema.string(
              description:
                  'The root directory to which all filesystem operations are restricted.',
            ),
          },
          required: ['rootDirectory'],
        )
        .value,
    dependencies: [],
  );
}

class ListFilesInput {
  factory ListFilesInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ListFilesInput._(this._json);

  ListFilesInput({String? dirPath, bool? recursive}) {
    _json = {'dirPath': ?dirPath, 'recursive': ?recursive};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ListFilesInput> $schema =
      _ListFilesInputTypeFactory();

  String? get dirPath {
    return _json['dirPath'] as String?;
  }

  set dirPath(String? value) {
    if (value == null) {
      _json.remove('dirPath');
    } else {
      _json['dirPath'] = value;
    }
  }

  bool? get recursive {
    return _json['recursive'] as bool?;
  }

  set recursive(bool? value) {
    if (value == null) {
      _json.remove('recursive');
    } else {
      _json['recursive'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ListFilesInputTypeFactory extends SchemanticType<ListFilesInput> {
  const _ListFilesInputTypeFactory();

  @override
  ListFilesInput parse(Object? json) {
    return ListFilesInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ListFilesInput',
    definition: $Schema
        .object(
          properties: {
            'dirPath': $Schema.fromMap({
              'description': 'Directory path relative to root.',
              'default': '',
              'type': 'string',
            }),
            'recursive': $Schema.fromMap({
              'description': 'Whether to list files recursively.',
              'default': false,
              'type': 'boolean',
            }),
          },
          required: [],
        )
        .value,
    dependencies: [],
  );
}

class ReadFileInput {
  factory ReadFileInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReadFileInput._(this._json);

  ReadFileInput({required String filePath}) {
    _json = {'filePath': filePath};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ReadFileInput> $schema =
      _ReadFileInputTypeFactory();

  String get filePath {
    return _json['filePath'] as String;
  }

  set filePath(String value) {
    _json['filePath'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ReadFileInputTypeFactory extends SchemanticType<ReadFileInput> {
  const _ReadFileInputTypeFactory();

  @override
  ReadFileInput parse(Object? json) {
    return ReadFileInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReadFileInput',
    definition: $Schema
        .object(
          properties: {
            'filePath': $Schema.string(
              description: 'File path relative to root.',
            ),
          },
          required: ['filePath'],
        )
        .value,
    dependencies: [],
  );
}

class WriteFileInput {
  factory WriteFileInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WriteFileInput._(this._json);

  WriteFileInput({required String filePath, required String content}) {
    _json = {'filePath': filePath, 'content': content};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<WriteFileInput> $schema =
      _WriteFileInputTypeFactory();

  String get filePath {
    return _json['filePath'] as String;
  }

  set filePath(String value) {
    _json['filePath'] = value;
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _WriteFileInputTypeFactory extends SchemanticType<WriteFileInput> {
  const _WriteFileInputTypeFactory();

  @override
  WriteFileInput parse(Object? json) {
    return WriteFileInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WriteFileInput',
    definition: $Schema
        .object(
          properties: {
            'filePath': $Schema.string(
              description: 'File path relative to root.',
            ),
            'content': $Schema.string(
              description: 'Content to write to the file.',
            ),
          },
          required: ['filePath', 'content'],
        )
        .value,
    dependencies: [],
  );
}

class SearchAndReplaceInput {
  factory SearchAndReplaceInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SearchAndReplaceInput._(this._json);

  SearchAndReplaceInput({
    required String filePath,
    required List<String> edits,
  }) {
    _json = {'filePath': filePath, 'edits': edits};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<SearchAndReplaceInput> $schema =
      _SearchAndReplaceInputTypeFactory();

  String get filePath {
    return _json['filePath'] as String;
  }

  set filePath(String value) {
    _json['filePath'] = value;
  }

  List<String> get edits {
    return (_json['edits'] as List).cast<String>();
  }

  set edits(List<String> value) {
    _json['edits'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SearchAndReplaceInputTypeFactory
    extends SchemanticType<SearchAndReplaceInput> {
  const _SearchAndReplaceInputTypeFactory();

  @override
  SearchAndReplaceInput parse(Object? json) {
    return SearchAndReplaceInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SearchAndReplaceInput',
    definition: $Schema
        .object(
          properties: {
            'filePath': $Schema.string(
              description: 'File path relative to root.',
            ),
            'edits': $Schema.list(
              description:
                  'A search and replace block string in the format:\n<<<<<<< SEARCH\n[search content]\n=======\n[replace content]\n>>>>>>> REPLACE',
              items: $Schema.string(),
            ),
          },
          required: ['filePath', 'edits'],
        )
        .value,
    dependencies: [],
  );
}

class ListFileOutputItem {
  factory ListFileOutputItem.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ListFileOutputItem._(this._json);

  ListFileOutputItem({required String path, required bool isDirectory}) {
    _json = {'path': path, 'isDirectory': isDirectory};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ListFileOutputItem> $schema =
      _ListFileOutputItemTypeFactory();

  String get path {
    return _json['path'] as String;
  }

  set path(String value) {
    _json['path'] = value;
  }

  bool get isDirectory {
    return _json['isDirectory'] as bool;
  }

  set isDirectory(bool value) {
    _json['isDirectory'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ListFileOutputItemTypeFactory
    extends SchemanticType<ListFileOutputItem> {
  const _ListFileOutputItemTypeFactory();

  @override
  ListFileOutputItem parse(Object? json) {
    return ListFileOutputItem._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ListFileOutputItem',
    definition: $Schema
        .object(
          properties: {
            'path': $Schema.string(),
            'isDirectory': $Schema.boolean(),
          },
          required: ['path', 'isDirectory'],
        )
        .value,
    dependencies: [],
  );
}
