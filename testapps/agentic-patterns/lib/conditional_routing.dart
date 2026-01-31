import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'conditional_routing.g.dart';

@Schematic()
abstract class $RouterInput {
  String get query;
}

@Schematic()
abstract class $IntentClassification {
  @Schematic()
  String get intent;
}

Flow<RouterInput, String, void, void> defineRouterFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
  return ai.defineFlow(
    name: 'routerFlow',
    inputSchema: RouterInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      // Step 1: Classify the user's intent
      final intentResponse = await ai.generate(
        model: geminiFlash,
        prompt:
            "Classify the user's query as either a 'question' or a 'creative' request. Query: \"${input.query}\"",
        outputSchema: IntentClassification.$schema,
      );

      final intent = intentResponse.output?.intent;

      // Step 2: Route based on the intent
      if (intent == 'question') {
        // Handle as a straightforward question
        final answerResponse = await ai.generate(
          model: geminiFlash,
          prompt: 'Answer the following question: ${input.query}',
        );
        return answerResponse.text;
      } else if (intent == 'creative') {
        // Handle as a creative writing prompt
        final creativeResponse = await ai.generate(
          model: geminiFlash,
          prompt: 'Write a short poem about: ${input.query}',
        );
        return creativeResponse.text;
      } else {
        return "Sorry, I couldn't determine how to handle your request.";
      }
    },
  );
}
