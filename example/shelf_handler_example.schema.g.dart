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
