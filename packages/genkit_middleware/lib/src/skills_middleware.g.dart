// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class UseSkillInput {
  factory UseSkillInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  UseSkillInput._(this._json);

  UseSkillInput({required String skillName}) {
    _json = {'skillName': skillName};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<UseSkillInput> $schema =
      _UseSkillInputTypeFactory();

  String get skillName {
    return _json['skillName'] as String;
  }

  set skillName(String value) {
    _json['skillName'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _UseSkillInputTypeFactory extends SchemanticType<UseSkillInput> {
  const _UseSkillInputTypeFactory();

  @override
  UseSkillInput parse(Object? json) {
    return UseSkillInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'UseSkillInput',
    definition: Schema.object(
      properties: {
        'skillName': Schema.string(
          description: 'The name of the skill to use.',
        ),
      },
      required: ['skillName'],
    ),
    dependencies: [],
  );
}

class SkillsPluginOptions {
  factory SkillsPluginOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SkillsPluginOptions._(this._json);

  SkillsPluginOptions({List<String>? skillPaths}) {
    _json = {'skillPaths': ?skillPaths};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<SkillsPluginOptions> $schema =
      _SkillsPluginOptionsTypeFactory();

  List<String>? get skillPaths {
    return (_json['skillPaths'] as List?)?.cast<String>();
  }

  set skillPaths(List<String>? value) {
    if (value == null) {
      _json.remove('skillPaths');
    } else {
      _json['skillPaths'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _SkillsPluginOptionsTypeFactory
    extends SchemanticType<SkillsPluginOptions> {
  const _SkillsPluginOptionsTypeFactory();

  @override
  SkillsPluginOptions parse(Object? json) {
    return SkillsPluginOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SkillsPluginOptions',
    definition: Schema.object(
      properties: {
        'skillPaths': Schema.list(
          description:
              'The directories containing skill files. Defaults to ["skills"].',
          items: Schema.string(),
        ),
      },
      required: [],
    ),
    dependencies: [],
  );
}
