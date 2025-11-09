import 'dart:convert';

part 'ext.g.dart';

@Schema()
abstract class IngredientSchema {
  String get name;
  String get quantity;
}

@Schema()
abstract class RecipeSchema {
  String get title;
  List<IngredientSchema> get ingredients;
  List<String> get instructions;
  int get servings;
}

class Action<I, O> {
  JsonExtensionType<I>? inputType;
  JsonExtensionType<O>? outputType;
  Future<O> Function(I input) fn;

  Future<O> run(I input) {
    throw Exception();
  }

  Action({this.inputType, this.outputType, required this.fn});
}

void main() {
  final myFlow = Action(inputType: RecipeType, outputType: StringType, fn:(input) async {
    return "Title: ${input.title}";
  });

  final recipeJson = '''
  {
    "title": "Pancakes",
    "ingredients": [
      {"name": "Flour", "quantity": "1 cup"},
      {"name": "Milk", "quantity": "1 cup"},
      {"name": "Egg", "quantity": "1"}
    ],
    "instructions": [
      "Mix ingredients",
      "Cook on griddle"
    ],
    "servings": 4
  }
  ''';

  final recipeData = RecipeType.parse(jsonDecode(recipeJson));

  myFlow.run(recipeData);

  print('Title: ${recipeData.title}');
  print('Servings: ${recipeData.servings}');
  print('Ingredients:');
  for (final ingredient in recipeData.ingredients) {
    print('  - ${ingredient.name}: ${ingredient.quantity}');
  }
  print('Instructions:');
  for (final instruction in recipeData.instructions) {
    print('  - $instruction');
  }

  // You can also modify the data
  recipeData.title = 'Fluffy Pancakes';
  recipeData.servings = 5;
  print('\n--- Modified Recipe ---');
  print('Title: ${recipeData.title}');
  print('Servings: ${recipeData.servings}');
}
