// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GreetInput {
  factory GreetInput.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  GreetInput._(this._json);

  GreetInput({required String name}) {
    _json = {'name': name};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<GreetInput> $schema = _GreetInputTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GreetInputTypeFactory extends SchemanticType<GreetInput> {
  const _GreetInputTypeFactory();

  @override
  GreetInput parse(Object? json) {
    return GreetInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GreetInput',
    definition: $Schema
        .object(properties: {'name': $Schema.string()}, required: ['name'])
        .value,
    dependencies: [],
  );
}

base class PromptInput {
  factory PromptInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PromptInput._(this._json);

  PromptInput({required String input}) {
    _json = {'input': input};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<PromptInput> $schema = _PromptInputTypeFactory();

  String get input {
    return _json['input'] as String;
  }

  set input(String value) {
    _json['input'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _PromptInputTypeFactory extends SchemanticType<PromptInput> {
  const _PromptInputTypeFactory();

  @override
  PromptInput parse(Object? json) {
    return PromptInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PromptInput',
    definition: $Schema
        .object(properties: {'input': $Schema.string()}, required: ['input'])
        .value,
    dependencies: [],
  );
}
