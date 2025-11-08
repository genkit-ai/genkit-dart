class Schema {
  const Schema();
}

abstract class JsonExtensionType<T> {
  const JsonExtensionType();
  T parse(Object json);
  Map<String, dynamic> get jsonSchema;
}

class StringTypeFactory implements JsonExtensionType<String> {
  const StringTypeFactory();

  @override
  String parse(Object json) => json as String;

  @override
  Map<String, dynamic> get jsonSchema => {
        'type': 'string',
      };
}

const StringType = StringTypeFactory();
