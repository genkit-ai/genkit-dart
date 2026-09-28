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

/// Generates with Grok.
///
/// No base URL, no model definitions: `xAI()` knows where xAI lives, which key
/// to read, and what its models can do.
Flow<String, String, void, void> defineXaiFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'xaiGenerate',
    inputSchema: .string(defaultValue: 'Explain a monad in two sentences.'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: XaiModels.grok46,
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Trades latency against depth with a reasoning effort.
///
/// xAI's levels are `none`, `low`, `medium`, `high` and `xhigh`, and which of
/// them a given model takes varies — the plugin rejects one the provider does
/// not define before the request goes out.
Flow<String, String, void, void> defineXaiEffortFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'xaiEffort',
    inputSchema: .string(defaultValue: 'Is 8051 prime?'),
    outputSchema: .string(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: XaiModels.grok43,
        prompt: prompt,
        config: OpenAIChatOptions(reasoningEffort: 'low'),
      );
      return response.text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [xAI(apiKey: Platform.environment['XAI_API_KEY'])],
  );

  defineXaiFlow(ai);
  defineXaiEffortFlow(ai);
}
