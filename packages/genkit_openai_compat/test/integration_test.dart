// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai_compat/genkit_openai_compat.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'integration_test.g.dart';

void main() {
  final apiKey = Platform.environment['OPENAI_API_KEY'];

  group('Integration Tests', () {
    setUpAll(() {
      if (apiKey == null || apiKey.isEmpty) {
        print('Skipping integration tests: OPENAI_API_KEY not set');
      }
    });

    test('generates text with GPT-4o', () async {
      if (apiKey == null || apiKey.isEmpty) return;

      final ai = Genkit(plugins: [
        openAI(apiKey: apiKey),
      ]);

      final response = await ai.generate(
        model: openAI.gpt4o,
        prompt: 'Say "hello" and nothing else.',
      );

      expect(response.text, isNotEmpty);
      expect(response.text.toLowerCase(), contains('hello'));
    }, skip: apiKey == null || apiKey.isEmpty);

    test('generates text with custom options', () async {
      if (apiKey == null || apiKey.isEmpty) return;

      final ai = Genkit(plugins: [
        openAI(apiKey: apiKey),
      ]);

      final response = await ai.generate(
        model: openAI.gpt4o,
        prompt: 'Write a haiku about Dart.',
        config: OpenAIOptions.from(
          temperature: 0.7,
          maxTokens: 100,
        ),
      );

      expect(response.text, isNotEmpty);
      expect(response.text.length, lessThan(200));
    }, skip: apiKey == null || apiKey.isEmpty);

    test('streaming generation', () async {
      if (apiKey == null || apiKey.isEmpty) return;

      final ai = Genkit(plugins: [
        openAI(apiKey: apiKey),
      ]);

      final chunks = <GenerateResponseChunk>[];
      await for (final chunk in ai.generateStream(
        model: openAI.gpt4o,
        prompt: 'Count from 1 to 5.',
      )) {
        chunks.add(chunk);
      }

      expect(chunks.length, greaterThan(0));
      final fullText = chunks
          .expand((c) => c.content)
          .where((p) => p.isText)
          .map((p) => p.text!)
          .join('');
      expect(fullText.toLowerCase(), contains('1'));
    }, skip: apiKey == null || apiKey.isEmpty);

    test('tool calling', () async {
      if (apiKey == null || apiKey.isEmpty) return;

      final ai = Genkit(plugins: [
        openAI(apiKey: apiKey),
      ]);

      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        inputType: WeatherInputType,
        fn: (input, ctx) async {
          return {'temperature': 72, 'condition': 'sunny'};
        },
      );

      final response = await ai.generate(
        model: openAI.gpt4o,
        prompt: 'What\'s the weather in Boston?',
        tools: ['getWeather'],
      );

      expect(response.message, isNotNull);
      final hasToolRequest = response.message!.content
          .any((p) => p.isToolRequest);
      expect(hasToolRequest, isTrue);
    }, skip: apiKey == null || apiKey.isEmpty);

    test('multi-turn conversation', () async {
      if (apiKey == null || apiKey.isEmpty) return;

      final ai = Genkit(plugins: [
        openAI(apiKey: apiKey),
      ]);

      final response1 = await ai.generate(
        model: openAI.gpt4o,
        prompt: 'My name is Alice.',
      );

      final response2 = await ai.generate(
        model: openAI.gpt4o,
        messages: [
          Message.from(role: Role.user, content: [TextPart.from(text: 'My name is Alice.')]),
          Message.from(role: Role.model, content: [TextPart.from(text: response1.text)]),
          Message.from(role: Role.user, content: [TextPart.from(text: 'What is my name?')]),
        ],
      );

      expect(response2.text, isNotEmpty);
      expect(response2.text.toLowerCase(), contains('alice'));
    }, skip: apiKey == null || apiKey.isEmpty);
  });
}

// Simple schema for weather tool input
@Schematic()
abstract class WeatherInputSchema {
  String get location;
}
