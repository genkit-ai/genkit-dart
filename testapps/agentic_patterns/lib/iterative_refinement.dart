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

Flow<IterativeRefinementInput, String, void, void>
defineIterativeRefinementFlow(Genkit ai, ModelRef geminiFlash) {
  return ai.defineFlow(
    name: 'iterativeRefinementFlow',
    inputSchema: IterativeRefinementInput.$schema,
    outputSchema: .string(),
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
}
