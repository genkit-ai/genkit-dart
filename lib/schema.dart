export 'package:json_schema_builder/json_schema_builder.dart' show Schema;
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class GenkitSchema {
  const GenkitSchema();
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

const StringType = StringTypeFactory();
