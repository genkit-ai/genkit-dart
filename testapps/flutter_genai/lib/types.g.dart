// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class ServerFlowInput {
  factory ServerFlowInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ServerFlowInput._(this._json);

  ServerFlowInput({required String provider, required String prompt}) {
    _json = {'provider': provider, 'prompt': prompt};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ServerFlowInput> $schema =
      _ServerFlowInputTypeFactory();

  String get provider {
    return _json['provider'] as String;
  }

  set provider(String value) {
    _json['provider'] = value;
  }

  String get prompt {
    return _json['prompt'] as String;
  }

  set prompt(String value) {
    _json['prompt'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ServerFlowInputTypeFactory extends SchemanticType<ServerFlowInput> {
  const _ServerFlowInputTypeFactory();

  @override
  ServerFlowInput parse(Object? json) {
    return ServerFlowInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
        name: 'ServerFlowInput',
        definition: $Schema.object(
          properties: {
            'provider': $Schema.string(),
            'prompt': $Schema.string(),
          },
          required: ['provider', 'prompt'],
        ).value,
        dependencies: [],
      );
}
