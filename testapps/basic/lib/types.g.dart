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

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ProcessObjectInput {
  factory ProcessObjectInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ProcessObjectInput._(this._json);

  ProcessObjectInput({required String message, required int count}) {
    _json = {'message': message, 'count': count};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ProcessObjectInput> $schema =
      _ProcessObjectInputTypeFactory();

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  int get count {
    return _json['count'] as int;
  }

  set count(int value) {
    _json['count'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ProcessObjectInputTypeFactory
    extends SchemanticType<ProcessObjectInput> {
  const _ProcessObjectInputTypeFactory();

  @override
  ProcessObjectInput parse(Object? json) {
    return ProcessObjectInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ProcessObjectInput',
    definition: Schema.object(
      properties: {'message': Schema.string(), 'count': Schema.integer()},
      required: ['message', 'count'],
    ),
    dependencies: [],
  );
}

class ProcessObjectOutput {
  factory ProcessObjectOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ProcessObjectOutput._(this._json);

  ProcessObjectOutput({required String reply, required int newCount}) {
    _json = {'reply': reply, 'newCount': newCount};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ProcessObjectOutput> $schema =
      _ProcessObjectOutputTypeFactory();

  String get reply {
    return _json['reply'] as String;
  }

  set reply(String value) {
    _json['reply'] = value;
  }

  int get newCount {
    return _json['newCount'] as int;
  }

  set newCount(int value) {
    _json['newCount'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ProcessObjectOutputTypeFactory
    extends SchemanticType<ProcessObjectOutput> {
  const _ProcessObjectOutputTypeFactory();

  @override
  ProcessObjectOutput parse(Object? json) {
    return ProcessObjectOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ProcessObjectOutput',
    definition: Schema.object(
      properties: {'reply': Schema.string(), 'newCount': Schema.integer()},
      required: ['reply', 'newCount'],
    ),
    dependencies: [],
  );
}

class StreamObjectsInput {
  factory StreamObjectsInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  StreamObjectsInput._(this._json);

  StreamObjectsInput({required String prompt}) {
    _json = {'prompt': prompt};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<StreamObjectsInput> $schema =
      _StreamObjectsInputTypeFactory();

  String get prompt {
    return _json['prompt'] as String;
  }

  set prompt(String value) {
    _json['prompt'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _StreamObjectsInputTypeFactory
    extends SchemanticType<StreamObjectsInput> {
  const _StreamObjectsInputTypeFactory();

  @override
  StreamObjectsInput parse(Object? json) {
    return StreamObjectsInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'StreamObjectsInput',
    definition: Schema.object(
      properties: {'prompt': Schema.string()},
      required: ['prompt'],
    ),
    dependencies: [],
  );
}

class StreamObjectsOutput {
  factory StreamObjectsOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  StreamObjectsOutput._(this._json);

  StreamObjectsOutput({required String text, required String summary}) {
    _json = {'text': text, 'summary': summary};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<StreamObjectsOutput> $schema =
      _StreamObjectsOutputTypeFactory();

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  String get summary {
    return _json['summary'] as String;
  }

  set summary(String value) {
    _json['summary'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _StreamObjectsOutputTypeFactory
    extends SchemanticType<StreamObjectsOutput> {
  const _StreamObjectsOutputTypeFactory();

  @override
  StreamObjectsOutput parse(Object? json) {
    return StreamObjectsOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'StreamObjectsOutput',
    definition: Schema.object(
      properties: {'text': Schema.string(), 'summary': Schema.string()},
      required: ['text', 'summary'],
    ),
    dependencies: [],
  );
}

class StreamyThrowyChunk {
  factory StreamyThrowyChunk.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  StreamyThrowyChunk._(this._json);

  StreamyThrowyChunk({required int count}) {
    _json = {'count': count};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<StreamyThrowyChunk> $schema =
      _StreamyThrowyChunkTypeFactory();

  int get count {
    return _json['count'] as int;
  }

  set count(int value) {
    _json['count'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _StreamyThrowyChunkTypeFactory
    extends SchemanticType<StreamyThrowyChunk> {
  const _StreamyThrowyChunkTypeFactory();

  @override
  StreamyThrowyChunk parse(Object? json) {
    return StreamyThrowyChunk._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'StreamyThrowyChunk',
    definition: Schema.object(
      properties: {'count': Schema.integer()},
      required: ['count'],
    ),
    dependencies: [],
  );
}
