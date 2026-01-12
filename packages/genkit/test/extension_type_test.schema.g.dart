// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'extension_type_test.dart';

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

extension type AnnotatedRecipe(Map<String, dynamic> _json) {
  factory AnnotatedRecipe.from({
    required String title,
    required List<Ingredient> ingredients,
    required int servings,
  }) {
    return AnnotatedRecipe({
      'title_key_in_json': title,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'servings': servings,
    });
  }

  String get title {
    return _json['title_key_in_json'] as String;
  }

  set title(String value) {
    _json['title_key_in_json'] = value;
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

class AnnotatedRecipeTypeFactory implements JsonExtensionType<AnnotatedRecipe> {
  const AnnotatedRecipeTypeFactory();

  @override
  AnnotatedRecipe parse(Object json) {
    return AnnotatedRecipe(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'title_key_in_json': Schema.string(
          description: 'description set in json schema',
        ),
        'ingredients': Schema.list(items: IngredientType.jsonSchema),
        'servings': Schema.integer(),
      },
      required: ['title_key_in_json', 'ingredients', 'servings'],
    );
  }
}

// ignore: constant_identifier_names
const AnnotatedRecipeType = AnnotatedRecipeTypeFactory();

extension type MealPlan(Map<String, dynamic> _json) {
  factory MealPlan.from({required String day, required MealType mealType}) {
    return MealPlan({'day': day, 'mealType': mealType});
  }

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

  Map<String, dynamic> toJson() {
    return _json;
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

// ignore: constant_identifier_names
const MealPlanType = MealPlanTypeFactory();

extension type NullableFields(Map<String, dynamic> _json) {
  factory NullableFields.from({
    String? optionalString,
    int? optionalInt,
    List<String>? optionalList,
    Ingredient? optionalIngredient,
  }) {
    return NullableFields({
      if (optionalString != null) 'optionalString': optionalString,
      if (optionalInt != null) 'optionalInt': optionalInt,
      if (optionalList != null) 'optionalList': optionalList,
      if (optionalIngredient != null)
        'optionalIngredient': optionalIngredient?.toJson(),
    });
  }

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
      _json['optionalIngredient'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
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

// ignore: constant_identifier_names
const NullableFieldsType = NullableFieldsTypeFactory();

extension type ComplexObject(Map<String, dynamic> _json) {
  factory ComplexObject.from({
    required String id,
    required DateTime createdAt,
    required double price,
    required Map<String, String> metadata,
    required List<int> ratings,
    NullableFields? nestedNullable,
  }) {
    return ComplexObject({
      'id': id,
      'createdAt': createdAt,
      'price': price,
      'metadata': metadata,
      'ratings': ratings,
      if (nestedNullable != null) 'nestedNullable': nestedNullable?.toJson(),
    });
  }

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  DateTime get createdAt {
    return DateTime.parse(_json['createdAt'] as String);
  }

  set createdAt(DateTime value) {
    _json['createdAt'] = value.toIso8601String();
  }

  double get price {
    return _json['price'] as double;
  }

  set price(double value) {
    _json['price'] = value;
  }

  Map<String, String> get metadata {
    return _json['metadata'] as Map<String, String>;
  }

  set metadata(Map<String, String> value) {
    _json['metadata'] = value;
  }

  List<int> get ratings {
    return (_json['ratings'] as List).cast<int>();
  }

  set ratings(List<int> value) {
    _json['ratings'] = value;
  }

  NullableFields? get nestedNullable {
    return _json['nestedNullable'] == null
        ? null
        : NullableFields(_json['nestedNullable'] as Map<String, dynamic>);
  }

  set nestedNullable(NullableFields? value) {
    if (value == null) {
      _json.remove('nestedNullable');
    } else {
      _json['nestedNullable'] = value;
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ComplexObjectTypeFactory implements JsonExtensionType<ComplexObject> {
  const ComplexObjectTypeFactory();

  @override
  ComplexObject parse(Object json) {
    return ComplexObject(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'id': Schema.string(),
        'createdAt': Schema.string(format: 'date-time'),
        'price': Schema.number(),
        'metadata': Schema.object(additionalProperties: Schema.string()),
        'ratings': Schema.list(items: Schema.integer()),
        'nestedNullable': NullableFieldsType.jsonSchema,
      },
      required: ['id', 'createdAt', 'price', 'metadata', 'ratings'],
    );
  }
}

// ignore: constant_identifier_names
const ComplexObjectType = ComplexObjectTypeFactory();

extension type Menu(Map<String, dynamic> _json) {
  factory Menu.from({
    required List<Recipe> recipes,
    List<Ingredient>? optionalIngredients,
  }) {
    return Menu({
      'recipes': recipes.map((e) => e.toJson()).toList(),
      if (optionalIngredients != null)
        'optionalIngredients': optionalIngredients
            .map((e) => e.toJson())
            .toList(),
    });
  }

  List<Recipe> get recipes {
    return (_json['recipes'] as List)
        .map((e) => Recipe(e as Map<String, dynamic>))
        .toList();
  }

  set recipes(List<Recipe> value) {
    _json['recipes'] = value.toList();
  }

  List<Ingredient>? get optionalIngredients {
    return (_json['optionalIngredients'] as List?)
        ?.map((e) => Ingredient(e as Map<String, dynamic>))
        .toList();
  }

  set optionalIngredients(List<Ingredient>? value) {
    if (value == null) {
      _json.remove('optionalIngredients');
    } else {
      _json['optionalIngredients'] = value.toList();
    }
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class MenuTypeFactory implements JsonExtensionType<Menu> {
  const MenuTypeFactory();

  @override
  Menu parse(Object json) {
    return Menu(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {
        'recipes': Schema.list(items: RecipeType.jsonSchema),
        'optionalIngredients': Schema.list(items: IngredientType.jsonSchema),
      },
      required: ['recipes'],
    );
  }
}

// ignore: constant_identifier_names
const MenuType = MenuTypeFactory();
