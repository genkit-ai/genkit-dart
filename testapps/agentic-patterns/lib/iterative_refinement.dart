import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'iterative_refinement.g.dart';

@Schematic()
abstract class $IterativeRefinementInput {
  String get topic;
}

@Schematic()
abstract class $Evaluation {
  String get critique;
  bool get satisfied;
}

final iterativeRefinementFlow = ai.defineFlow(
  name: 'iterativeRefinementFlow',
  inputSchema: IterativeRefinementInput.$schema,
  outputSchema: stringSchema(),
  fn: (input, _) async {
    var content = '';
    var feedback = '';
    var attempts = 0;

    // Step 1: Generate the initial draft
    final draftResponse = await ai.generate(
      model: geminiFlash,
      prompt:
          'Write a short, single-paragraph blog post about: ${input.topic}.',
    );
    content = draftResponse.text;

    // Step 2: Iteratively refine the content
    while (attempts < 3) {
      attempts++;

      // The "Evaluator" provides feedback
      final evaluationResponse = await ai.generate(
        model: geminiFlash,
        prompt:
            'Critique the following blog post. Is it clear, concise, and engaging? Provide specific feedback for improvement. Post: "$content"',
        outputSchema: Evaluation.$schema,
      );

      final evaluation = evaluationResponse.output;
      if (evaluation == null) {
        throw Exception('Failed to evaluate content.');
      }

      if (evaluation.satisfied) {
        break; // Exit loop if content is good enough
      }

      feedback = evaluation.critique;

      // The "Optimizer" refines the content based on feedback
      final optimizationResponse = await ai.generate(
        model: geminiFlash,
        prompt:
            'Revise the following blog post based on the feedback provided.\nPost: "$content"\nFeedback: "$feedback"',
      );
      content = optimizationResponse.text;
    }

    return content;
  },
);
