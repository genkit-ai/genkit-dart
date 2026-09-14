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

/// Live tests against xAI's API.
///
/// Grok reasons by default at effort `high`, so a trivial prompt can still take
/// well past package:test's 30-second default. That budget is sized for unit
/// tests, not for a round trip to a thinking model.
///
/// Skipped unless `XAI_API_KEY` is set.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'xai_integration_test.g.dart';

@Schema()
abstract class $CityQuery {
  String get city;
}

@Schema()
abstract class $CityFact {
  String get city;
  String get country;
}

void main() {
  final apiKey = Platform.environment['XAI_API_KEY'];
  final skip = apiKey == null || apiKey.isEmpty ? 'XAI_API_KEY not set' : null;

  Genkit newAi() {
    final ai = Genkit(plugins: [xAI(apiKey: apiKey)]);
    addTearDown(ai.shutdown);
    return ai;
  }

  group('xAI integration', () {
    test('generates text', () async {
      final response = await newAi().generate(
        model: XaiModels.grok46,
        prompt: 'Say "hello" and nothing else.',
      );

      expect(response.text.toLowerCase(), contains('hello'));
    }, skip: skip);

    test('honours maxTokens under the field the plugin sends', () async {
      // The catalog assumes xAI reads OpenAI's `max_completion_tokens`. If it
      // only reads `max_tokens`, the limit is ignored silently and this is the
      // only thing that would say so - the same defect DeepSeek had.
      final response = await newAi().generate(
        model: XaiModels.grok46,
        prompt: 'Write five paragraphs about the sea.',
        config: OpenAIChatOptions(maxTokens: 16),
      );

      expect(response.finishReason, FinishReason.length);
    }, skip: skip);

    test('accepts a JSON schema as a constraint', () async {
      final response = await newAi().generate(
        model: XaiModels.grok46,
        prompt: 'Give me a city and its country.',
        outputFormat: 'json',
        outputSchema: CityFact.$schema,
      );

      expect(response.output?.city, isNotEmpty);
      expect(response.output?.country, isNotEmpty);
    }, skip: skip);

    test('takes a reasoning effort', () async {
      final response = await newAi().generate(
        model: XaiModels.grok46,
        prompt: 'Is 91 prime? Answer yes or no.',
        config: OpenAIChatOptions(reasoningEffort: 'low'),
      );

      expect(response.text, isNotEmpty);
    }, skip: skip);

    test('runs a tool loop', () async {
      final ai = newAi();
      ai.defineTool(
        name: 'getPopulation',
        description: 'Get the population of a city.',
        inputSchema: CityQuery.$schema,
        outputSchema: .integer(),
        fn: (query, _) async => .response(8900000),
      );

      final response = await ai.generate(
        model: XaiModels.grok46,
        prompt: 'Use the tool to get the population of London, then say it.',
        toolNames: ['getPopulation'],
      );

      expect(response.text, contains('8'));
    }, skip: skip);

    test('streams', () async {
      final stream = newAi().generateStream(
        model: XaiModels.grok46,
        prompt: 'Count from one to five.',
      );
      final streamed = StringBuffer();
      await for (final chunk in stream) {
        for (final part in chunk.content) {
          if (part.isText) streamed.write(part.text);
        }
      }

      expect(streamed.toString(), isNotEmpty);
      expect((await stream.onResult).text, isNotEmpty);
    }, skip: skip);

    test('the curated catalog still matches what xAI serves', () async {
      // Asked of the API directly rather than through the plugin: what the
      // plugin lists is the catalog merged with discovery, and the question
      // here is only what the host actually serves.
      final response = await http.get(
        Uri.parse('https://api.x.ai/v1/models'),
        headers: {'authorization': 'Bearer $apiKey'},
      );
      expect(response.statusCode, 200, reason: response.body);

      final served = ((jsonDecode(response.body) as Map)['data'] as List)
          .map((m) => (m as Map)['id'] as String)
          .toSet();

      expect(served, isNotEmpty, reason: 'the host listed no models');
      for (final id in knownXaiChatModels) {
        expect(served, contains(id), reason: '$id is no longer served');
      }
    }, skip: skip);
  });
}
