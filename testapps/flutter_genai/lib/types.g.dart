// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class RecipeRequest {
  factory RecipeRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RecipeRequest._(this._json);

  RecipeRequest({
    required String provider,
    required String dietFriendly,
    required String mainIngredient,
  }) {
    _json = {
      'provider': provider,
      'dietFriendly': dietFriendly,
      'mainIngredient': mainIngredient,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<RecipeRequest> $schema =
      _RecipeRequestTypeFactory();

  String get provider {
    return _json['provider'] as String;
  }

  set provider(String value) {
    _json['provider'] = value;
  }

  String get dietFriendly {
    return _json['dietFriendly'] as String;
  }

  set dietFriendly(String value) {
    _json['dietFriendly'] = value;
  }

  String get mainIngredient {
    return _json['mainIngredient'] as String;
  }

  set mainIngredient(String value) {
    _json['mainIngredient'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RecipeRequestTypeFactory extends SchemanticType<RecipeRequest> {
  const _RecipeRequestTypeFactory();

  @override
  RecipeRequest parse(Object? json) {
    return RecipeRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RecipeRequest',
    definition: $Schema
        .object(
          properties: {
            'provider': $Schema.string(),
            'dietFriendly': $Schema.string(),
            'mainIngredient': $Schema.string(),
          },
          required: ['provider', 'dietFriendly', 'mainIngredient'],
        )
        .value,
    dependencies: [],
  );
}

base class CheckPantryInput {
  factory CheckPantryInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  CheckPantryInput._(this._json);

  CheckPantryInput({required String spice}) {
    _json = {'spice': spice};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<CheckPantryInput> $schema =
      _CheckPantryInputTypeFactory();

  String get spice {
    return _json['spice'] as String;
  }

  set spice(String value) {
    _json['spice'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CheckPantryInputTypeFactory
    extends SchemanticType<CheckPantryInput> {
  const _CheckPantryInputTypeFactory();

  @override
  CheckPantryInput parse(Object? json) {
    return CheckPantryInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'CheckPantryInput',
    definition: $Schema
        .object(properties: {'spice': $Schema.string()}, required: ['spice'])
        .value,
    dependencies: [],
  );
}
