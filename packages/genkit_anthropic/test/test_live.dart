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
import 'package:genkit_anthropic/src/plugin_impl.dart';
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
  final apiKey = Platform.environment['ANTHROPIC_API_KEY'];

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
      expect(chunks.length, greaterThan(1));
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
        fn: (CalculatorInput input, _) async => input.a * input.b,
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
          // Thinking requires budget if supported
          thinking: ThinkingConfig(budgetTokens: 1024),
        ),
      );
      expect(
        response.message?.content.where((p) => p.isReasoning).length,
        greaterThanOrEqualTo(1),
      );
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}
