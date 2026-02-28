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
  // Check if API key or Vertex Config is available
  final apiKey =
      Platform.environment['GOOGLE_GENAI_API_KEY'] ??
      Platform.environment['GEMINI_API_KEY'];
  final projectId = Platform.environment['GCLOUD_PROJECT'];
  final location = Platform.environment['GCLOUD_LOCATION'] ?? 'us-central1';

  final configs = [
    if (apiKey != null)
      (
        name: 'Google AI',
        plugin: googleAI(apiKey: apiKey),
        gemini: googleAI.gemini,
        textEmbedding: googleAI.textEmbedding,
        modelName: 'gemini-2.5-flash',
        embedderName: 'gemini-embedding-001',
      ),
    if (projectId != null)
      (
        name: 'Vertex AI',
        plugin: vertexAI(projectId: projectId, location: location),
        gemini: vertexAI.gemini,
        textEmbedding: vertexAI.textEmbedding,
        modelName: 'gemini-2.5-flash',
        embedderName: 'gemini-embedding-001',
      ),
  ];

  if (configs.isEmpty) {
    print('Skipping live tests: No API key or Vertex config found');
    return;
  }

  for (final config in configs) {
    group('${config.name} Integration (Live)', () {
      late Genkit ai;

      setUp(() {
        ai = Genkit(plugins: [config.plugin]);
      });

      test('should list models', () async {
        final actions = await ai.registry.listActions();
        final modelsAndEmbedders = actions.where((a) => a.actionType == 'model' || a.actionType == 'embedder');
        expect(modelsAndEmbedders.isNotEmpty, isTrue);
      });

      test('should generate simple text', () async {
        final response = await ai.generate(
          model: config.gemini(config.modelName),
          prompt: 'Say hello to World',
          config: GeminiOptions(temperature: 0),
        );
        expect(response.text, contains('Hello'));
      });

      test('should stream text', () async {
        final response = ai.generateStream(
          model: config.gemini(config.modelName),
          prompt: 'Count to 15',
        );

        final chunks = await response.toList();
        expect(chunks.length, greaterThan(1));
        final fullText = chunks.map((c) => c.text).join();
        expect(fullText, contains('5'));

        final finalResponse = await response.onResult;
        expect(finalResponse.text, contains('5'));
      });

      test('should generate structured output', () async {
        final response = await ai.generate(
          model: config.gemini(config.modelName),
          prompt: 'Generate a person named John Doe, age 30',
          outputSchema: Person.$schema,
        );

        expect(response.output, isNotNull);
        expect(response.output!.name, 'John Doe');
        expect(response.output!.age, 30);
      });

      test('should stream structured output', () async {
        final response = ai.generateStream(
          model: config.gemini(config.modelName),
          prompt: 'Generate a person named Jane Doe, age 25',
          outputSchema: Person.$schema,
        );

        final finalResponse = await response.onResult;
        expect(finalResponse.output, isNotNull);
        expect(finalResponse.output!.name, 'Jane Doe');
        expect(finalResponse.output!.age, 25);
      });

      test('should use tools', () async {
        final tool = ai.defineTool(
          name: 'calculator',
          description: 'Multiplies two numbers',
          inputSchema: CalculatorInput.$schema,
          outputSchema: .integer(),
          fn: (CalculatorInput input, _) async => input.a * input.b,
        );

        final response = await ai.generate(
          model: config.gemini(config.modelName),
          prompt: 'What is 123 * 456?',
          tools: [tool],
        );

        expect(response.text, contains('56088')); // 123*456 = 56088
      });

      test('should embed text', () async {
        final embeddings = await ai.embedMany(
          embedder: config.textEmbedding(config.embedderName),
          documents: [
            DocumentData(content: [TextPart(text: 'Hello world')]),
          ],
        );

        expect(embeddings, isNotNull);
        expect(embeddings.length, 1);
        expect(embeddings.first.embedding, isNotEmpty);
        expect(embeddings.first.embedding.length, 3072);
      });

      test('should embed multiple texts', () async {
        final embeddings = await ai.embedMany(
          embedder: config.textEmbedding(config.embedderName),
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
        final embeddings = await ai.embedMany(
          embedder: config.textEmbedding(config.embedderName),
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
}
