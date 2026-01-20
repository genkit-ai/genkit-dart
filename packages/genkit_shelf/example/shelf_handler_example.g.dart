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

extension type HandlerInput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory HandlerInput.from({required String message}) {
    return HandlerInput({'message': message});
  }

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HandlerInputTypeFactory extends SchemanticType<HandlerInput> {
  const _HandlerInputTypeFactory();

  @override
  HandlerInput parse(Object? json) {
    return HandlerInput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerInput',
    definition: Schema.object(
      properties: {'message': Schema.string()},
      required: ['message'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const HandlerInputType = _HandlerInputTypeFactory();

extension type HandlerOutput(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory HandlerOutput.from({required String processedMessage}) {
    return HandlerOutput({'processedMessage': processedMessage});
  }

  String get processedMessage {
    return _json['processedMessage'] as String;
  }

  set processedMessage(String value) {
    _json['processedMessage'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _HandlerOutputTypeFactory extends SchemanticType<HandlerOutput> {
  const _HandlerOutputTypeFactory();

  @override
  HandlerOutput parse(Object? json) {
    return HandlerOutput(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'HandlerOutput',
    definition: Schema.object(
      properties: {'processedMessage': Schema.string()},
      required: ['processedMessage'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const HandlerOutputType = _HandlerOutputTypeFactory();
