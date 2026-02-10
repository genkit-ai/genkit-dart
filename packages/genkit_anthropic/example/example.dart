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
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:schemantic/schemantic.dart';

import 'src/model.dart';

void main(List<String> args) {
  configureCollectorExporter();

  final ai = Genkit(
    plugins: [anthropic(apiKey: Platform.environment['ANTHROPIC_API_KEY']!)],
  );

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: stringSchema(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: stringSchema(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Streaming Flow ---
  ai.defineFlow(
    name: 'streaming',
    inputSchema: stringSchema(defaultValue: 'Count to 5'),
    outputSchema: stringSchema(),
    streamSchema: stringSchema(),
    fn: (input, ctx) async {
      final stream = ai.generateStream(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: input,
      );

      await for (final chunk in stream) {
        if (ctx.streamingRequested) {
          ctx.sendChunk(chunk.text);
        }
      }
      return (await stream.onResult).text;
    },
  );

  // --- Tool Calling Flow ---
  ai.defineTool(
    name: 'calculator',
    description: 'Multiplies two numbers',
    inputSchema: CalculatorInput.$schema,
    outputSchema: intSchema(),
    fn: (input, _) async => input.a * input.b,
  );

  ai.defineFlow(
    name: 'toolCalling',
    inputSchema: stringSchema(defaultValue: 'What is 123 * 456?'),
    outputSchema: stringSchema(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: prompt,
        tools: ['calculator'],
      );
      return response.text;
    },
  );

  // --- Thinking Flow (Claude 3.7+) ---
  ai.defineFlow(
    name: 'thinking',
    inputSchema: stringSchema(defaultValue: 'Solve this 24 game: 2, 3, 10, 10'),
    outputSchema: Message.$schema,
    streamSchema: ModelResponseChunk.$schema,
    fn: (prompt, ctx) async {
      final response = await ai.generate(
        // Assuming a model that supports thinking is available or aliased
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: prompt,
        onChunk: ctx.sendChunk,
        config: AnthropicOptions(thinking: ThinkingConfig(budgetTokens: 2048)),
      );
      // The reasoning reasoning is in response.message.content
      // Here we just return the text response
      return response.message!;
    },
  );

  // --- Structured Output Flow ---
  ai.defineFlow(
    name: 'structuredOutput',
    inputSchema: stringSchema(
      defaultValue: 'Generate a person named John Doe, age 30',
    ),
    outputSchema: Person.$schema,
    streamSchema: Person.$schema,
    fn: (prompt, ctx) async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: prompt,
        outputSchema: Person.$schema,
        onChunk: (chunk) {
          ctx.sendChunk(chunk.output!);
        },
      );
      return response.output!;
    },
  );
}
