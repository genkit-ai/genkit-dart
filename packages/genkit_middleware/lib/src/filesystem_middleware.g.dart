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

base class FilesystemOptions {
  /// Creates a [FilesystemOptions] from a JSON map.
  factory FilesystemOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  FilesystemOptions._(this._json);

  FilesystemOptions({required String rootDirectory}) {
    _json = {'rootDirectory': rootDirectory};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [FilesystemOptions].
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

  /// Serializes this [FilesystemOptions] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _FilesystemOptionsTypeFactory
    extends SchemanticType<FilesystemOptions> {
  const _FilesystemOptionsTypeFactory();

  @override
  FilesystemOptions parse(Object? json) {
    return FilesystemOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'FilesystemOptions',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'rootDirectory': <String, Object?>{
          'type': 'string',
          'description':
              'The root directory to which all filesystem operations are restricted.',
        },
      },
      'required': ['rootDirectory'],
    },
    dependencies: [],
  );
}

base class ListFilesInput {
  /// Creates a [ListFilesInput] from a JSON map.
  factory ListFilesInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ListFilesInput._(this._json);

  ListFilesInput({String? dirPath, bool? recursive}) {
    _json = {'dirPath': ?dirPath, 'recursive': ?recursive};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ListFilesInput].
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

  /// Serializes this [ListFilesInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ListFilesInputTypeFactory extends SchemanticType<ListFilesInput> {
  const _ListFilesInputTypeFactory();

  @override
  ListFilesInput parse(Object? json) {
    return ListFilesInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ListFilesInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'dirPath': <String, Object?>{
          'type': 'string',
          'description': 'Directory path relative to root.',
          'default': '',
        },
        'recursive': <String, Object?>{
          'type': 'boolean',
          'description': 'Whether to list files recursively.',
          'default': false,
        },
      },
    },
    dependencies: [],
  );
}

base class ReadFileInput {
  /// Creates a [ReadFileInput] from a JSON map.
  factory ReadFileInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ReadFileInput._(this._json);

  ReadFileInput({required String filePath}) {
    _json = {'filePath': filePath};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ReadFileInput].
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

  /// Serializes this [ReadFileInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ReadFileInputTypeFactory extends SchemanticType<ReadFileInput> {
  const _ReadFileInputTypeFactory();

  @override
  ReadFileInput parse(Object? json) {
    return ReadFileInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ReadFileInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'filePath': <String, Object?>{
          'type': 'string',
          'description': 'File path relative to root.',
        },
      },
      'required': ['filePath'],
    },
    dependencies: [],
  );
}

base class WriteFileInput {
  /// Creates a [WriteFileInput] from a JSON map.
  factory WriteFileInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  WriteFileInput._(this._json);

  WriteFileInput({required String filePath, required String content}) {
    _json = {'filePath': filePath, 'content': content};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [WriteFileInput].
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

  /// Serializes this [WriteFileInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _WriteFileInputTypeFactory extends SchemanticType<WriteFileInput> {
  const _WriteFileInputTypeFactory();

  @override
  WriteFileInput parse(Object? json) {
    return WriteFileInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'WriteFileInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'filePath': <String, Object?>{
          'type': 'string',
          'description': 'File path relative to root.',
        },
        'content': <String, Object?>{
          'type': 'string',
          'description': 'Content to write to the file.',
        },
      },
      'required': ['filePath', 'content'],
    },
    dependencies: [],
  );
}

base class SearchAndReplaceInput {
  /// Creates a [SearchAndReplaceInput] from a JSON map.
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

  /// The JSON schema and type descriptor for [SearchAndReplaceInput].
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

  /// Serializes this [SearchAndReplaceInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SearchAndReplaceInputTypeFactory
    extends SchemanticType<SearchAndReplaceInput> {
  const _SearchAndReplaceInputTypeFactory();

  @override
  SearchAndReplaceInput parse(Object? json) {
    return SearchAndReplaceInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SearchAndReplaceInput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'filePath': <String, Object?>{
          'type': 'string',
          'description': 'File path relative to root.',
        },
        'edits': <String, Object?>{
          'type': 'array',
          'description':
              'A search and replace block string in the format:\n<<<<<<< SEARCH\n[search content]\n=======\n[replace content]\n>>>>>>> REPLACE',
          'items': <String, Object?>{'type': 'string'},
        },
      },
      'required': ['filePath', 'edits'],
    },
    dependencies: [],
  );
}

base class ListFileOutputItem {
  /// Creates a [ListFileOutputItem] from a JSON map.
  factory ListFileOutputItem.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ListFileOutputItem._(this._json);

  ListFileOutputItem({required String path, required bool isDirectory}) {
    _json = {'path': path, 'isDirectory': isDirectory};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ListFileOutputItem].
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

  /// Serializes this [ListFileOutputItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ListFileOutputItemTypeFactory
    extends SchemanticType<ListFileOutputItem> {
  const _ListFileOutputItemTypeFactory();

  @override
  ListFileOutputItem parse(Object? json) {
    return ListFileOutputItem._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ListFileOutputItem',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'path': <String, Object?>{'type': 'string'},
        'isDirectory': <String, Object?>{'type': 'boolean'},
      },
      'required': ['path', 'isDirectory'],
    },
    dependencies: [],
  );
}
