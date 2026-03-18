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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic_sample/person.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final personTool = ai.defineTool(
    name: 'get_person',
    description: 'Returns information about a person',
    inputSchema: .string(),
    outputSchema: Person.schema,
    fn: (name, _) async {
      return Person(firstName: name, lastName: 'Example');
    },
  );

  final greetFlow = ai.defineFlow(
    name: 'greetFlow',
    inputSchema: Person.schema,
    outputSchema: .string(),
    fn: (person, _) async {
      return 'Hello, ${person.firstName} ${person.lastName}!';
    },
  );

  // 4. Define a structured output flow using a real model
  final characterFlow = ai.defineFlow(
    name: 'characterFlow',
    inputSchema: .string(),
    outputSchema: RpgCharacter.schema,
    fn: (name, _) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        outputSchema: RpgCharacter.schema,
        prompt:
            'Generate an RPG character called $name. '
            'Return ONLY JSON matching the schema.',
      );
      return response.output!;
    },
  );

  print('--- Running Greet Flow ---');
  final result = await greetFlow.runRaw({
    'firstName': 'Alice',
    'lastName': 'Liddell',
  });
  print(result.result);

  print('\n--- Running Character Flow (Gemini Flash) ---');
  try {
    final char = await characterFlow('Gorble');
    print('Character: ${char.name}');
    print('Alignment: ${char.alignment}');
    print('Backstory: ${char.backstory}');
  } catch (e) {
    print('Character Flow failed: $e');
    print('\nNOTE: Ensure GENAI_API_KEY is set in your environment.');
  }

  print('\n--- Running Tool ---');
  final person = await personTool('Bob');
  print('Tool result: ${person.firstName} ${person.lastName}');

  print('\n--- JSON Schema for Flow ---');
  print(greetFlow.inputSchema?.jsonSchema());
}
