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
import 'package:genkit_openai/genkit_openai.dart';

/// Generates with Mistral Small.
///
/// No base URL, no model definitions: `mistral()` knows where Mistral lives,
/// which key to read, and what its models can do.
Flow<String, String, void, void> defineMistralFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'mistralGenerate',
    inputSchema: .string(defaultValue: 'Explain a monad in two sentences.'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Asks for a repeatable answer with a seed.
///
/// Mistral calls the field `random_seed`; the plugin renames it, so the option
/// is the same one OpenAI takes.
Flow<String, String, void, void> defineMistralSeededFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'mistralSeeded',
    inputSchema: .string(defaultValue: 'Name a colour.'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: prompt,
        config: OpenAIChatOptions(seed: 42, maxTokens: 64),
      );
      return response.text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [mistral(apiKey: Platform.environment['MISTRAL_API_KEY'])],
  );

  defineMistralFlow(ai);
  defineMistralSeededFlow(ai);
}
