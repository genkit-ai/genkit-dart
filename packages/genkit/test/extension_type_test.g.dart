// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'extension_type_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class Ingredient {
  factory Ingredient.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Ingredient._(this._json);

  factory Ingredient({required String name, required String quantity}) {
    return Ingredient._({'name': name, 'quantity': quantity});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Ingredient> $schema = _IngredientTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _IngredientTypeFactory extends SchemanticType<Ingredient> {
  const _IngredientTypeFactory();

  @override
  Ingredient parse(Object? json) {
    return Ingredient._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Ingredient',
    definition: Schema.object(
      properties: {'name': Schema.string(), 'quantity': Schema.string()},
      required: ['name', 'quantity'],
    ),
    dependencies: [],
  );
}

class Recipe {
  factory Recipe.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Recipe._(this._json);

  factory Recipe({
    required String title,
    required List<Ingredient> ingredients,
    required int servings,
  }) {
    return Recipe._({
      'title': title,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'servings': servings,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Recipe> $schema = _RecipeTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  List<Ingredient> get ingredients {
    return (_json['ingredients'] as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _RecipeTypeFactory extends SchemanticType<Recipe> {
  const _RecipeTypeFactory();

  @override
  Recipe parse(Object? json) {
    return Recipe._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Recipe',
    definition: Schema.object(
      properties: {
        'title': Schema.string(),
        'ingredients': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Ingredient'}),
        ),
        'servings': Schema.integer(),
      },
      required: ['title', 'ingredients', 'servings'],
    ),
    dependencies: [Ingredient.$schema],
  );
}

class AnnotatedRecipe {
  factory AnnotatedRecipe.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AnnotatedRecipe._(this._json);

  factory AnnotatedRecipe({
    required String title,
    required List<Ingredient> ingredients,
    required int servings,
  }) {
    return AnnotatedRecipe._({
      'title_key_in_json': title,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'servings': servings,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<AnnotatedRecipe> $schema =
      _AnnotatedRecipeTypeFactory();

  String get title {
    return _json['title_key_in_json'] as String;
  }

  set title(String value) {
    _json['title_key_in_json'] = value;
  }

  List<Ingredient> get ingredients {
    return (_json['ingredients'] as List)
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _AnnotatedRecipeTypeFactory extends SchemanticType<AnnotatedRecipe> {
  const _AnnotatedRecipeTypeFactory();

  @override
  AnnotatedRecipe parse(Object? json) {
    return AnnotatedRecipe._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AnnotatedRecipe',
    definition: Schema.object(
      properties: {
        'title_key_in_json': Schema.string(
          description: 'description set in json schema',
        ),
        'ingredients': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Ingredient'}),
        ),
        'servings': Schema.integer(),
      },
      required: ['title_key_in_json', 'ingredients', 'servings'],
    ),
    dependencies: [Ingredient.$schema],
  );
}

class MealPlan {
  factory MealPlan.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  MealPlan._(this._json);

  factory MealPlan({required String day, required MealType mealType}) {
    return MealPlan._({'day': day, 'mealType': mealType});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<MealPlan> $schema = _MealPlanTypeFactory();

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

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MealPlanTypeFactory extends SchemanticType<MealPlan> {
  const _MealPlanTypeFactory();

  @override
  MealPlan parse(Object? json) {
    return MealPlan._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MealPlan',
    definition: Schema.object(
      properties: {
        'day': Schema.string(),
        'mealType': Schema.string(enumValues: ['breakfast', 'lunch', 'dinner']),
      },
      required: ['day', 'mealType'],
    ),
    dependencies: [],
  );
}

class NullableFields {
  factory NullableFields.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  NullableFields._(this._json);

  factory NullableFields({
    String? optionalString,
    int? optionalInt,
    List<String>? optionalList,
    Ingredient? optionalIngredient,
  }) {
    return NullableFields._({
      if (optionalString != null) 'optionalString': optionalString,
      if (optionalInt != null) 'optionalInt': optionalInt,
      if (optionalList != null) 'optionalList': optionalList,
      if (optionalIngredient != null)
        'optionalIngredient': optionalIngredient.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<NullableFields> $schema =
      _NullableFieldsTypeFactory();

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
        : Ingredient.fromJson(
            _json['optionalIngredient'] as Map<String, dynamic>,
          );
  }

  set optionalIngredient(Ingredient? value) {
    if (value == null) {
      _json.remove('optionalIngredient');
    } else {
      _json['optionalIngredient'] = value;
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

class _NullableFieldsTypeFactory extends SchemanticType<NullableFields> {
  const _NullableFieldsTypeFactory();

  @override
  NullableFields parse(Object? json) {
    return NullableFields._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'NullableFields',
    definition: Schema.object(
      properties: {
        'optionalString': Schema.string(),
        'optionalInt': Schema.integer(),
        'optionalList': Schema.list(items: Schema.string()),
        'optionalIngredient': Schema.fromMap({'\$ref': r'#/$defs/Ingredient'}),
      },
      required: [],
    ),
    dependencies: [Ingredient.$schema],
  );
}

class ComplexObject {
  factory ComplexObject.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ComplexObject._(this._json);

  factory ComplexObject({
    required String id,
    required DateTime createdAt,
    required double price,
    required Map<String, String> metadata,
    required List<int> ratings,
    NullableFields? nestedNullable,
  }) {
    return ComplexObject._({
      'id': id,
      'createdAt': createdAt,
      'price': price,
      'metadata': metadata,
      'ratings': ratings,
      if (nestedNullable != null) 'nestedNullable': nestedNullable.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<ComplexObject> $schema =
      _ComplexObjectTypeFactory();

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
        : NullableFields.fromJson(
            _json['nestedNullable'] as Map<String, dynamic>,
          );
  }

  set nestedNullable(NullableFields? value) {
    if (value == null) {
      _json.remove('nestedNullable');
    } else {
      _json['nestedNullable'] = value;
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

class _ComplexObjectTypeFactory extends SchemanticType<ComplexObject> {
  const _ComplexObjectTypeFactory();

  @override
  ComplexObject parse(Object? json) {
    return ComplexObject._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ComplexObject',
    definition: Schema.object(
      properties: {
        'id': Schema.string(),
        'createdAt': Schema.string(format: 'date-time'),
        'price': Schema.number(),
        'metadata': Schema.object(additionalProperties: Schema.string()),
        'ratings': Schema.list(items: Schema.integer()),
        'nestedNullable': Schema.fromMap({'\$ref': r'#/$defs/NullableFields'}),
      },
      required: ['id', 'createdAt', 'price', 'metadata', 'ratings'],
    ),
    dependencies: [NullableFields.$schema],
  );
}

class Menu {
  factory Menu.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Menu._(this._json);

  factory Menu({
    required List<Recipe> recipes,
    List<Ingredient>? optionalIngredients,
  }) {
    return Menu._({
      'recipes': recipes.map((e) => e.toJson()).toList(),
      if (optionalIngredients != null)
        'optionalIngredients': optionalIngredients
            .map((e) => e.toJson())
            .toList(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Menu> $schema = _MenuTypeFactory();

  List<Recipe> get recipes {
    return (_json['recipes'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set recipes(List<Recipe> value) {
    _json['recipes'] = value.toList();
  }

  List<Ingredient>? get optionalIngredients {
    return (_json['optionalIngredients'] as List?)
        ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set optionalIngredients(List<Ingredient>? value) {
    if (value == null) {
      _json.remove('optionalIngredients');
    } else {
      _json['optionalIngredients'] = value.toList();
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

class _MenuTypeFactory extends SchemanticType<Menu> {
  const _MenuTypeFactory();

  @override
  Menu parse(Object? json) {
    return Menu._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Menu',
    definition: Schema.object(
      properties: {
        'recipes': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Recipe'}),
        ),
        'optionalIngredients': Schema.list(
          items: Schema.fromMap({'\$ref': r'#/$defs/Ingredient'}),
        ),
      },
      required: ['recipes'],
    ),
    dependencies: [Recipe.$schema, Ingredient.$schema],
  );
}
