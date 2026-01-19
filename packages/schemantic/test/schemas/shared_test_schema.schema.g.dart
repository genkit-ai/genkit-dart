// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'shared_test_schema.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type SharedChildSchema(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory SharedChildSchema.from({String? childId}) {
    return SharedChildSchema({'childId': childId});
  }

  String? get childId {
    return _json['childId'] as String?;
  }

  set childId(String? value) {
    _json['childId'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SharedChildSchemaTypeFactory extends SchemanticType<SharedChildSchema> {
  const _SharedChildSchemaTypeFactory();

  @override
  SharedChildSchema parse(Object? json) {
    return SharedChildSchema(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SharedChildSchema',
    definition: sharedChildSchema,
    dependencies: [],
  );
}

const sharedChildSchemaType = _SharedChildSchemaTypeFactory();
