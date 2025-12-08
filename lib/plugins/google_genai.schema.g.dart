// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'google_genai.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type GeminiOptions(Map<String, dynamic> _json) {
  factory GeminiOptions.from({
    required int maxOutputTokens,
    required int temperature,
  }) {
    return GeminiOptions({
      'maxOutputTokens': maxOutputTokens,
      'temperature': temperature,
    });
  }

  int get maxOutputTokens {
    return _json['maxOutputTokens'] as int;
  }

  set maxOutputTokens(int value) {
    _json['maxOutputTokens'] = value;
  }

  int get temperature {
    return _json['temperature'] as int;
  }

  set temperature(int value) {
    _json['temperature'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class GeminiOptionsTypeFactory implements JsonExtensionType<GeminiOptions> {
  const GeminiOptionsTypeFactory();

  @override
  GeminiOptions parse(Object json) {
    return GeminiOptions(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'maxOutputTokens': Schema.integer(),
        'temperature': Schema.integer(),
      },
      required: ['maxOutputTokens', 'temperature'],
    );
  }
}

// ignore: constant_identifier_names
const GeminiOptionsType = GeminiOptionsTypeFactory();
