// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'generate_bidi_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type MyToolInput(Map<String, dynamic> _json) {
  factory MyToolInput.from({required String location}) {
    return MyToolInput({'location': location});
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

class MyToolInputTypeFactory implements JsonExtensionType<MyToolInput> {
  const MyToolInputTypeFactory();

  @override
  MyToolInput parse(Object json) {
    return MyToolInput(json as Map<String, dynamic>);
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
const MyToolInputType = MyToolInputTypeFactory();
