part of 'ext.dart';

class Schema {
  const Schema();
}

class JsonExtensionType<T>{

}

// **************************************************************************
// SchemaGenerator
// **************************************************************************

/// A wrapper around a [Map] that provides type-safe access to its keys.
extension type Ingredient(Map<String, dynamic> _json) {
  String get name => _json['name'] as String;
  set name(String value) => _json['name'] = value;

  String get quantity => _json['quantity'] as String;
  set quantity(String value) => _json['quantity'] = value;
}

/// A factory for creating [Ingredient] instances.
class IngredientTypeFactory implements JsonExtensionType<Ingredient> {
  /// Creates a new [IngredientTypeFactory] instance.
  const IngredientTypeFactory();

  /// Parses a [Map] into an [Ingredient] instance.
  Ingredient parse(Map<String, dynamic> json) => Ingredient(json);

  /// The JSON schema for an [Ingredient] instance.
  Map<String, dynamic> get jsonSchema => {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'quantity': {'type': 'string'},
        },
        'required': ['name', 'quantity'],
      };
}

/// The singleton instance of [IngredientTypeFactory].
const IngredientType = IngredientTypeFactory();

/// A wrapper around a [Map] that provides type-safe access to its keys.
extension type Recipe(Map<String, dynamic> _json) {
  String get title => _json['title'] as String;
  set title(String value) => _json['title'] = value;

  List<Ingredient> get ingredients =>
      (_json['ingredients'] as List).map((e) => Ingredient(e)).toList();
  set ingredients(List<Ingredient> value) =>
      _json['ingredients'] = value.map((e) => e._json).toList();

  List<String> get instructions => (_json['instructions'] as List).cast<String>();
  set instructions(List<String> value) => _json['instructions'] = value;

  int get servings => _json['servings'] as int;
  set servings(int value) => _json['servings'] = value;
}

/// A factory for creating [Recipe] instances.
class RecipeTypeFactory implements JsonExtensionType<Recipe> {
  /// Creates a new [RecipeTypeFactory] instance.
  const RecipeTypeFactory();

  /// Parses a [Map] into a [Recipe] instance.
  Recipe parse(Map<String, dynamic> json) => Recipe(json);

  /// The JSON schema for a [Recipe] instance.
  Map<String, dynamic> get jsonSchema => {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'ingredients': {
            'type': 'array',
            'items': IngredientType.jsonSchema,
          },
          'instructions': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'servings': {'type': 'integer'},
        },
        'required': ['title', 'ingredients', 'instructions', 'servings'],
      };
}

/// The singleton instance of [RecipeTypeFactory].
const RecipeType = RecipeTypeFactory();


class StringTypeFactory implements JsonExtensionType<String> {
  /// Creates a new [StringTypeFactory] instance.
  const StringTypeFactory();

  /// Parses a [Map] into a [String] instance.
  String parse(String json) => json;

  /// The JSON schema for a [String] instance.
  Map<String, dynamic> get jsonSchema => {
        'type': 'string',
      };
}

const StringType = StringTypeFactory();
