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

/// Live tests against DeepSeek's API.
///
/// The mocked suite in `deepseek_test.dart` proves what the plugin *sends*.
/// These prove DeepSeek accepts it — which is a different question, and the
/// only one that catches the plugin agreeing with a stale reading of the docs.
///
/// Skipped unless `DEEPSEEK_API_KEY` is set.
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'deepseek_integration_test.g.dart';

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
  final apiKey = Platform.environment['DEEPSEEK_API_KEY'];
  final skip = apiKey == null || apiKey.isEmpty
      ? 'DEEPSEEK_API_KEY not set'
      : null;

  Genkit newAi() {
    final ai = Genkit(plugins: [deepSeek(apiKey: apiKey)]);
    addTearDown(ai.shutdown);
    return ai;
  }

  group('DeepSeek integration', () {
    test('generates text', () async {
      final response = await newAi().generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Say "hello" and nothing else.',
      );

      expect(response.text.toLowerCase(), contains('hello'));
    }, skip: skip);

    test('returns its thinking, and honours the effort', () async {
      // The whole point of the body rewrite: DeepSeek reads the effort from
      // inside `thinking`, so if the plugin left it at the top level this
      // would quietly run at the default instead.
      final response = await newAi().generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Is 8051 prime? Think it through, then answer yes or no.',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      final reasoning = response.message?.content
          .where((part) => part.isReasoning)
          .map((part) => part.reasoning ?? '')
          .join();

      expect(reasoning, isNotNull);
      expect(reasoning, isNotEmpty, reason: 'no reasoning_content came back');
      expect(response.text, isNotEmpty);
    }, skip: skip);

    test('streams thinking ahead of the answer', () async {
      // The mocked suite proves the request survives the body rewrite on the
      // streaming path; only a real server proves the reasoning deltas come
      // back and reach the caller as they are produced. DeepSeek is the only
      // provider that exercises this mapping at all.
      final stream = newAi().generateStream(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Is 91 prime? Think it through, then answer yes or no.',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      var firstReasoning = -1;
      var firstText = -1;
      var index = 0;
      await for (final chunk in stream) {
        for (final part in chunk.content) {
          if (part.isReasoning && firstReasoning < 0) firstReasoning = index;
          if (part.isText && firstText < 0) firstText = index;
        }
        index++;
      }
      final response = await stream.onResult;

      expect(
        firstReasoning,
        greaterThanOrEqualTo(0),
        reason: 'no reasoning streamed',
      );
      expect(firstText, greaterThanOrEqualTo(0), reason: 'no text streamed');
      expect(
        firstReasoning,
        lessThan(firstText),
        reason: 'thinking should arrive before the answer it produced',
      );
      expect(response.text, isNotEmpty);
    }, skip: skip);

    test('an effort of none turns thinking off', () async {
      final response = await newAi().generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'What is 2 + 2? Answer with the number only.',
        config: OpenAIChatOptions(reasoningEffort: 'none'),
      );

      expect(response.text, contains('4'));
      expect(
        response.message?.content.any((part) => part.isReasoning) ?? false,
        isFalse,
        reason: 'thinking was asked to be off but reasoning came back',
      );
    }, skip: skip);

    test('honours maxTokens, which needs the older field name', () async {
      // The defect this branch fixes: sent as `max_completion_tokens` the
      // limit is ignored silently, and the answer runs to its natural end.
      final response = await newAi().generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Write five paragraphs about the sea.',
        config: OpenAIChatOptions(reasoningEffort: 'none', maxTokens: 16),
      );

      expect(response.finishReason, FinishReason.length);
    }, skip: skip);

    test('produces structured output without a schema on the wire', () async {
      // DeepSeek has no json_schema, so this exercises json_object plus the
      // schema the plugin puts in the prompt.
      final response = await newAi().generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Give me a city and its country.',
        outputFormat: 'json',
        outputSchema: CityFact.$schema,
      );

      expect(response.output?.city, isNotEmpty);
      expect(response.output?.country, isNotEmpty);
    }, skip: skip);

    test('runs a tool loop, replaying its thinking', () async {
      // With tools, DeepSeek expects previous turns' reasoning_content back or
      // it loses the thread. A loop that completes is the evidence that the
      // replayed field is accepted rather than rejected.
      final ai = newAi();
      // The input schema has to be an object: OpenAI-shaped APIs take tool
      // parameters as a JSON Schema object, and the converter rejects
      // anything else before the request is built.
      ai.defineTool(
        name: 'getPopulation',
        description: 'Get the population of a city.',
        inputSchema: CityQuery.$schema,
        outputSchema: .integer(),
        fn: (query, _) async => .response(8900000),
      );

      final response = await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Use the tool to get the population of London, then say it.',
        toolNames: ['getPopulation'],
      );

      expect(response.text, contains('8'));
    }, skip: skip);

    test('the curated catalog still matches what DeepSeek serves', () async {
      // The lineup moved once already: deepseek-chat and deepseek-reasoner
      // were the whole catalog until 2026. A stable id the API no longer
      // lists is a catalog entry that needs retiring.
      //
      // The `/v1` spelling is the same host, but it differs from the
      // provider's default, so the curated catalog is withheld and this is
      // pure discovery.
      final probe = Genkit(
        plugins: [
          deepSeek(apiKey: apiKey, baseUrl: 'https://api.deepseek.com/v1'),
        ],
      );
      addTearDown(probe.shutdown);

      final discovered = (await probe.registry.listActions())
          .where((a) => a.actionType == .model)
          .map((a) => a.name.split('/').last)
          .toSet();

      expect(discovered, isNotEmpty, reason: 'discovery returned nothing');

      final stable = KnownDeepSeekModel.values
          .where((m) => m.stage == OpenAIModelStage.stable)
          .map((m) => m.id);
      for (final id in stable) {
        expect(discovered, contains(id), reason: '$id is no longer served');
      }
    }, skip: skip);
  });
}
