// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'generate_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type TestToolInput(Map<String, dynamic> _json) {
  factory TestToolInput.from({required String name}) {
    return TestToolInput({'name': name});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class TestToolInputTypeFactory implements JsonExtensionType<TestToolInput> {
  const TestToolInputTypeFactory();

  @override
  TestToolInput parse(Object json) {
    return TestToolInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
    );
  }
}

// ignore: constant_identifier_names
const TestToolInputType = TestToolInputTypeFactory();
