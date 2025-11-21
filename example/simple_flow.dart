import 'package:genkit/genkit.dart';
import 'package:genkit/plugins/google-genai.dart';

part 'simple_flow.schema.g.dart';

@GenkitSchema()
abstract class IngredientSchema {
  String get name;
  String get quantity;
}

@GenkitSchema()
abstract class RecipeSchema {
  String get title;
  List<IngredientSchema> get ingredients;
  int get servings;
}

void main() async {
  configureCollectorExporter();

  final ai = Genkit();
  defineGoogleGenAiModels(ai);

  ai.defineModel(
    name: 'echo',
    fn: (req, ctx) async {
      return ModelResponse.from(
        finishReason: FinishReason.stop,
        message: Message.from(
          role: Role.model,
          content: [
            TextPart.from(
              text: 'echo: ${req.messages.map((m) => m.text).join()}',
            ),
          ],
        ),
      );
    },
  );

  final child = ai.defineFlow(
    name: 'child',
    fn: (String subject, context) async {
      final response = await ai.generate(
        model: 'gemini-2.5-flash',
        prompt: 'tell me joke about $subject',
      );
      return response.text;
    },
  );

  ai.defineFlow(
    name: 'parent',
    inputType: StringType,
    outputType: StringType,
    streamType: StringType,
    fn: (String name, context) async {
      if (context.streamingRequested) {
        for (var i = 0; i < 5; i++) {
          context.sendChunk('Thinking... $i');
          await Future.delayed(Duration(seconds: 1)); // Delays for 2 seconds
        }
      }
      return await child(name);
    },
  );

  ai.defineFlow(
    name: 'recipeTransformer',
    inputType: RecipeType,
    outputType: RecipeType,
    fn: (recipe, context) async {
      final hasSalt =
          recipe.ingredients.any((i) => i.name.toLowerCase() == 'salt');
      if (hasSalt) {
        return recipe;
      }
      return Recipe.from(
        title: recipe.title,
        servings: recipe.servings,
        ingredients: [
          ...recipe.ingredients,
          Ingredient.from(name: 'salt', quantity: 'a pinch'),
        ],
      );
    },
  );
}
