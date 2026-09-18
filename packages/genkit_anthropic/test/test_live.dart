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
import 'package:genkit_anthropic/src/known_models.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'test_live.g.dart';

@Schema()
abstract class $Person {
  String get name;
  int get age;
}

@Schema()
abstract class $CalculatorInput {
  int get a;
  int get b;
}

void main() {
  // Check if API key is available
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];

  // Without this the suite still runs, and every call comes back as an empty
  // `failed` response rather than an error - `generate` resolves model
  // failures instead of throwing - so the whole file fails on unrelated
  // assertions that say nothing about the missing key.
  if (apiKey == null) {
    print('Skipping live tests: ANTHROPIC_API_KEY is not set');
    return;
  }

  group('Anthropic Integration', () {
    late Genkit ai;
    AnthropicPluginImpl? plugin;

    setUp(() {
      plugin = AnthropicPluginImpl(apiKey: apiKey);
      ai = Genkit(plugins: [plugin!]);
    });

    tearDown(() {
      plugin?.close();
    });

    test('should generate simple text', () async {
      final flow = ai.defineFlow(
        name: 'testSimple',
        inputSchema: .string(),
        outputSchema: .string(),
        fn: (input, _) async {
          final response = await ai.generate(
            model: anthropic.model('claude-sonnet-4-5'),
            prompt: 'Say hello to $input',
            config: AnthropicOptions(temperature: 0),
          );
          return response.text;
        },
      );

      final result = await flow('World');
      expect(result, contains('Hello'));
    });

    test('should stream text', () async {
      final response = ai.generateStream(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'Count to 5',
      );

      final chunks = await response.toList();
      expect(chunks, isNotEmpty);
      final fullText = chunks.map((c) => c.text).join();
      expect(fullText, contains('5'));

      final finalResponse = await response.onResult;
      expect(finalResponse.text, contains('5'));
    });

    test('should generate structured output', () async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'Generate a person named John Doe, age 30',
        outputSchema: Person.$schema,
      );

      expect(response.output, isNotNull);
      expect(response.output!.name, 'John Doe');
      expect(response.output!.age, 30);
    });

    // Discovered rather than hard-coded. This needs a model Anthropic still
    // serves that is absent from [KnownClaudeModel], and a literal satisfies
    // only the second half - names retire, and the test then fails on a 404
    // that says nothing about constrained generation. Asking the catalog
    // keeps both halves true as it moves.
    String? uncuratedModel;
    var searchedCatalog = false;

    /// The cheapest live model that declares no native constrained generation,
    /// or null when every model Anthropic serves is curated here.
    Future<String?> findUncuratedModel() async {
      if (searchedCatalog) return uncuratedModel;
      searchedCatalog = true;

      final names = (await plugin!.list())
          .where((a) => a.actionType == ActionType.model)
          .map((a) => a.name.split('/').last)
          .where((name) => knownClaudeModelFor(name) == null)
          .toList();

      // Haiku first purely to keep the bill down; any of them exercises the
      // same path.
      names.sort((a, b) {
        int rank(String n) => n.contains('haiku') ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
      return uncuratedModel = names.firstOrNull;
    }

    test('simulates constrained generation for an uncurated model', () async {
      final model = await findUncuratedModel();
      if (model == null) {
        markTestSkipped('every live Anthropic model is curated here');
        return;
      }
      expect(
        plugin!.modelInfoFor(model).supports,
        isNot(contains('constrained')),
        reason: 'the fallback claims constrained support; nothing to simulate',
      );

      // No native schema reaches Anthropic: core strips it and puts the shape
      // in the prompt, and the plugin's forced `return_output` tool is
      // unreachable without `output.schema`. So this is the injected
      // instructions and nothing else.
      final response = await ai.generate(
        model: anthropic.model(model),
        prompt: 'Generate a person named John Doe, age 30',
        outputSchema: Person.$schema,
      );

      // The raw text is the only diagnostic worth having here: a null output
      // means the model answered something `extractJson` could not read, and
      // the difference between prose, a fenced block and an empty turn is the
      // whole question.
      expect(
        response.output,
        isNotNull,
        reason:
            'no parseable output. finishReason=${response.finishReason}, '
            'error=${response.error}, text="${response.text}"',
      );
      expect(response.output!.name, 'John Doe');
      expect(response.output!.age, 30);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('streams simulated constrained generation', () async {
      final model = await findUncuratedModel();
      if (model == null) {
        markTestSkipped('every live Anthropic model is curated here');
        return;
      }

      final response = ai.generateStream(
        model: anthropic.model(model),
        prompt: 'Generate a person named Jane Doe, age 25',
        outputSchema: Person.$schema,
      );

      final finalResponse = await response.onResult;
      expect(
        finalResponse.output,
        isNotNull,
        reason:
            'no parseable output. finishReason=${finalResponse.finishReason}, '
            'error=${finalResponse.error}, text="${finalResponse.text}"',
      );
      expect(finalResponse.output!.name, 'Jane Doe');
      expect(finalResponse.output!.age, 25);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('should stream structured output', () async {
      final response = ai.generateStream(
        model: anthropic.model('claude-sonnet-4-5'),
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
        fn: (CalculatorInput input, _) async => .response(input.a * input.b),
      );

      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'What is 123 * 456?',
        tools: [tool],
      );

      expect(response.text, contains('56,088')); // 123*456 = 56088
      expect(response.messages.map((m) => m.role), [
        'user',
        'model',
        'tool',
        'model',
      ]);
    });

    test('should support thinking', () async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'Solve this 24 game: 2, 3, 10, 10',
        config: AnthropicOptions(
          thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        ),
      );
      expect(
        response.message?.content.where((p) => p.isReasoning).length,
        greaterThanOrEqualTo(1),
      );
    }, timeout: Timeout(Duration(minutes: 2)));

    test('should replay thinking blocks through a tool loop', () async {
      // Regression test for #353. The second turn re-sends the assistant's
      // thinking block, whose signature Anthropic verifies server-side - the
      // one thing the wire tests cannot check. Before the fix the block was
      // dropped and this request failed.
      final tool = ai.defineTool(
        name: 'calculator',
        description: 'Multiplies two numbers',
        inputSchema: CalculatorInput.$schema,
        outputSchema: .integer(),
        fn: (CalculatorInput input, _) async => .response(input.a * input.b),
      );

      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-4-5'),
        prompt: 'What is 123 * 456? Use the calculator tool.',
        tools: [tool],
        config: AnthropicOptions(
          thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        ),
      );

      expect(response.text, contains('56,088'));
      expect(response.messages.map((m) => m.role), [
        'user',
        'model',
        'tool',
        'model',
      ]);

      // The replayed turn must have carried a signed thinking block.
      final replayed = response.messages[1].content.where((p) => p.isReasoning);
      expect(replayed, isNotEmpty);
      expect(
        replayed.first.metadata?['thoughtSignature'],
        isA<String>().having((s) => s.isNotEmpty, 'is not empty', isTrue),
      );
    }, timeout: Timeout(Duration(minutes: 2)));

    test('should use adaptive thinking for newer models', () async {
      final response = await ai.generate(
        model: anthropic.model('claude-sonnet-5'),
        prompt: 'What is 17 * 19? Answer briefly.',
        config: AnthropicOptions(
          maxTokens: 512,
          thinking: ThinkingConfig(),
          outputConfig: AnthropicOutputConfig(effort: 'low'),
        ),
      );
      expect(response.text, isNotEmpty);
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
