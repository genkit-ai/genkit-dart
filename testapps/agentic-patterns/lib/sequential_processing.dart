import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'sequential_processing.g.dart';

@Schematic()
abstract class $StoryInput {
  String get topic;
}

@Schematic()
abstract class $StoryIdea {
  /// A short, compelling story concept
  String get idea;
}

Flow<StoryInput, String, void, void> defineStoryWriterFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
  return ai.defineFlow(
    name: 'storyWriterFlow',
    inputSchema: StoryInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      // Step 1: Generate a creative story idea
      final ideaResponse = await ai.generate(
        model: geminiFlash,
        prompt: 'Generate a unique story idea about a ${input.topic}.',
        outputSchema: StoryIdea.$schema,
      );

      final storyIdea = ideaResponse.output?.idea;
      if (storyIdea == null) {
        throw Exception('Failed to generate a story idea.');
      }

      // Step 2: Use the idea to write the beginning of the story
      final storyResponse = await ai.generate(
        model: geminiFlash,
        prompt:
            'Write the opening paragraph for a story based on this idea: $storyIdea',
      );

      return storyResponse.text;
    },
  );
}
