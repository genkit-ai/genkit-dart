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

import 'package:basic_sample/simple_flow_types.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  ai.defineModel(
    name: 'echo',
    fn: (req, ctx) async {
      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [
            TextPart(text: 'echo: ${req.messages.map((m) => m.text).join()}'),
          ],
        ),
      );
    },
  );

  final inner = ai.defineFlow(
    name: 'inner',
    fn: (String subject, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: 'tell me joke about $subject',
      );
      return response.text;
    },
  );

  ai.defineFlow(
    name: 'outer',
    inputSchema: .string(),
    outputSchema: .string(),
    streamSchema: .string(),
    fn: (String name, context) async {
      if (context.streamingRequested) {
        for (var i = 0; i < 5; i++) {
          context.sendChunk('Thinking... $i');
          await Future.delayed(Duration(seconds: 1)); // Delays for 1 second
        }
      }
      return await inner(name);
    },
  );

  ai.defineFlow(
    name: 'recipeTransformer',
    inputSchema: Recipe.$schema,
    outputSchema: Recipe.$schema,
    fn: (recipe, context) async {
      final hasSalt = recipe.ingredients.any(
        (i) => i.name.toLowerCase() == 'salt',
      );
      if (hasSalt) {
        return recipe;
      }
      return Recipe(
        title: recipe.title,
        servings: recipe.servings,
        ingredients: [
          ...recipe.ingredients,
          Ingredient(name: 'salt', quantity: 'a pinch'),
        ],
      );
    },
  );
}
