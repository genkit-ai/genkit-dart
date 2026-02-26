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

part of 'shelf_handler_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class HandlerInput {
  factory HandlerInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  HandlerInput._(this._json);

  HandlerInput({required String message}) {
    _json = {'message': message};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<HandlerInput> $schema =
      _HandlerInputTypeFactory();

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HandlerInputTypeFactory extends SchemanticType<HandlerInput> {
  const _HandlerInputTypeFactory();

  @override
  HandlerInput parse(Object? json) {
    return HandlerInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerInput',
    definition: $Schema
        .object(
          properties: {'message': $Schema.string()},
          required: ['message'],
        )
        .value,
    dependencies: [],
  );
}

class HandlerOutput {
  factory HandlerOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  HandlerOutput._(this._json);

  HandlerOutput({required String processedMessage}) {
    _json = {'processedMessage': processedMessage};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<HandlerOutput> $schema =
      _HandlerOutputTypeFactory();

  String get processedMessage {
    return _json['processedMessage'] as String;
  }

  set processedMessage(String value) {
    _json['processedMessage'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HandlerOutputTypeFactory extends SchemanticType<HandlerOutput> {
  const _HandlerOutputTypeFactory();

  @override
  HandlerOutput parse(Object? json) {
    return HandlerOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerOutput',
    definition: $Schema
        .object(
          properties: {'processedMessage': $Schema.string()},
          required: ['processedMessage'],
        )
        .value,
    dependencies: [],
  );
}
