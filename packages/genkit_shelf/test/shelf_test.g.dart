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

part of 'shelf_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ShelfTestOutput implements ShelfTestOutputSchema {
  ShelfTestOutput(this._json);

  factory ShelfTestOutput.from({required String greeting}) {
    return ShelfTestOutput({'greeting': greeting});
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

class _ShelfTestOutputTypeFactory extends SchemanticType<ShelfTestOutput> {
  const _ShelfTestOutputTypeFactory();

  @override
  ShelfTestOutput parse(Object? json) {
    return ShelfTestOutput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ShelfTestOutput',
    definition: Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const ShelfTestOutputType = _ShelfTestOutputTypeFactory();

class ShelfTestStream implements ShelfTestStreamSchema {
  ShelfTestStream(this._json);

  factory ShelfTestStream.from({required String chunk}) {
    return ShelfTestStream({'chunk': chunk});
  }

  Map<String, dynamic> _json;

  @override
  String get chunk {
    return _json['chunk'] as String;
  }

  set chunk(String value) {
    _json['chunk'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ShelfTestStreamTypeFactory extends SchemanticType<ShelfTestStream> {
  const _ShelfTestStreamTypeFactory();

  @override
  ShelfTestStream parse(Object? json) {
    return ShelfTestStream(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ShelfTestStream',
    definition: Schema.object(
      properties: {'chunk': Schema.string()},
      required: ['chunk'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const ShelfTestStreamType = _ShelfTestStreamTypeFactory();
