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

part of 'simple_flow_types.dart';

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
