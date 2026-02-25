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
import 'package:schemantic/schemantic.dart';

/// Defines a flow for simple text generation with DeepSeek.
Flow<String, String, void, void> defineSimpleGenerationFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'simpleGeneration',
    inputSchema: stringSchema(defaultValue: 'Explain how LLMs work'),
    outputSchema: stringSchema(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: deepSeek.model('deepseek-chat'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Defines a flow for streaming text generation with DeepSeek.
Flow<String, String, String, void> defineStreamedGenerationFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'streamedGeneration',
    inputSchema: stringSchema(defaultValue: 'Explain how LLMs work'),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (prompt, ctx) async {
      final stream = ai.generateStream(
        model: deepSeek.model('deepseek-chat'),
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

/// Defines a flow for reasoning with deepseek-reasoner.
Flow<String, String, void, void> defineReasonerFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'reasonerGeneration',
    inputSchema: stringSchema(
      defaultValue: 'What is the sum of the first 100 prime numbers?',
    ),
    outputSchema: stringSchema(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: deepSeek.model('deepseek-reasoner'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Defines a flow that demonstrates dynamic model resolution.
///
/// References a model not in the predefined list. The plugin resolves it
/// on-the-fly via [deepSeekModelInfo].
Flow<String, String, void, void> defineDynamicModelFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'dynamicModelGeneration',
    inputSchema: stringSchema(defaultValue: 'Say hello in 3 languages'),
    outputSchema: stringSchema(),
    fn: (prompt, _) async {
      final response = await ai.generate(
        model: deepSeek.model('deepseek-v3'),
        prompt: prompt,
      );
      return response.text;
    },
  );
}

/// Defines a flow for chat with a system prompt.
Flow<String, String, void, void> defineSystemPromptFlow(Genkit ai) {
  return ai.defineFlow(
    name: 'systemPromptChat',
    inputSchema: stringSchema(defaultValue: 'Explain flutter'),
    outputSchema: stringSchema(),
    fn: (userMessage, _) async {
      final messages = <Message>[
        Message(
          role: Role.system,
          content: [
            TextPart(
              text: 'You are a helpful expert in Dart and Flutter development. '
                  'Provide clear, concise, and accurate answers.',
            ),
          ],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: userMessage)],
        ),
      ];

      final response = await ai.generate(
        model: deepSeek.model('deepseek-chat'),
        messages: messages,
      );
      return response.text;
    },
  );
}

void main() {
  final ai = Genkit(
    plugins: [deepSeek(apiKey: Platform.environment['DEEPSEEK_API_KEY'])],
  );

  defineSimpleGenerationFlow(ai);
  defineStreamedGenerationFlow(ai);
  defineReasonerFlow(ai);
  defineDynamicModelFlow(ai);
  defineSystemPromptFlow(ai);
}
