// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'genkit_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type TestCustomOptions(Map<String, dynamic> _json) {
  factory TestCustomOptions.from({required String customField}) {
    return TestCustomOptions({'customField': customField});
  }

  String get customField {
    return _json['customField'] as String;
  }

  set customField(String value) {
    _json['customField'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class TestCustomOptionsTypeFactory
    implements JsonExtensionType<TestCustomOptions> {
  const TestCustomOptionsTypeFactory();

  @override
  TestCustomOptions parse(Object json) {
    return TestCustomOptions(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'customField': Schema.string()},
      required: ['customField'],
    );
  }
}

const TestCustomOptionsType = TestCustomOptionsTypeFactory();
