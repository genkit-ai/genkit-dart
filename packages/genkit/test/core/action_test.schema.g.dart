// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'action_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type TestInput(Map<String, dynamic> _json) {
  factory TestInput.from({required String name}) {
    return TestInput({'name': name});
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

class TestInputTypeFactory implements JsonExtensionType<TestInput> {
  const TestInputTypeFactory();

  @override
  TestInput parse(Object json) {
    return TestInput(json as Map<String, dynamic>);
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
const TestInputType = TestInputTypeFactory();

extension type TestOutput(Map<String, dynamic> _json) {
  factory TestOutput.from({required String greeting}) {
    return TestOutput({'greeting': greeting});
  }

  String get greeting {
    return _json['greeting'] as String;
  }

  set greeting(String value) {
    _json['greeting'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class TestOutputTypeFactory implements JsonExtensionType<TestOutput> {
  const TestOutputTypeFactory();

  @override
  TestOutput parse(Object json) {
    return TestOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    );
  }
}

// ignore: constant_identifier_names
const TestOutputType = TestOutputTypeFactory();
