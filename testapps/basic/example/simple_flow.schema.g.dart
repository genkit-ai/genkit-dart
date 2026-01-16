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

part of 'simple_flow.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Ingredient(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
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

class _IngredientTypeFactory extends JsonExtensionType<Ingredient> {
  const _IngredientTypeFactory();

  @override
  Ingredient parse(Object json) {
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

extension type Recipe(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
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

class _RecipeTypeFactory extends JsonExtensionType<Recipe> {
  const _RecipeTypeFactory();

  @override
  Recipe parse(Object json) {
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
