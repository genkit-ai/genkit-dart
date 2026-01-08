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

extension type HandlerInput(Map<String, dynamic> _json) {
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

class HandlerInputTypeFactory implements JsonExtensionType<HandlerInput> {
  const HandlerInputTypeFactory();

  @override
  HandlerInput parse(Object json) {
    return HandlerInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'message': Schema.string()},
      required: ['message'],
    );
  }
}

// ignore: constant_identifier_names
const HandlerInputType = HandlerInputTypeFactory();

extension type HandlerOutput(Map<String, dynamic> _json) {
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

class HandlerOutputTypeFactory implements JsonExtensionType<HandlerOutput> {
  const HandlerOutputTypeFactory();

  @override
  HandlerOutput parse(Object json) {
    return HandlerOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'processedMessage': Schema.string()},
      required: ['processedMessage'],
    );
  }
}

// ignore: constant_identifier_names
const HandlerOutputType = HandlerOutputTypeFactory();
