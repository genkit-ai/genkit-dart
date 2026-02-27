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
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/plugin_impl.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'test_live.g.dart';

@Schematic()
abstract class $Person {
  String get name;
  int get age;
}

@Schematic()
abstract class $CalculatorInput {
  int get a;
  int get b;
}

void main() {
  // Check if API key is available
  final apiKey =
      Platform.environment['GOOGLE_GENAI_API_KEY'] ??
      Platform.environment['GEMINI_API_KEY'];

  group('Google AI Integration (Live)', () {
    late Genkit ai;
    GoogleGenAiPluginImpl? plugin;

    setUp(() {
      if (apiKey == null) {
        return;
      }
      plugin = GoogleGenAiPluginImpl(apiKey: apiKey);
      ai = Genkit(plugins: [plugin!]);
    });

    tearDown(() {
      // plugin?.close(); // GoogleGenAiPluginImpl doesn't need explicit close usually, but good practice if it did
    });

    test('should generate simple text', () async {
      if (apiKey == null) {
        print('Skipping live test: No API key');
        return;
      }
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: 'Say hello to World',
        config: GeminiOptions(temperature: 0),
      );
      expect(response.text, contains('Hello'));
    });

    test('should stream text', () async {
      if (apiKey == null) return;
      final response = ai.generateStream(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: 'Count to 5',
      );

      final chunks = await response.toList();
      expect(chunks.length, greaterThan(1));
      final fullText = chunks.map((c) => c.text).join();
      expect(fullText, contains('5'));

      final finalResponse = await response.onResult;
      expect(finalResponse.text, contains('5'));
    });

    test('should generate structured output', () async {
      if (apiKey == null) return;
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: 'Generate a person named John Doe, age 30',
        outputSchema: Person.$schema,
      );

      expect(response.output, isNotNull);
      expect(response.output!.name, 'John Doe');
      expect(response.output!.age, 30);
    });

    test('should stream structured output', () async {
      if (apiKey == null) return;
      final response = ai.generateStream(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: 'Generate a person named Jane Doe, age 25',
        outputSchema: Person.$schema,
      );

      final finalResponse = await response.onResult;
      expect(finalResponse.output, isNotNull);
      expect(finalResponse.output!.name, 'Jane Doe');
      expect(finalResponse.output!.age, 25);
    });

    test('should use tools', () async {
      if (apiKey == null) return;
      final tool = ai.defineTool(
        name: 'calculator',
        description: 'Multiplies two numbers',
        inputSchema: CalculatorInput.$schema,
        outputSchema: .integer(),
        fn: (CalculatorInput input, _) async => input.a * input.b,
      );

      // Note: Gemini 1.5 Flash is good at tool calls
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3-flash-preview'),
        prompt: 'What is 123 * 456?',
        tools: [tool],
      );

      expect(response.text, contains('56,088')); // 123*456 = 56088
    });

    test('should embed text', () async {
      if (apiKey == null) return;
      final embeddings = await ai.embedMany(
        embedder: googleAI.textEmbedding('text-embedding-004'),
        documents: [
          DocumentData(content: [TextPart(text: 'Hello world')]),
        ],
      );

      expect(embeddings, isNotNull);
      expect(embeddings.length, 1);
      expect(embeddings.first.embedding, isNotEmpty);
      print('Embedding length: ${embeddings.first.embedding.length}');
      expect(
        embeddings.first.embedding.length,
        768,
      ); // text-embedding-004 dimension
    });

    test('should embed multiple texts', () async {
      if (apiKey == null) return;
      final embeddings = await ai.embedMany(
        embedder: googleAI.textEmbedding('text-embedding-004'),
        documents: [
          DocumentData(content: [TextPart(text: 'Hello')]),
          DocumentData(content: [TextPart(text: 'World')]),
        ],
      );

      expect(embeddings.length, 2);
      expect(embeddings[0].embedding, isNotEmpty);
      expect(embeddings[1].embedding, isNotEmpty);
    });

    test('should embed with options', () async {
      if (apiKey == null) return;
      final embeddings = await ai.embedMany(
        embedder: googleAI.textEmbedding('text-embedding-004'),
        documents: [
          DocumentData(content: [TextPart(text: 'Hello')]),
        ],
        options: TextEmbedderOptions(
          outputDimensionality: 256,
          taskType: 'RETRIEVAL_DOCUMENT',
        ),
      );

      expect(embeddings.length, 1);
      expect(embeddings.first.embedding.length, 256);
    });
  });
}
