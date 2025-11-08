import 'dart:convert';
import 'package:genkit/schema.dart';
import 'package:test/test.dart';

part 'extension_type_test.schema.g.dart';

@Schema()
abstract class IngredientSchema {
  String get name;
  String get quantity;
}

@Schema()
abstract class RecipeSchema {
  String get title;
  List<IngredientSchema> get ingredients;
  int get servings;
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
      final expectedSchema = {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'ingredients': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'quantity': {'type': 'string'},
              },
              'required': ['name', 'quantity'],
            },
          },
          'servings': {'type': 'integer'},
        },
        'required': ['title', 'ingredients', 'servings'],
      };

      expect(RecipeType.jsonSchema, expectedSchema);
    });
  });
}
