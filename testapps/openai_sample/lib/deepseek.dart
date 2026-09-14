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

/// Generates with DeepSeek Flash.
///
/// No base URL, no model definitions: `deepSeek()` knows where DeepSeek lives,
/// which key to read, and what its models can do.
Flow<String, String, void, void> defineDeepSeekFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'deepseekGenerate',
    inputSchema: .string(defaultValue: 'Explain a monad in two sentences.'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Shows the thinking DeepSeek did before answering.
///
/// Thinking is on by default for the models that support it, which is the
/// opposite of OpenAI's behaviour — so the reasoning arrives without being
/// asked for, as a `ReasoningPart` ahead of the answer.
Flow<String, String, void, void> defineDeepSeekThinkingFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'deepseekThinking',
    inputSchema: .string(defaultValue: 'Is 8051 prime? Think it through.'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: prompt,
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      final reasoning = response.message?.content
          .where((part) => part.isReasoning)
          .map((part) => part.reasoning)
          .join('\n');

      return 'Thinking:\n${reasoning?.isEmpty ?? true ? '(none returned)' : reasoning}'
          '\n\nAnswer:\n${response.text}';
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [deepSeek(apiKey: Platform.environment['DEEPSEEK_API_KEY'])],
  );

  defineDeepSeekFlow(ai);
  defineDeepSeekThinkingFlow(ai);
}
