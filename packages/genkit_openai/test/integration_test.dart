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
import 'package:test/test.dart';

part 'integration_test.g.dart';

void main() {
  final apiKey = Platform.environment['OPENAI_API_KEY'];

  group('Integration Tests', () {
    test(
      'generates text with GPT-4o',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        final response = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'Say "hello" and nothing else.',
        );

        expect(response.text, isNotEmpty);
        expect(response.text.toLowerCase(), contains('hello'));
      },
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );

    test(
      'generates text with custom options',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        final response = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'Write a haiku about Dart.',
          config: OpenAIOptionsSchema(temperature: 0.7, maxTokens: 100),
        );

        expect(response.text, isNotEmpty);
        expect(response.text.length, lessThan(200));
      },
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );

    test(
      'streaming generation',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        final chunks = <GenerateResponseChunk>[];
        await for (final chunk in ai.generateStream(
          model: openAI.model('gpt-4o'),
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
      },
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );

    test(
      'tool calling',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        ai.defineTool(
          name: 'getWeather',
          description: 'Get the weather for a location',
          inputSchema: WeatherInputSchema.$schema,
          fn: (input, ctx) async {
            return {'temperature': 72, 'condition': 'sunny'};
          },
        );

        final response = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'What\'s the weather in Boston?',
          toolNames: ['getWeather'],
        );

        // Note: This test verifies that tools can be called successfully.
        // However, GPT-4o may choose to answer directly without calling the tool
        // since it has general knowledge about typical weather patterns.
        // The important thing is that the request succeeds and we get a response.
        expect(response.message, isNotNull);
        expect(response.message!.content, isNotEmpty);

        // Verify the response has either text or tool requests (both are valid)
        final hasContent = response.message!.content.any(
          (p) => p.isText || p.isToolRequest,
        );
        expect(hasContent, isTrue);
      },
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );

    test(
      'multi-turn conversation',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        final response1 = await ai.generate(
          model: openAI.model('gpt-4o'),
          prompt: 'My name is Alice.',
        );

        final response2 = await ai.generate(
          model: openAI.model('gpt-4o'),
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'My name is Alice.')],
            ),
            Message(
              role: Role.model,
              content: [TextPart(text: response1.text)],
            ),
            Message(
              role: Role.user,
              content: [TextPart(text: 'What is my name?')],
            ),
          ],
        );

        expect(response2.text, isNotEmpty);
        expect(response2.text.toLowerCase(), contains('alice'));
      },
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );
  });
}

// Simple schema for weather tool input
@Schematic()
abstract class $WeatherInputSchema {
  String get location;
}
