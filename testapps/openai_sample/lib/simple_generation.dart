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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

/// Defines a flow that demonstrates basic text generation with an OpenAI model.
///
/// Takes a plain text prompt and returns the model's text response. This is the
/// simplest possible integration — no tools, no structured output, no streaming.
Flow<String, String, void, void> defineSimpleGenerationFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'simpleGeneration',
    inputSchema: stringSchema(
      defaultValue: 'Tell me a joke about Dart programming.',
    ),
    outputSchema: stringSchema(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o-mini'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Defines a flow that demonstrates real-time token streaming from OpenAI.
///
/// When called with streaming requested, text chunks are emitted as they arrive
/// from the model. The full concatenated text is returned as the final output.
/// Uses [OpenAIOptions] to configure temperature and token limits.
Flow<String, String, String, void> defineStreamedSimpleGenerationFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'streamedSimpleGeneration',
    inputSchema: stringSchema(
      defaultValue: 'Tell me a joke about Dart programming.',
    ),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (prompt, ctx) async {
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o-mini'),
        prompt: prompt,
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested) {
          ctx.sendChunk(chunk.text);
        }
      }

      return (await stream.onResult).text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  defineSimpleGenerationFlow(ai);
  defineStreamedSimpleGenerationFlow(ai);
}
