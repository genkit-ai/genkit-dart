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

import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/generate.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:test/test.dart';

part 'formats_test.schema.g.dart';

@GenkitSchema()
abstract class TestObjectSchema {
  String get foo;
  int get bar;
}

void main() {
  group('formats', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('parses json output', () async {
      genkit.defineModel(
        name: 'jsonModel',
        fn: (req, ctx) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{"foo": "baz", "bar": 123}')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('jsonModel'),
        prompt: 'hi',
        output: GenerateOutput(format: 'json'),
      );

      expect(response.output, equals({'foo': 'baz', 'bar': 123}));
    });

    test('injects instructions for schema', () async {
      String? receivedInstructions;
      genkit.defineModel(
        name: 'instructionModel',
        fn: (req, ctx) async {
          for (final m in req.messages) {
            for (final p in m.content) {
              if (p.toJson().containsKey('text') &&
                  (p as TextPart).metadata?['purpose'] == 'output') {
                receivedInstructions = p.text;
              }
            }
          }
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{}')],
            ),
          );
        },
      );

      await genkit.generate(
        model: modelRef('instructionModel'),
        prompt: 'hi',
        output: GenerateOutput(schema: TestObjectType),
      );

      expect(receivedInstructions, contains('Output should be in JSON format'));
      expect(receivedInstructions, contains('"foo"'));
    });

    test('defaults to json format when schema is present', () async {
      // verify that format is automatically set to json if not provided but schema is
      genkit.defineModel(
        name: 'defaultJsonModel',
        fn: (req, ctx) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{"a": 1}')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('defaultJsonModel'),
        prompt: 'hi',
        output: GenerateOutput(schema: TestObjectType),
      );

      expect(response.output, equals({'a': 1}));
    });
  });
}
