// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'simple_flow.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Ingredient(Map<String, dynamic> _json) {
  factory Ingredient.from({required String name, required String quantity}) {
    return Ingredient({'name': name, 'quantity': quantity});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get quantity {
    return _json['quantity'] as String;
  }

  set quantity(String value) {
    _json['quantity'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class IngredientTypeFactory implements JsonExtensionType<Ingredient> {
  const IngredientTypeFactory();

  @override
  Ingredient parse(Object json) {
    return Ingredient(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'name': Schema.string(), 'quantity': Schema.string()},
      required: ['name', 'quantity'],
    );
  }
}

// ignore: constant_identifier_names
const IngredientType = IngredientTypeFactory();

extension type Recipe(Map<String, dynamic> _json) {
  factory Recipe.from({
    required String title,
    required List<Ingredient> ingredients,
    required int servings,
  }) {
    return Recipe({
      'title': title,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'servings': servings,
    });
  }

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  List<Ingredient> get ingredients {
    return (_json['ingredients'] as List)
        .map((e) => Ingredient(e as Map<String, dynamic>))
        .toList();
  }

  set ingredients(List<Ingredient> value) {
    _json['ingredients'] = value.toList();
  }

  int get servings {
    return _json['servings'] as int;
  }

  set servings(int value) {
    _json['servings'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class RecipeTypeFactory implements JsonExtensionType<Recipe> {
  const RecipeTypeFactory();

  @override
  Recipe parse(Object json) {
    return Recipe(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'title': Schema.string(),
        'ingredients': Schema.list(items: IngredientType.jsonSchema),
        'servings': Schema.integer(),
      },
      required: ['title', 'ingredients', 'servings'],
    );
  }
}

// ignore: constant_identifier_names
const RecipeType = RecipeTypeFactory();
