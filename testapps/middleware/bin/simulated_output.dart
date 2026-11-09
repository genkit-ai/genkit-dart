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
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'simulated_output.g.dart';

@Schema()
abstract class $Recipe {
  String get title;
  List<String> get ingredients;
  int get minutes;
}

/// Structured output with the schema in the prompt rather than sent as a
/// native constraint. Gemini supports native constraints, so this is only to
/// show the middleware; reach for it with models or providers that do not.
///
/// Run with `dart run bin/simulated_output.dart` and open the Developer UI to
/// compare the two flows' requests.
void main() {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('GEMINI_API_KEY environment variable is required.');
    exit(1);
  }

  final ai = Genkit(plugins: [googleAI(apiKey: apiKey)]);
  final model = googleAI.gemini('gemini-flash-latest');

  // Native: the plugin sends the schema as `responseJsonSchema`.
  ai.defineFlow(
    name: 'nativeRecipe',
    inputSchema: .string(defaultValue: 'pancakes'),
    outputSchema: Recipe.$schema,
    fn: (dish, _) async {
      final response = await ai.generate(
        model: model,
        prompt: 'Write a short recipe for $dish.',
        outputSchema: Recipe.$schema,
      );
      return response.output!;
    },
  );

  // Simulated: the schema goes in the prompt and no native constraint is
  // sent. The response is still parsed into a typed `Recipe`.
  ai.defineFlow(
    name: 'simulatedRecipe',
    inputSchema: .string(defaultValue: 'pancakes'),
    outputSchema: Recipe.$schema,
    fn: (dish, _) async {
      final response = await ai.generate(
        model: model,
        prompt: 'Write a short recipe for $dish.',
        outputSchema: Recipe.$schema,
        use: [simulateConstrainedGeneration()],
      );
      return response.output!;
    },
  );
}
