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

void main(List<String> args) async {
  final ai = Genkit(plugins: [googleAI()]);

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        prompt: input,
      );
      return response.text;
    },
  );

  ai.defineEvaluator(
    name: 'custom',
    description: 'Custom evaluator',
    fn: (input, context) async {
      return [
        ...input.dataset.map(
          (d) => EvalFnResponse(
            testCaseId: d.testCaseId!,
            evaluation: EvalFnResponseEvaluation.score(
              Score(
                score: ScoreScore.bool(true),
                status: EvalStatusEnum.PASS,
                details: {'reasoning': 'something, something, something....'},
              ),
            ),
          ),
        ),
      ];
    },
  );
}
