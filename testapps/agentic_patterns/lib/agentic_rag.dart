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
import 'package:schemantic/schemantic.dart';

part 'agentic_rag.g.dart';

@Schematic()
abstract class $AgenticRagInput {
  String get question;
}

@Schematic()
abstract class $MenuRagToolInput {
  @Field(
    description:
        'A short, single-word query (important -- only use one word) to search the menu (e.g. "burger" if looking for burgers).',
  )
  String get query;
}

Flow<AgenticRagInput, String, void, void> defineAgenticRagFlow(
  Genkit ai,
  ModelReference geminiFlash,
) {
  // 1. Define a simulated retrieval tool
  final menuRagTool = ai.defineTool(
    name: 'menuRagTool',
    description: 'Use to retrieve information from the Genkit Grub Pub menu.',
    inputSchema: MenuRagToolInput.$schema,
    outputSchema: listSchema(stringSchema()),
    function: (input, _) async {
      const menuItems = [
        'Classic Burger: A juicy beef patty with lettuce, tomato, and our special sauce.',
        'Vegan Burger: A delicious plant-based patty with avocado and sprouts.',
        'Fries: Crispy golden fries, lightly salted.',
        'Milkshake: A thick and creamy milkshake, available in vanilla, chocolate, and strawberry.',
        'Salad: A fresh garden salad with your choice of dressing.',
        'Chicken Sandwich: Grilled chicken breast with honey mustard on a brioche bun.',
        'Fish and Chips: Beer-battered cod with a side of tartar sauce.',
        'Onion Rings: Thick-cut onion rings, fried to perfection.',
        'Ice Cream Sundae: Two scoops of vanilla ice cream with chocolate sauce and a cherry on top.',
        'Apple Pie: A classic apple pie with a flaky crust, served warm.',
      ];

      // Simulate retrieval with simple substring match
      final query = input.query.toLowerCase();
      final results = menuItems
          .where((item) => item.toLowerCase().contains(query))
          .toList();

      return results;
    },
  );

  // 2. Use the tool in a flow
  return ai.defineFlow(
    name: 'agenticRagFlow',
    inputSchema: AgenticRagInput.$schema,
    outputSchema: stringSchema(),
    function: (input, _) async {
      final llmResponse = await ai.generate(
        model: geminiFlash,
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text:
                    'You are a helpful AI assistant that can answer questions about the food available on the menu at Genkit Grub Pub.\n'
                    'Use the provided tool to answer questions.\n'
                    "If you don't know, do not make up an answer.\n"
                    'Do not add or change items on the menu.',
              ),
            ],
          ),
        ],
        prompt: input.question,
        toolNames: [menuRagTool.name],
      );
      return llmResponse.text;
    },
  );
}
