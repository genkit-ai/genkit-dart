// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'tool_calling_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type WeatherToolInput(Map<String, dynamic> _json) {
  factory WeatherToolInput.from({required String location}) {
    return WeatherToolInput({'location': location});
  }

  String get location {
    return _json['location'] as String;
  }

  set location(String value) {
    _json['location'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class WeatherToolInputTypeFactory
    implements JsonExtensionType<WeatherToolInput> {
  const WeatherToolInputTypeFactory();

  @override
  WeatherToolInput parse(Object json) {
    return WeatherToolInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'location': Schema.string()},
      required: ['location'],
    );
  }
}

// ignore: constant_identifier_names
const WeatherToolInputType = WeatherToolInputTypeFactory();
