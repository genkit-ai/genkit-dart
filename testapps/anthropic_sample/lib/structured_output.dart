// Copyright 2026 Google LLC
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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:schemantic/schemantic.dart';

part 'structured_output.g.dart';

@Schema()
abstract class $Recipe {
  /// Name of the dish
  String get title;

  /// Ingredients with quantities, e.g. "2 eggs"
  List<String> get ingredients;

  /// Total time in minutes
  int get minutes;

  /// Optional tip for the cook
  String? get tip;
}

@Schema()
abstract class $Scorecard {
  String get student;

  /// Score per subject. A `Map` field can't be expressed in Anthropic's
  /// schema subset, so the plugin puts this schema in the prompt instead.
  Map<String, int> get scores;
}

@Schema()
abstract class $Category {
  String get name;

  /// Recursive, so this schema also travels in the prompt.
  List<$Category>? get subcategories;
}

@Schema()
abstract class $PantryQuery {
  String get item;
}

/// Native structured output: the schema goes to Anthropic as
/// `output_config.format` and the reply is guaranteed to match it.
Flow<String, Recipe, void, void> defineRecipeFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'recipe',
    inputSchema: .string(defaultValue: 'pancakes'),
    outputSchema: Recipe.$schema,
    fn: (dish, _) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt: 'Write a short recipe for $dish.',
        outputSchema: Recipe.$schema,
      );
      return response.output!;
    },
  );
}

/// A model name the plugin doesn't curate still gets the native path.
Flow<String, Recipe, void, void> defineUncuratedModelFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'recipeUncuratedModel',
    inputSchema: .string(defaultValue: 'shakshuka'),
    outputSchema: Recipe.$schema,
    fn: (dish, _) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt: 'Write a short recipe for $dish.',
        outputSchema: Recipe.$schema,
      );
      return response.output!;
    },
  );
}

/// Streams partial output as the JSON arrives.
Flow<String, Recipe, Recipe, void> defineStreamedRecipeFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'recipeStreamed',
    inputSchema: .string(defaultValue: 'ramen'),
    outputSchema: Recipe.$schema,
    streamSchema: Recipe.$schema,
    fn: (dish, ctx) async {
      final stream = ai.generateStream(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt: 'Write a short recipe for $dish.',
        outputSchema: Recipe.$schema,
      );
      await for (final chunk in stream) {
        final partial = chunk.output;
        if (ctx.streamingRequested && partial != null) ctx.sendChunk(partial);
      }
      return (await stream.onResult).output!;
    },
  );
}

/// Structured output composes with the caller's own tools and with thinking:
/// the schema pins no `tool_choice`.
Flow<String, Recipe, void, void> defineRecipeWithToolsFlow(Genkit ai) {
  final pantry = ai.defineTool(
    name: 'checkPantry',
    description: 'Returns how much of an ingredient is in the pantry',
    inputSchema: PantryQuery.$schema,
    outputSchema: .string(),
    fn: (query, _) async =>
        .response(query.item.toLowerCase().contains('egg') ? 'none' : 'plenty'),
  );

  return ai.defineFlow(
    name: 'recipeWithTools',
    inputSchema: .string(defaultValue: 'a quick breakfast'),
    outputSchema: Recipe.$schema,
    fn: (dish, _) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt:
            'Suggest a recipe for $dish. Check the pantry for each main '
            'ingredient first and avoid anything we are out of.',
        tools: [pantry],
        outputSchema: Recipe.$schema,
        config: AnthropicOptions(
          thinking: AnthropicThinkingConfig(
            type: 'enabled',
            budgetTokens: 1024,
          ),
        ),
      );
      return response.output!;
    },
  );
}

/// Shapes Anthropic can't constrain (a `Map` field, a recursive type) travel
/// in the system prompt instead: unenforced, but still parsed and typed.
Flow<String, Scorecard, void, void> defineScorecardFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'scorecardPromptFallback',
    inputSchema: .string(defaultValue: 'Ada: maths 90, art 70, music 85'),
    outputSchema: Scorecard.$schema,
    fn: (input, _) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt: 'Turn this into a scorecard: $input',
        outputSchema: Scorecard.$schema,
      );
      return response.output!;
    },
  );
}

Flow<String, Category, void, void> defineTaxonomyFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'taxonomyPromptFallback',
    inputSchema: .string(defaultValue: 'string instruments'),
    outputSchema: Category.$schema,
    fn: (topic, _) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5-5'),
        prompt: 'Build a small two-level taxonomy of $topic.',
        outputSchema: Category.$schema,
      );
      return response.output!;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [anthropic(apiKey: Platform.environment['ANTHROPIC_API_KEY'])],
  );

  defineRecipeFlow(ai);
  defineUncuratedModelFlow(ai);
  defineStreamedRecipeFlow(ai);
  defineRecipeWithToolsFlow(ai);
  defineScorecardFlow(ai);
  defineTaxonomyFlow(ai);
}
