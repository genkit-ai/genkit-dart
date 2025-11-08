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
  Schema get jsonSchema {
    return Schema.object(
      properties: {'name': Schema.string(), 'quantity': Schema.string()},
      required: ['name', 'quantity'],
    );
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

const RecipeType = RecipeTypeFactory();

extension type MealPlan(Map<String, dynamic> _json) {
  String get day {
    return _json['day'] as String;
  }

  set day(String value) {
    _json['day'] = value;
  }

  MealType get mealType {
    return MealType.values.byName(_json['mealType'] as String);
  }

  set mealType(MealType value) {
    _json['mealType'] = value.name;
  }
}

class MealPlanTypeFactory implements JsonExtensionType<MealPlan> {
  const MealPlanTypeFactory();

  @override
  MealPlan parse(Object json) {
    return MealPlan(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'day': Schema.string(),
        'mealType': Schema.string(enumValues: ['breakfast', 'lunch', 'dinner']),
      },
      required: ['day', 'mealType'],
    );
  }
}

const MealPlanType = MealPlanTypeFactory();

extension type NullableFields(Map<String, dynamic> _json) {
  String? get optionalString {
    return _json['optionalString'] as String?;
  }

  set optionalString(String? value) {
    if (value == null) {
      _json.remove('optionalString');
    } else {
      _json['optionalString'] = value;
    }
  }

  int? get optionalInt {
    return _json['optionalInt'] as int?;
  }

  set optionalInt(int? value) {
    if (value == null) {
      _json.remove('optionalInt');
    } else {
      _json['optionalInt'] = value;
    }
  }

  List<String>? get optionalList {
    return (_json['optionalList'] as List?)?.cast<String>();
  }

  set optionalList(List<String>? value) {
    if (value == null) {
      _json.remove('optionalList');
    } else {
      _json['optionalList'] = value;
    }
  }

  Ingredient? get optionalIngredient {
    return _json['optionalIngredient'] == null
        ? null
        : Ingredient(_json['optionalIngredient'] as Map<String, dynamic>);
  }

  set optionalIngredient(Ingredient? value) {
    if (value == null) {
      _json.remove('optionalIngredient');
    } else {
      _json['optionalIngredient'] = (value as dynamic)?._json;
    }
  }
}

class NullableFieldsTypeFactory implements JsonExtensionType<NullableFields> {
  const NullableFieldsTypeFactory();

  @override
  NullableFields parse(Object json) {
    return NullableFields(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'optionalString': Schema.string(),
        'optionalInt': Schema.integer(),
        'optionalList': Schema.list(items: Schema.string()),
        'optionalIngredient': IngredientType.jsonSchema,
      },
      required: [],
    );
  }
}

const NullableFieldsType = NullableFieldsTypeFactory();
