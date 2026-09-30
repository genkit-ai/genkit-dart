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

base class ShelfTestOutput {
  /// Creates a [ShelfTestOutput] from a JSON map.
  factory ShelfTestOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ShelfTestOutput._(this._json);

  ShelfTestOutput({required String greeting}) {
    _json = {'greeting': greeting};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ShelfTestOutput].
  static const SchemanticType<ShelfTestOutput> $schema =
      _ShelfTestOutputTypeFactory();

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

  /// Serializes this [ShelfTestOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ShelfTestOutputTypeFactory extends SchemanticType<ShelfTestOutput> {
  const _ShelfTestOutputTypeFactory();

  @override
  ShelfTestOutput parse(Object? json) {
    return ShelfTestOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ShelfTestOutput',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'greeting': <String, Object?>{'type': 'string'},
      },
      'required': ['greeting'],
    },
    dependencies: [],
  );
}

base class ShelfTestStream {
  /// Creates a [ShelfTestStream] from a JSON map.
  factory ShelfTestStream.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ShelfTestStream._(this._json);

  ShelfTestStream({required String chunk}) {
    _json = {'chunk': chunk};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [ShelfTestStream].
  static const SchemanticType<ShelfTestStream> $schema =
      _ShelfTestStreamTypeFactory();

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

  /// Serializes this [ShelfTestStream] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ShelfTestStreamTypeFactory extends SchemanticType<ShelfTestStream> {
  const _ShelfTestStreamTypeFactory();

  @override
  ShelfTestStream parse(Object? json) {
    return ShelfTestStream._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ShelfTestStream',
    definition: <String, Object?>{
      'type': 'object',
      'properties': <String, Object?>{
        'chunk': <String, Object?>{'type': 'string'},
      },
      'required': ['chunk'],
    },
    dependencies: [],
  );
}
