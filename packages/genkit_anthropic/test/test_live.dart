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
abstract class $Record {
  String get name;
  dynamic get extra;
}

@Schema()
abstract class $Scorecard {
  String get name;
  Map<String, int> get scores;
}

@Schema()
abstract class $CalculatorInput {
  int get a;
  int get b;
}

void main() {
  // Check if API key is available
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];

  // Skipped rather than an early `return`: a `return` here registers no
  // tests at all, so `dart test test/test_live.dart` without the key exits
  // 79 ("no tests ran") instead of reporting a clean skip. Without either
  // guard, the suite would still run and every call would come back as an
  // empty `failed` response rather than an error - `generate` resolves model
  // failures instead of throwing - so the whole file would fail on unrelated
  // assertions that say nothing about the missing key.
  group(
    'Anthropic Integration',
    skip: apiKey == null ? 'ANTHROPIC_API_KEY is not set' : null,
    () {
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

      // Any real model absent from [KnownClaudeModel] works here; it is
      // swapped freely as Anthropic's catalog moves. The test asserts that
      // premise rather than trusting it, because a name that quietly became
      // curated would leave this exercising the native path and still
      // passing.
      const uncuratedModel = 'claude-3-5-haiku-latest';

      test('simulates constrained generation for an uncurated model', () async {
        expect(
          knownClaudeModelFor(uncuratedModel),
          isNull,
          reason: '$uncuratedModel is curated now; pick another name',
        );
        expect(
          plugin!.modelInfoFor(uncuratedModel).supports,
          isNot(contains('constrained')),
          reason:
              'the fallback claims constrained support; nothing to simulate',
        );

        // No native schema reaches Anthropic: core strips it and puts the
        // shape in the prompt, and the plugin's forced `return_output` tool is
        // unreachable without `output.schema`. So this is the injected
        // instructions and nothing else.
        final response = await ai.generate(
          model: anthropic.model(uncuratedModel),
          prompt: 'Generate a person named John Doe, age 30',
          outputSchema: Person.$schema,
        );

        expect(response.output, isNotNull);
        expect(response.output!.name, 'John Doe');
        expect(response.output!.age, 30);
      }, timeout: Timeout(Duration(minutes: 2)));

      test('streams simulated constrained generation', () async {
        final response = ai.generateStream(
          model: anthropic.model(uncuratedModel),
          prompt: 'Generate a person named Jane Doe, age 25',
          outputSchema: Person.$schema,
        );

        final finalResponse = await response.onResult;
        expect(finalResponse.output, isNotNull);
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

      test('composes structured output with manual thinking', () async {
        // On the default surface, and with no beta header: this is what says
        // `output_config.format` needs neither. The forced `return_output`
        // tool it replaced could not do this at all - Anthropic rejects a
        // pinned tool_choice alongside extended thinking.
        final response = await ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'Generate a person named John Doe, age 30',
          outputSchema: Person.$schema,
          config: AnthropicOptions(
            thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
          ),
        );

        expect(response.output, isNotNull);
        expect(response.output!.name, 'John Doe');
        expect(response.output!.age, 30);
      }, timeout: Timeout(Duration(minutes: 2)));

      test('composes structured output with the caller\'s tools', () async {
        // The other thing the forced tool made impossible: pinning
        // `tool_choice` to `return_output` left the caller's tools
        // unreachable, so core had to simulate whenever a request carried any.
        // An object input schema: Anthropic rejects anything else with
        // "tools.0.custom.input_schema.type: Input should be 'object'".
        final tool = ai.defineTool(
          name: 'ageOf',
          description: 'Returns the age of a person by name',
          inputSchema: CalculatorInput.$schema,
          outputSchema: .integer(),
          fn: (CalculatorInput input, _) async => .response(30),
        );

        final response = await ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'Look up the age of John Doe with the tool, then return him.',
          tools: [tool],
          outputSchema: Person.$schema,
        );

        expect(response.output, isNotNull);
        expect(response.output!.name, contains('John'));
        expect(response.output!.age, 30);
      }, timeout: Timeout(Duration(minutes: 2)));

      test('still serves structured output on the beta surface', () async {
        // The field is served on both, so naming beta must not change it.
        final response = ai.generateStream(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'Generate a person named Jane Doe, age 25',
          outputSchema: Person.$schema,
          config: AnthropicOptions(apiVersion: 'beta'),
        );

        final finalResponse = await response.onResult;
        expect(finalResponse.output, isNotNull);
        expect(finalResponse.output!.name, 'Jane Doe');
        expect(finalResponse.output!.age, 25);
      }, timeout: Timeout(Duration(minutes: 2)));

      test('a dynamic field survives, as the value it is', () async {
        // `{}` cannot be sent as a constraint, so the schema goes in the
        // prompt. The point of that choice over a concrete rewrite: `extra`
        // comes back as an object, not as a string of JSON.
        final response = await ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt:
              'Return a record named Ada whose extra is the nested object '
              '{"city": "London"}.',
          outputSchema: Record.$schema,
        );

        expect(response.output, isNotNull);
        expect(response.output!.name, contains('Ada'));
        expect(response.output!.extra, isA<Map<String, dynamic>>());
        expect((response.output!.extra as Map)['city'], 'London');
      }, timeout: Timeout(Duration(minutes: 2)));

      test('a map field comes back populated', () async {
        // `additionalProperties` may only be `false` natively, which would
        // close the map and leave the model able to answer only `{}`. The
        // prompt fallback is what keeps the entries.
        final response = await ai.generate(
          model: anthropic.model('claude-sonnet-4-5'),
          prompt: 'Return a scorecard for Ada with scores maths=90, art=70.',
          outputSchema: Scorecard.$schema,
        );

        expect(response.output, isNotNull);
        expect(response.output!.scores, isNotEmpty);
        expect(response.output!.scores['maths'], 90);
      }, timeout: Timeout(Duration(minutes: 2)));

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
        final replayed = response.messages[1].content.where(
          (p) => p.isReasoning,
        );
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
    },
  );
}
