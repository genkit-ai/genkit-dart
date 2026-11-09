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

part of 'action_handler_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class HandlerTestOutput {
  /// Creates a [HandlerTestOutput] from a JSON map.
  factory HandlerTestOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  HandlerTestOutput._(this._json);

  HandlerTestOutput({required String greeting}) {
    _json = {'greeting': greeting};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [HandlerTestOutput].
  static const SchemanticType<HandlerTestOutput> $schema =
      _HandlerTestOutputTypeFactory();

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

  /// Serializes this [HandlerTestOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _HandlerTestOutputTypeFactory
    extends SchemanticType<HandlerTestOutput> {
  const _HandlerTestOutputTypeFactory();

  @override
  HandlerTestOutput parse(Object? json) {
    return HandlerTestOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerTestOutput',
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

base class HandlerTestStream {
  /// Creates a [HandlerTestStream] from a JSON map.
  factory HandlerTestStream.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  HandlerTestStream._(this._json);

  HandlerTestStream({required String chunk}) {
    _json = {'chunk': chunk};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [HandlerTestStream].
  static const SchemanticType<HandlerTestStream> $schema =
      _HandlerTestStreamTypeFactory();

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

  /// Serializes this [HandlerTestStream] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _HandlerTestStreamTypeFactory
    extends SchemanticType<HandlerTestStream> {
  const _HandlerTestStreamTypeFactory();

  @override
  HandlerTestStream parse(Object? json) {
    return HandlerTestStream._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerTestStream',
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
