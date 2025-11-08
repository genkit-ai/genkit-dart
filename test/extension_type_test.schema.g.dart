// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'extension_type_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Ingredient(Map<String, dynamic> _json) {
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
}

class IngredientTypeFactory implements JsonExtensionType<Ingredient> {
  const IngredientTypeFactory();

  @override
  Ingredient parse(Object json) {
    return Ingredient(json as Map<String, dynamic>);
  }

  @override
  Map<String, dynamic> get jsonSchema {
    return {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'quantity': {'type': 'string'},
      },
      'required': ['name', 'quantity'],
    };
  }
}

const IngredientType = IngredientTypeFactory();

extension type Recipe(Map<String, dynamic> _json) {
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
    _json['ingredients'] = value.map((e) => (e as dynamic)._json).toList();
  }

  int get servings {
    return _json['servings'] as int;
  }

  set servings(int value) {
    _json['servings'] = value;
  }
}

class RecipeTypeFactory implements JsonExtensionType<Recipe> {
  const RecipeTypeFactory();

  @override
  Recipe parse(Object json) {
    return Recipe(json as Map<String, dynamic>);
  }

  @override
  Map<String, dynamic> get jsonSchema {
    return {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'ingredients': {'type': 'array', 'items': IngredientType.jsonSchema},
        'servings': {'type': 'integer'},
      },
      'required': ['title', 'ingredients', 'servings'],
    };
  }
}

const RecipeType = RecipeTypeFactory();
