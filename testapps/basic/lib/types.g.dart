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

class ProcessObjectInput implements ProcessObjectInputSchema {
  ProcessObjectInput(this._json);

  factory ProcessObjectInput.from({
    required String message,
    required int count,
  }) {
    return ProcessObjectInput({'message': message, 'count': count});
  }

  Map<String, dynamic> _json;

  @override
  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  @override
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
    return ProcessObjectInput(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const ProcessObjectInputType = _ProcessObjectInputTypeFactory();

class ProcessObjectOutput implements ProcessObjectOutputSchema {
  ProcessObjectOutput(this._json);

  factory ProcessObjectOutput.from({
    required String reply,
    required int newCount,
  }) {
    return ProcessObjectOutput({'reply': reply, 'newCount': newCount});
  }

  Map<String, dynamic> _json;

  @override
  String get reply {
    return _json['reply'] as String;
  }

  set reply(String value) {
    _json['reply'] = value;
  }

  @override
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
    return ProcessObjectOutput(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const ProcessObjectOutputType = _ProcessObjectOutputTypeFactory();

class StreamObjectsInput implements StreamObjectsInputSchema {
  StreamObjectsInput(this._json);

  factory StreamObjectsInput.from({required String prompt}) {
    return StreamObjectsInput({'prompt': prompt});
  }

  Map<String, dynamic> _json;

  @override
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
    return StreamObjectsInput(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const StreamObjectsInputType = _StreamObjectsInputTypeFactory();

class StreamObjectsOutput implements StreamObjectsOutputSchema {
  StreamObjectsOutput(this._json);

  factory StreamObjectsOutput.from({
    required String text,
    required String summary,
  }) {
    return StreamObjectsOutput({'text': text, 'summary': summary});
  }

  Map<String, dynamic> _json;

  @override
  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  @override
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
    return StreamObjectsOutput(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const StreamObjectsOutputType = _StreamObjectsOutputTypeFactory();

class StreamyThrowyChunk implements StreamyThrowyChunkSchema {
  StreamyThrowyChunk(this._json);

  factory StreamyThrowyChunk.from({required int count}) {
    return StreamyThrowyChunk({'count': count});
  }

  Map<String, dynamic> _json;

  @override
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
    return StreamyThrowyChunk(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const StreamyThrowyChunkType = _StreamyThrowyChunkTypeFactory();
