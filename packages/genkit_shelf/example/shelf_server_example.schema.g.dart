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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'shelf_server_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class HelloInput implements HelloInputSchema {
  HelloInput(this._json);

  factory HelloInput.from({required String name}) {
    return HelloInput({'name': name});
  }

  Map<String, dynamic> _json;

  @override
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HelloInputTypeFactory extends SchemanticType<HelloInput> {
  const _HelloInputTypeFactory();

  @override
  HelloInput parse(Object? json) {
    return HelloInput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HelloInput',
    definition: Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const HelloInputType = _HelloInputTypeFactory();

class HelloOutput implements HelloOutputSchema {
  HelloOutput(this._json);

  factory HelloOutput.from({required String greeting}) {
    return HelloOutput({'greeting': greeting});
  }

  Map<String, dynamic> _json;

  @override
  String get greeting {
    return _json['greeting'] as String;
  }

  set greeting(String value) {
    _json['greeting'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HelloOutputTypeFactory extends SchemanticType<HelloOutput> {
  const _HelloOutputTypeFactory();

  @override
  HelloOutput parse(Object? json) {
    return HelloOutput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HelloOutput',
    definition: Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const HelloOutputType = _HelloOutputTypeFactory();

class CountChunk implements CountChunkSchema {
  CountChunk(this._json);

  factory CountChunk.from({required int count}) {
    return CountChunk({'count': count});
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

class _CountChunkTypeFactory extends SchemanticType<CountChunk> {
  const _CountChunkTypeFactory();

  @override
  CountChunk parse(Object? json) {
    return CountChunk(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CountChunk',
    definition: Schema.object(
      properties: {'count': Schema.integer()},
      required: ['count'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const CountChunkType = _CountChunkTypeFactory();
