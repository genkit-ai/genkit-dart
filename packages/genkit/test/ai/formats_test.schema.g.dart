// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'formats_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type TestObject(Map<String, dynamic> _json) {
  factory TestObject.from({required String foo, required int bar}) {
    return TestObject({'foo': foo, 'bar': bar});
  }

  String get foo {
    return _json['foo'] as String;
  }

  set foo(String value) {
    _json['foo'] = value;
  }

  int get bar {
    return _json['bar'] as int;
  }

  set bar(int value) {
    _json['bar'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class TestObjectTypeFactory implements JsonExtensionType<TestObject> {
  const TestObjectTypeFactory();

  @override
  TestObject parse(Object json) {
    return TestObject(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'foo': Schema.string(), 'bar': Schema.integer()},
      required: ['foo', 'bar'],
    );
  }
}

// ignore: constant_identifier_names
const TestObjectType = TestObjectTypeFactory();
