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

@Schematic()
abstract class $ImageGeneratorInput {
  String get concept;
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

Flow<ImageGeneratorInput, String, void, void> defineImageGeneratorFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
  final geminiImage = modelRef('googleai/gemini-2.5-flash-image');

  return ai.defineFlow(
    name: 'imageGeneratorFlow',
    inputSchema: ImageGeneratorInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      // Step 1: Use a text model to generate a rich image prompt
      final promptResponse = await ai.generate(
        model: geminiFlash,
        prompt:
            'Create a detailed, artistic prompt for an image generation model. The concept is: "${input.concept}".',
      );

      final imagePrompt = promptResponse.text;

      // Step 2: Use the generated prompt to create an image
      final imageResponse = await ai.generate(
        model: geminiImage,
        prompt: imagePrompt,
        config: {
          'responseModalities': ['image']
        },
      );

      final imageUrl = imageResponse.media?.url;
      if (imageUrl == null) {
        throw Exception('Failed to generate an image.');
      }
      return imageUrl;
    },
  );
}
