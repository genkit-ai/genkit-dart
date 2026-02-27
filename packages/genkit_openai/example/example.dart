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

part 'example.g.dart';

@Schematic()
abstract class $CalculatorInput {
  int get a;
  int get b;
}

@Schematic()
abstract class $Person {
  String get name;
  int get age;
}

void main(List<String> args) {
  final ai = Genkit(
    plugins: [openAI(apiKey: Platform.environment['OPENAI_API_KEY'])],
  );

  // --- Basic Generate Flow ---
  ai.defineFlow(
    name: 'basicGenerate',
    inputSchema: .string(defaultValue: 'Hello Genkit for Dart!'),
    outputSchema: .string(),
    fn: (input, context) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: input,
      );
      return response.text;
    },
  );

  // --- Streaming Flow ---
  ai.defineFlow(
    name: 'streaming',
    inputSchema: .string(defaultValue: 'Count to 5'),
    outputSchema: .string(),
    streamSchema: .string(),
    fn: (input, ctx) async {
      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
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
    outputSchema: .integer(),
    fn: (input, _) async => input.a * input.b,
  );

  ai.defineFlow(
    name: 'toolCalling',
    inputSchema: .string(defaultValue: 'What is 123 * 456?'),
    outputSchema: .string(),
    fn: (prompt, context) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: prompt,
        toolNames: ['calculator'],
      );
      return response.text;
    },
  );

  // --- Structured Output Flow ---
  ai.defineFlow(
    name: 'structuredOutput',
    inputSchema: .string(
      defaultValue: 'Generate a person named John Doe, age 30',
    ),
    outputSchema: Person.$schema,
    streamSchema: Person.$schema,
    fn: (prompt, ctx) async {
      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: prompt,
        outputSchema: Person.$schema,
        onChunk: (chunk) {
          if (chunk.output != null) {
            ctx.sendChunk(chunk.output!);
          }
        },
      );
      return response.output!;
    },
  );
}
