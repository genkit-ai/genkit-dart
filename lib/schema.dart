export 'package:json_schema_builder/json_schema_builder.dart' show Schema;
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class GenkitSchema {
  const GenkitSchema();
}

class Key {
  final String? name;
  final String? description;

  const Key({this.name, this.description});
}

abstract class JsonExtensionType<T> {
  const JsonExtensionType();
  T parse(Object json);
  jsb.Schema get jsonSchema;
}

class StringTypeFactory implements JsonExtensionType<String> {
  const StringTypeFactory();

  @override
  String parse(Object json) => json as String;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.string();
}

// ignore: constant_identifier_names
const StringType = StringTypeFactory();

class IntTypeFactory implements JsonExtensionType<int> {
  const IntTypeFactory();

  @override
  int parse(Object json) => json as int;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.integer();
}

// ignore: constant_identifier_names
const IntType = IntTypeFactory();

class DoubleTypeFactory implements JsonExtensionType<double> {
  const DoubleTypeFactory();

  @override
  double parse(Object json) {
    if (json is int) return json.toDouble();
    return json as double;
  }

  @override
  jsb.Schema get jsonSchema => jsb.Schema.number();
}

// ignore: constant_identifier_names
const DoubleType = DoubleTypeFactory();

class BoolTypeFactory implements JsonExtensionType<bool> {
  const BoolTypeFactory();

  @override
  bool parse(Object json) => json as bool;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.boolean();
}

// ignore: constant_identifier_names
const BoolType = BoolTypeFactory();

class VoidTypeFactory implements JsonExtensionType<void> {
  const VoidTypeFactory();

  @override
  void parse(Object? json) {}

  @override
  jsb.Schema get jsonSchema => jsb.Schema.nil();
}

// ignore: constant_identifier_names
const VoidType = VoidTypeFactory();
