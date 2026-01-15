import 'package:genkit_schema_builder/genkit_schema_builder.dart';

Map<String, dynamic> toJsonSchema({
  JsonExtensionType? type,
  Map<String, dynamic>? jsonSchema,
}) {
  var result = Schema.any().value;
  if (jsonSchema != null) {
    result = jsonSchema;
  }

  if (type != null) {
    result = type.jsonSchema(useRefs: true).value;
  }

  result['\$schema'] = 'http://json-schema.org/draft-07/schema#';

  return result;
}
