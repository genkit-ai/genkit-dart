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

import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'extension_type_test.g.dart';

@Schematic()
abstract class $Ingredient {
  String get name;
  String get quantity;
}

@Schematic()
abstract class $Recipe {
  String get title;
  List<$Ingredient> get ingredients;
  int get servings;
}

@Schematic()
abstract class $AnnotatedRecipe {
  @Field(
    name: 'title_key_in_json',
    description: 'description set in json schema',
  )
  String get title;
  List<$Ingredient> get ingredients;
  int get servings;
}

enum MealType { breakfast, lunch, dinner }

@Schematic()
abstract class $MealPlan {
  String get day;
  MealType get mealType;
}

@Schematic()
abstract class $NullableFields {
  String? get optionalString;
  int? get optionalInt;
  List<String>? get optionalList;
  $Ingredient? get optionalIngredient;
}

@Schematic()
abstract class $ComplexObject {
  String get id;
  DateTime get createdAt;
  double get price;
  Map<String, String> get metadata;
  List<int> get ratings;
  $NullableFields? get nestedNullable;
}

@Schematic()
abstract class $Menu {
  List<$Recipe> get recipes;
  List<$Ingredient>? get optionalIngredients;
}

void main() {
  group('Extension Type Generation', () {
    test('Parses and accesses data correctly', () {
      final recipeJson = {
        "title": "Pancakes",
        "ingredients": [
          {"name": "Flour", "quantity": "1 cup"},
          {"name": "Milk", "quantity": "1 cup"},
        ],
        "servings": 4,
      };

      final recipe = Recipe.$schema.parse(recipeJson);

      expect(recipe.title, "Pancakes");
      expect(recipe.servings, 4);
      expect(recipe.ingredients.length, 2);
      expect(recipe.ingredients[0].name, "Flour");
      expect(recipe.ingredients[0].quantity, "1 cup");

      // Modify and verify
      recipe.title = "Fluffy Pancakes";
      expect(recipe.title, "Fluffy Pancakes");
    });

    test('Generates correct JSON schema', () {
      final expectedSchema = Schema.object(
        properties: {
          'title': Schema.string(),
          'ingredients': Schema.list(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'quantity': Schema.string(),
              },
              required: ['name', 'quantity'],
            ),
          ),
          'servings': Schema.integer(),
        },
        required: ['title', 'ingredients', 'servings'],
      );

      expect(Recipe.$schema.jsonSchema().toJson(), expectedSchema.toJson());
    });

    test('Generates correct JSON schema for annotated fields', () {
      final expectedSchema = Schema.object(
        properties: {
          'title_key_in_json': Schema.string(
            description: 'description set in json schema',
          ),
          'ingredients': Schema.list(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'quantity': Schema.string(),
              },
              required: ['name', 'quantity'],
            ),
          ),
          'servings': Schema.integer(),
        },
        required: ['title_key_in_json', 'ingredients', 'servings'],
      );

      expect(
        AnnotatedRecipe.$schema.jsonSchema().toJson(),
        expectedSchema.toJson(),
      );
    });

    test('Validates annotated schema correctly', () async {
      expect(
        (await AnnotatedRecipe.$schema.jsonSchema().validate({
          'title_key_in_json': 'Pancakes',
          'ingredients': [
            {'name': 'Flour', 'quantity': '1 cup'},
          ],
          'servings': 4,
        })).length,
        isZero,
      );

      expect(
        (await AnnotatedRecipe.$schema.jsonSchema().validate({
          'title_key_in_json': 'Pancakes',
          'ingredients': [
            {'name': 'Flour', 'quantity': '1 cup'},
          ],
        })).length,
        isNot(isZero),
      );

      expect(
        (await AnnotatedRecipe.$schema.jsonSchema().validate({
          'title': 'Pancakes',
          'ingredients': [
            {'name': 'Flour', 'quantity': '1 cup'},
          ],
          'servings': 4,
        })).length,
        isNot(isZero),
      );
    });

    test('Generates correct JSON schema for enums', () {
      final expectedSchema = Schema.object(
        properties: {
          'day': Schema.string(),
          'mealType': Schema.string(
            enumValues: ['breakfast', 'lunch', 'dinner'],
          ),
        },
        required: ['day', 'mealType'],
      );

      expect(MealPlan.$schema.jsonSchema().toJson(), expectedSchema.toJson());
    });

    test('Generates correct JSON schema for nullable fields', () {
      final expectedSchema = Schema.object(
        properties: {
          'optionalString': Schema.string(),
          'optionalInt': Schema.integer(),
          'optionalList': Schema.list(items: Schema.string()),
          'optionalIngredient': Ingredient.$schema.jsonSchema(),
        },
        required: [],
      );

      expect(
        NullableFields.$schema.jsonSchema().toJson(),
        expectedSchema.toJson(),
      );
    });

    test('Parses and accesses nullable data correctly', () {
      // Test with all fields present
      final fullJson = {
        'optionalString': 'hello',
        'optionalInt': 42,
        'optionalList': ['a', 'b'],
        'optionalIngredient': {'name': 'Salt', 'quantity': '1 pinch'},
      };
      final fullData = NullableFields.$schema.parse(fullJson);
      expect(fullData.optionalString, 'hello');
      expect(fullData.optionalInt, 42);
      expect(fullData.optionalList, ['a', 'b']);
      expect(fullData.optionalIngredient?.name, 'Salt');

      // Test with all fields null/missing
      final emptyJson = <String, dynamic>{
        'optionalString': null,
        'optionalInt': null,
        'optionalList': null,
        'optionalIngredient': null,
      };
      final emptyData = NullableFields.$schema.parse(emptyJson);
      expect(emptyData.optionalString, isNull);
      expect(emptyData.optionalInt, isNull);
      expect(emptyData.optionalList, isNull);
      expect(emptyData.optionalIngredient, isNull);

      // Test setting fields to null
      fullData.optionalString = null;
      fullData.optionalInt = null;
      fullData.optionalList = null;
      fullData.optionalIngredient = null;
      expect(fullData.optionalString, isNull);
      expect(fullData.optionalInt, isNull);
      expect(fullData.optionalList, isNull);
      expect(fullData.optionalIngredient, isNull);
    });

    test('Generates correct JSON schema for complex objects', () {
      final expectedSchema = Schema.object(
        properties: {
          'id': Schema.string(),
          'createdAt': Schema.string(format: 'date-time'),
          'price': Schema.number(),
          'metadata': Schema.object(additionalProperties: Schema.string()),
          'ratings': Schema.list(items: Schema.integer()),
          'nestedNullable': NullableFields.$schema.jsonSchema(),
        },
        required: ['id', 'createdAt', 'price', 'metadata', 'ratings'],
      );

      expect(
        ComplexObject.$schema.jsonSchema().toJson(),
        expectedSchema.toJson(),
      );
    });

    test('Parses and accesses complex object data correctly', () {
      final now = DateTime.now();
      final complexJson = {
        'id': 'xyz-123',
        'createdAt': now.toIso8601String(),
        'price': 99.99,
        'metadata': {'source': 'test', 'version': '1.0'},
        'ratings': [5, 4, 5],
        'nestedNullable': {'optionalString': 'nested'},
      };

      final complexObject = ComplexObject.$schema.parse(complexJson);

      expect(complexObject.id, 'xyz-123');
      expect(complexObject.createdAt, now);
      expect(complexObject.price, 99.99);
      expect(complexObject.metadata, {'source': 'test', 'version': '1.0'});
      expect(complexObject.ratings, [5, 4, 5]);
      expect(complexObject.nestedNullable?.optionalString, 'nested');
      expect(complexObject.nestedNullable?.optionalInt, isNull);

      // Test with null nested object
      final complexJsonWithNull = {
        'id': 'xyz-123',
        'createdAt': now.toIso8601String(),
        'price': 99.99,
        'metadata': {'source': 'test', 'version': '1.0'},
        'ratings': [5, 4, 5],
        'nestedNullable': null,
      };
      final complexObjectWithNull = ComplexObject.$schema.parse(
        complexJsonWithNull,
      );
      expect(complexObjectWithNull.nestedNullable, isNull);
    });

    test('Generates correct JSON schema for lists of complex objects', () {
      final expectedSchema = Schema.object(
        properties: {
          'recipes': Schema.list(items: Recipe.$schema.jsonSchema()),
          'optionalIngredients': Schema.list(
            items: Schema.object(
              properties: {
                'name': Schema.string(),
                'quantity': Schema.string(),
              },
              required: ['name', 'quantity'],
            ),
          ),
        },
        required: ['recipes'],
      );

      expect(Menu.$schema.jsonSchema().toJson(), expectedSchema.toJson());
    });

    test('Parses and accesses lists of complex objects correctly', () {
      final menuJson = {
        'recipes': [
          {
            "title": "Pancakes",
            "ingredients": [
              {"name": "Flour", "quantity": "1 cup"},
            ],
            "servings": 4,
          },
        ],
        'optionalIngredients': [
          {"name": "Syrup", "quantity": "2 tbsp"},
        ],
      };

      final menu = Menu.$schema.parse(menuJson);

      expect(menu.recipes.length, 1);
      expect(menu.recipes[0].title, "Pancakes");
      expect(menu.optionalIngredients?.length, 1);
      expect(menu.optionalIngredients?[0].name, "Syrup");
    });
  });
}
