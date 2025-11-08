import 'dart:convert';
import 'package:genkit/schema.dart';
import 'package:test/test.dart';
import 'package:json_annotation/json_annotation.dart';

part 'extension_type_test.schema.g.dart';

@GenkitSchema()
abstract class IngredientSchema {
  String get name;
  String get quantity;
}

@GenkitSchema()
abstract class RecipeSchema {
  @JsonKey(name: 'title')
  String get title;
  List<IngredientSchema> get ingredients;
  int get servings;
}

enum MealType { breakfast, lunch, dinner }

@GenkitSchema()
abstract class MealPlanSchema {
  String get day;
  MealType get mealType;
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

      final recipe = RecipeType.parse(recipeJson);

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

      expect(RecipeType.jsonSchema.toJson(), expectedSchema.toJson());
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

      expect(MealPlanType.jsonSchema.toJson(), expectedSchema.toJson());
    });
  });
}
