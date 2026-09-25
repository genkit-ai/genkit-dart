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

    test('a schema-less tool round-trips', () async {
      // The counterpart to the test above, which declares an inputSchema. A
      // tool without one has to reach OpenAI as a valid empty object schema;
      // this only fails against the real API, which is why it lives here.
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);
      var toolRan = false;
      ai.defineTool(
        name: 'getTime',
        description: 'Returns the current time',
        fn: (input, ctx) async {
          toolRan = true;
          return .response({'time': '12:00'});
        },
      );

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'Use the getTime tool to tell me the current time.',
        toolNames: ['getTime'],
      );

      expect(response.message, isNotNull);
      expect(toolRan, isTrue);
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

      test(
        'schemaless json output returns parseable JSON',
        () async {
          if (apiKey == null || apiKey.isEmpty) {
            fail(
              'OPENAI_API_KEY environment variable must be set to run integration tests',
            );
          }

          // Without a schema Genkit adds no prompt instructions either, so
          // before the json_object fallback nothing asked for JSON at all.
          final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

          final response = await ai.generate(
            model: openAI.model('gpt-4o'),
            prompt:
                'Return a JSON object with keys "name" and "age" for a '
                'person named John Doe aged 30.',
            outputFormat: 'json',
          );

          final decoded = jsonDecode(response.text) as Map<String, dynamic>;
          expect(decoded['name'], isNotNull);
        },
        skip: apiKey == null || apiKey.isEmpty
            ? 'OPENAI_API_KEY not set'
            : null,
      );

      test(
        'an output schema with an optional field is accepted',
        () async {
          if (apiKey == null || apiKey.isEmpty) {
            fail(
              'OPENAI_API_KEY environment variable must be set to run integration tests',
            );
          }

          // Regression test for the old `strict: true`, which made OpenAI
          // reject any schema whose `required` omitted a property. Only the
          // live API can prove this; a mock cannot.
          final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

          final response = await ai.generate(
            model: openAI.model('gpt-4o'),
            prompt: 'A person named John Doe who goes by JD.',
            outputSchema: ProfileSchema.$schema,
          );

          // Asserted field by field rather than through `output!.name`: if
          // the model omits a field, the getter throws a TypeError inside
          // expect() and the test reports a crash instead of the assertion
          // that actually failed.
          expect(response.output, isNotNull);
          final profile = response.output!.toJson();
          expect(profile['name'], isA<String>());
          expect(profile['name'], isNotEmpty);
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

    test('resolves the key from OPENAI_API_KEY when none is passed', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // Note the bare openAI() - no apiKey, no apiKeyProvider. Every other
      // live test passes the key explicitly, so this is the only coverage of
      // the environment fallback actually authenticating a real request.
      final ai = Genkit(plugins: [openAI()]);

      final response = await ai.generate(
        model: openAI.model('gpt-4o-mini'),
        prompt: 'Say "hello" and nothing else.',
      );

      expect(response.text.toLowerCase(), contains('hello'));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('reasoning effort reaches a reasoning model', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      // The mocks prove the parameter reaches the wire; only OpenAI can say
      // whether it accepts the level for this model.
      final response = await ai.generate(
        model: OpenAIModels.o4Mini,
        prompt: 'What is 17 * 23? Answer with the number only.',
        config: OpenAIChatOptions(reasoningEffort: 'low'),
      );

      expect(response.text, contains('391'));
      // Reasoning models bill their thinking separately, so a low effort
      // still shows up in the usage breakdown.
      expect(response.usage?.outputTokens, greaterThan(0));

      await ai.shutdown();
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('verbosity reaches the GPT-5 family', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final response = await ai.generate(
        model: OpenAIModels.gpt5Mini,
        prompt: 'Name the capital of France.',
        config: OpenAIChatOptions(verbosity: 'low', reasoningEffort: 'low'),
      );

      expect(response.text.toLowerCase(), contains('paris'));

      await ai.shutdown();
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('a model that does not reason rejects an effort', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      // The plugin refuses this before the request goes out. The live value
      // of the test is the other half: that OpenAI would have refused it too,
      // so the local check is not inventing a restriction.
      final local = await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );
      expect(local.finishReason, FinishReason.failed);
      expect(local.error?.status, StatusCodes.INVALID_ARGUMENT.name);

      // The same request with the guard bypassed. Naming OpenAI's own URL no
      // longer does it - that is the same host, so the catalog and its checks
      // both apply - but registering the model says more about it than the
      // catalog does, and is left to the API to judge.
      final direct = Genkit(
        plugins: [
          openAI(
            apiKey: apiKey,
            models: [CustomModelDefinition(name: 'gpt-4o')],
          ),
        ],
      );
      final remote = await direct.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(remote.finishReason, FinishReason.failed);
      expect(remote.error?.message, contains('reasoning_effort'));

      await direct.shutdown();
      await ai.shutdown();
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('discovery enriches the curated catalog', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // Offline, list() returns exactly knownChatModels. With a real key it
      // must return strictly more than that - if it does not, discovery has
      // silently stopped running and the offline fallback has swallowed it.
      //
      // Not asserted: that the merged listing contains the catalog. list()
      // merges it in unconditionally, so that holds however discovery went.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final actions = await ai.registry.listActions();
      final names = actions
          .where((a) => a.actionType == .model)
          .map((a) => a.name)
          .toSet();

      // A baseUrl withholds the catalog, so this listing is pure discovery -
      // the only way to see what OpenAI actually serves. An empty overlap
      // means every curated id has been renamed or retired.
      final probe = Genkit(
        plugins: [openAI(apiKey: apiKey, baseUrl: 'https://api.openai.com/v1')],
      );
      final discovered = (await probe.registry.listActions())
          .where((a) => a.actionType == .model)
          .map((a) => a.name)
          .toSet();
      await probe.shutdown();

      expect(
        discovered.intersection(
          knownChatModels.map((id) => 'openai/$id').toSet(),
        ),
        isNotEmpty,
        reason: 'no curated id is served by OpenAI any more',
      );
      expect(
        names.length,
        greaterThan(knownChatModels.length),
        reason: 'discovery should contribute models beyond the catalog',
      );

      // Discovery must not smuggle in non-chat models.
      expect(names.any((n) => n.contains('embedding')), isFalse);
      expect(names.any((n) => n.contains('dall-e')), isFalse);

      await ai.shutdown();
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('embeds documents and honours the dimensions option', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);
      final documents = [
        DocumentData(content: [TextPart(text: 'The cat sat on the mat.')]),
        DocumentData(
          content: [TextPart(text: 'Paris is the capital of France.')],
        ),
      ];

      final full = await ai.embedMany(
        embedder: OpenAIEmbedders.textEmbedding3Small,
        documents: documents,
      );

      // The vector length the catalog claims, checked against the API rather
      // than against the catalog itself.
      expect(full, hasLength(2));
      expect(
        full.first.embedding,
        hasLength(KnownOpenAIEmbedder.textEmbedding3Small.dimensions),
      );

      final shortened = await ai.embed(
        embedder: OpenAIEmbedders.textEmbedding3Small,
        document: documents.first,
        options: OpenAIEmbedderOptions(dimensions: 256),
      );

      expect(shortened.single.embedding, hasLength(256));

      await ai.shutdown();
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

    test('gpt-4o-mini-tts honours speed', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // The OpenAPI spec gives `speed` a 0.25-4.0 range with no model
      // restriction, and faster speech is shorter audio - so the same words at
      // 2x should come back smaller than at 1x.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      Future<int> bytesAt(double? speed) async {
        final response = await ai.generate(
          model: openAI.speechModel('gpt-4o-mini-tts'),
          prompt: 'Genkit Dart now speaks, at whatever pace you ask for.',
          config: OpenAISpeechOptions(voice: 'sage', speed: speed),
        );
        return base64Decode(response.media!.url.split(',').last).length;
      }

      expect(await bytesAt(2.0), lessThan(await bytesAt(1.0)));
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

    test('speech round trip: tts-1 then whisper-1', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // No audio fixtures live in this repo, so the transcription input is
      // generated on the fly by the speech model.
      const sentence = 'The quick brown fox jumps over the lazy dog.';
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: sentence,
        config: OpenAISpeechOptions(voice: 'nova'),
      );
      expect(spoken.media, isNotNull);

      final heard = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(language: 'en'),
      );

      expect(heard.text.toLowerCase(), contains('quick brown fox'));
      expect(heard.text.toLowerCase(), contains('lazy dog'));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('whisper-1 translates non-English audio to English', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'El zorro marron rapido salta sobre el perro perezoso.',
        config: OpenAISpeechOptions(voice: 'nova'),
      );

      final translated = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(translate: true),
      );

      expect(translated.text.toLowerCase(), contains('fox'));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('srt response format returns subtitle markup', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // The SDK path could not do this at all: its create() always
      // JSON-decodes the body.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Genkit Dart now listens.',
      );

      final subtitles = await ai.generate(
        model: openAI.transcriptionModel('whisper-1'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(responseFormat: 'srt'),
      );

      expect(subtitles.text, contains('-->'));
      expect(subtitles.text.trim(), startsWith('1'));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test(
      'verbose_json accepts repeated timestamp granularities',
      () async {
        if (apiKey == null || apiKey.isEmpty) {
          fail(
            'OPENAI_API_KEY environment variable must be set to run integration tests',
          );
        }

        // timestamp_granularities is sent as repeated form fields. No mock can
        // prove OpenAI accepts that encoding, so it is checked here.
        final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

        final spoken = await ai.generate(
          model: openAI.speechModel('tts-1'),
          prompt: 'Genkit Dart now listens.',
        );

        final verbose = await ai.generate(
          model: openAI.transcriptionModel('whisper-1'),
          promptParts: [MediaPart(media: spoken.media!)],
          config: OpenAITranscriptionOptions(
            responseFormat: 'verbose_json',
            timestampGranularities: ['word', 'segment'],
          ),
        );

        expect(verbose.text.toLowerCase(), contains('listens'));
      },
      timeout: Timeout(Duration(minutes: 2)),
      skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null,
    );

    test('gpt-4o-transcribe accepts chunking strategy and include', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // chunking_strategy and include[] are encoded by hand as form fields,
      // the same risk class as timestamp_granularities. Only the live API can
      // confirm the encoding. This is also the only live coverage of the
      // gpt-4o-transcribe family, whose constraints differ from whisper-1.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Genkit Dart handles long audio.',
      );

      final heard = await ai.generate(
        model: openAI.transcriptionModel('gpt-4o-transcribe'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(
          chunkingStrategy: 'auto',
          include: ['logprobs'],
        ),
      );

      expect(heard.text.toLowerCase(), contains('long audio'));
    }, skip: apiKey == null || apiKey.isEmpty ? 'OPENAI_API_KEY not set' : null);

    test('an object chunking strategy is accepted', () async {
      if (apiKey == null || apiKey.isEmpty) {
        fail(
          'OPENAI_API_KEY environment variable must be set to run integration tests',
        );
      }

      // The object form is JSON-encoded into the form field; verifies the
      // server parses it rather than treating it as a literal string.
      final ai = Genkit(plugins: [openAI(apiKey: apiKey)]);

      final spoken = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Server side chunking works.',
      );

      final heard = await ai.generate(
        model: openAI.transcriptionModel('gpt-4o-mini-transcribe'),
        promptParts: [MediaPart(media: spoken.media!)],
        config: OpenAITranscriptionOptions(
          chunkingStrategy: {
            'type': 'server_vad',
            'prefix_padding_ms': 300,
            'silence_duration_ms': 400,
            'threshold': 0.5,
          },
        ),
      );

      expect(heard.text.toLowerCase(), contains('chunking'));
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

/// A schema with an optional field.
///
/// `nickname` is nullable, so schemantic leaves it out of `required` - which
/// is precisely what OpenAI's strict mode rejects. The plugin used to send
/// `strict: true`, so this shape returned a 400.
@Schema()
abstract class $ProfileSchema {
  String get name;
  String? get nickname;
}
