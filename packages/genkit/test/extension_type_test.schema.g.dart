// dart format width=80
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

// GENERATED CODE BY schemantic - DO NOT MODIFY BY HAND
// To regenerate, run `dart run build_runner build -d`

part of 'extension_type_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class Ingredient implements IngredientSchema {
  Ingredient(this._json);

  factory Ingredient.from({required String name, required String quantity}) {
    return Ingredient({'name': name, 'quantity': quantity});
  }

  Map<String, dynamic> _json;

  @override
  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  @override
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
    return Ingredient(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const IngredientType = _IngredientTypeFactory();

class Recipe implements RecipeSchema {
  Recipe(this._json);

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

  Map<String, dynamic> _json;

  @override
  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  @override
  List<Ingredient> get ingredients {
    return (_json['ingredients'] as List)
        .map((e) => Ingredient(e as Map<String, dynamic>))
        .toList();
  }

  set ingredients(List<Ingredient> value) {
    _json['ingredients'] = value.toList();
  }

  @override
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
    return Recipe(json as Map<String, dynamic>);
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
    dependencies: [IngredientType],
  );
}

// ignore: constant_identifier_names
const RecipeType = _RecipeTypeFactory();

class AnnotatedRecipe implements AnnotatedRecipeSchema {
  AnnotatedRecipe(this._json);

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

  Map<String, dynamic> _json;

  @override
  String get title {
    return _json['title_key_in_json'] as String;
  }

  set title(String value) {
    _json['title_key_in_json'] = value;
  }

  @override
  List<Ingredient> get ingredients {
    return (_json['ingredients'] as List)
        .map((e) => Ingredient(e as Map<String, dynamic>))
        .toList();
  }

  set ingredients(List<Ingredient> value) {
    _json['ingredients'] = value.toList();
  }

  @override
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
    return AnnotatedRecipe(json as Map<String, dynamic>);
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
    dependencies: [IngredientType],
  );
}

// ignore: constant_identifier_names
const AnnotatedRecipeType = _AnnotatedRecipeTypeFactory();

class MealPlan implements MealPlanSchema {
  MealPlan(this._json);

  factory MealPlan.from({required String day, required MealType mealType}) {
    return MealPlan({'day': day, 'mealType': mealType});
  }

  Map<String, dynamic> _json;

  @override
  String get day {
    return _json['day'] as String;
  }

  set day(String value) {
    _json['day'] = value;
  }

  @override
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
    return MealPlan(json as Map<String, dynamic>);
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

// ignore: constant_identifier_names
const MealPlanType = _MealPlanTypeFactory();

class NullableFields implements NullableFieldsSchema {
  NullableFields(this._json);

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
        'optionalIngredient': optionalIngredient.toJson(),
    });
  }

  Map<String, dynamic> _json;

  @override
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

  @override
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

  @override
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

  @override
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
    return NullableFields(json as Map<String, dynamic>);
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
    dependencies: [IngredientType],
  );
}

// ignore: constant_identifier_names
const NullableFieldsType = _NullableFieldsTypeFactory();

class ComplexObject implements ComplexObjectSchema {
  ComplexObject(this._json);

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
      if (nestedNullable != null) 'nestedNullable': nestedNullable.toJson(),
    });
  }

  Map<String, dynamic> _json;

  @override
  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  @override
  DateTime get createdAt {
    return DateTime.parse(_json['createdAt'] as String);
  }

  set createdAt(DateTime value) {
    _json['createdAt'] = value.toIso8601String();
  }

  @override
  double get price {
    return _json['price'] as double;
  }

  set price(double value) {
    _json['price'] = value;
  }

  @override
  Map<String, String> get metadata {
    return _json['metadata'] as Map<String, String>;
  }

  set metadata(Map<String, String> value) {
    _json['metadata'] = value;
  }

  @override
  List<int> get ratings {
    return (_json['ratings'] as List).cast<int>();
  }

  set ratings(List<int> value) {
    _json['ratings'] = value;
  }

  @override
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
    return ComplexObject(json as Map<String, dynamic>);
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
    dependencies: [NullableFieldsType],
  );
}

// ignore: constant_identifier_names
const ComplexObjectType = _ComplexObjectTypeFactory();

class Menu implements MenuSchema {
  Menu(this._json);

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

  Map<String, dynamic> _json;

  @override
  List<Recipe> get recipes {
    return (_json['recipes'] as List)
        .map((e) => Recipe(e as Map<String, dynamic>))
        .toList();
  }

  set recipes(List<Recipe> value) {
    _json['recipes'] = value.toList();
  }

  @override
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
    return Menu(json as Map<String, dynamic>);
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
    dependencies: [RecipeType, IngredientType],
  );
}

// ignore: constant_identifier_names
const MenuType = _MenuTypeFactory();
