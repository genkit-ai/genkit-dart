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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'integration_test.g.dart';

void main() {
  final apiKey = Platform.environment['OPENAI_API_KEY'];

  group('Integration Tests', () {
    test('generates text with GPT-4o', () async {
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
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('generates text with custom options', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Write a haiku about Dart.',
        config: OpenAIChatOptions(temperature: 0.7, maxTokens: 100),
      );

      expect(response.text, isNotEmpty);
      expect(response.text.length, lessThan(200));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('streaming generation', () async {
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
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('tool calling', () async {
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
          return .response({'temperature': 72, 'condition': 'sunny'});
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
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('o-series tool calling executes the tool', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      var toolRan = false;
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        inputSchema: WeatherInputSchema.$schema,
        fn: (input, ctx) async {
          toolRan = true;
          return .response({'temperature': 72, 'condition': 'sunny'});
        },
      );

      final response = await ai.generate(
        model: openAI.model('o4-mini'),
        prompt: 'Use the getWeather tool to find the weather in Boston.',
        toolNames: ['getWeather'],
      );

      expect(response.message, isNotNull);
      // Unlike the tolerant gpt-4o test above, this asserts the tool actually
      // executed: with tools silently stripped (bug #357) o-series models
      // hallucinate a JSON tool call as plain text and the tool never runs.
      expect(
        toolRan,
        isTrue,
        reason: 'getWeather must actually execute for o4-mini',
      );
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    group('Structured output', () {
      test(
        'non-streaming: outputSchema parses response to schema type',
        () async {
          if (apiKey == null || apiKey.isEmpty) {
            fail(
              'OPENAI_API_KEY environment variable must be set to run integration tests',
            );
          }

          final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

          final response = await ai.generate(
            model: openAI.model('gpt-4o'),
            prompt: 'Generate a person named John Doe, age 30',
            outputSchema: PersonSchema.$schema,
          );

          expect(response.output, isNotNull);
          expect(response.output, isA<PersonSchema>());
          expect(response.output!.name, 'John Doe');
          expect(response.output!.age, 30);
        },
        skip: apiKey == null || apiKey.isEmpty
            ? 'OPENAI_API_KEY not set'
            : null,
      );

      test(
        'streaming: outputSchema parses streamed response to schema type',
        () async {
          if (apiKey == null || apiKey.isEmpty) {
            fail(
              'OPENAI_API_KEY environment variable must be set to run integration tests',
            );
          }

          final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

          final response = ai.generateStream(
            model: openAI.model('gpt-4o'),
            prompt: 'Generate a person named Jane Doe, age 25',
            outputSchema: PersonSchema.$schema,
          );

          final finalResponse = await response.onResult;
          expect(finalResponse.output, isNotNull);
          expect(finalResponse.output, isA<PersonSchema>());
          expect(finalResponse.output!.name, 'Jane Doe');
          expect(finalResponse.output!.age, 25);
        },
        skip: apiKey == null || apiKey.isEmpty
            ? 'OPENAI_API_KEY not set'
            : null,
      );
    });

    test('multi-turn conversation', () async {
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
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('reports token usage for non-streaming and streaming', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Say hello.',
      );
      expect(response.usage?.inputTokens, greaterThan(0));
      expect(response.usage?.outputTokens, greaterThan(0));
      expect(response.usage?.totalTokens, greaterThan(0));

      final stream = ai.generateStream(
        model: openAI.model('gpt-4o'),
        prompt: 'Say hello.',
      );
      await for (final _ in stream) {}
      final result = await stream.onResult;
      expect(result.usage?.inputTokens, greaterThan(0));
      expect(result.usage?.outputTokens, greaterThan(0));
      expect(result.usage?.totalTokens, greaterThan(0));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('generates speech with gpt-4o-mini-tts', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: openAI.speechModel('gpt-4o-mini-tts'),
        prompt: 'Genkit is an amazing AI framework.',
        config: OpenAISpeechOptions(
          voice: 'sage',
          instructions: 'Speak in a calm, warm tone.',
        ),
      );

      final media = response.media;
      expect(media, isNotNull);
      expect(media!.contentType, 'audio/mpeg');
      expect(media.url, startsWith('data:audio/mpeg;base64,'));

      final bytes = base64Decode(media.url.split(',').last);
      expect(bytes, isNotEmpty);
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('gpt-4o-mini-tts tolerates speed being set', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // gpt-4o-mini-tts rejects `speed`, so the plugin strips it. This guards
      // that assumption from both directions: if OpenAI starts accepting the
      // field, dropping it silently discards a caller's setting; if it still
      // rejects it, a regression that stopped stripping would 400 here.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: openAI.speechModel('gpt-4o-mini-tts'),
        prompt: 'Speed should be ignored for this model.',
        config: OpenAISpeechOptions(voice: 'sage', speed: 1.5),
      );

      expect(response.media, isNotNull);
      expect(base64Decode(response.media!.url.split(',').last), isNotEmpty);
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('responseFormat wav returns real WAV bytes', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // contentType is derived from the requested format rather than from the
      // response, so this checks the bytes really are what we label them.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Genkit Dart now speaks.',
        config: OpenAISpeechOptions(
          voice: 'nova',
          responseFormat: 'wav',
          speed: 1.1,
        ),
      );

      final media = response.media;
      expect(media, isNotNull);
      expect(media!.contentType, 'audio/wav');

      final bytes = base64Decode(media.url.split(',').last);
      expect(bytes.length, greaterThan(12));
      // RIFF....WAVE container magic.
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);
  });
}

// Simple schema for weather tool input
@Schema()
abstract class $WeatherInputSchema {
  String get location;
}

@Schema()
abstract class $PersonSchema {
  String get name;
  int get age;
}
