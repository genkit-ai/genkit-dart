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
  ModelRef geminiFlash,
) {
  // 1. Define a simulated retrieval tool
  final menuRagTool = ai.defineTool(
    name: 'menuRagTool',
    description: 'Use to retrieve information from the Genkit Grub Pub menu.',
    inputSchema: MenuRagToolInput.$schema,
    outputSchema: listSchema(stringSchema()),
    fn: (input, _) async {
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
    fn: (input, _) async {
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
        tools: [menuRagTool.name],
      );
      return llmResponse.text;
    },
  );
}
