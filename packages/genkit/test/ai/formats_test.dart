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
import 'package:genkit/src/ai/formatters/formatters.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'formats_test.schema.g.dart';

@Schematic()
abstract class TestObjectSchema {
  String get foo;
  int get bar;
}

void main() {
  group('formats', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
      defineFormat(
        genkit.registry,
        Formatter(
          name: 'banana',
          config: GenerateActionOutputConfig({
            'format': null,
            'constrained': false,
          }),
          handler: (schema) {
            String? instructions = 'Output should be in banana format';
            return FormatterHandlerResult(
              parseMessage: (message) {
                final text = message.content
                    .where((p) => p.isText)
                    .map((p) => p.text)
                    .join();
                return 'banana: $text';
              },
              parseChunk: (chunk) {
                final text = chunk.content
                    .where((p) => p.isText)
                    .map((p) => p.text)
                    .join();
                return 'banana chunk: $text';
              },
              instructions: instructions,
            );
          },
        ),
      );
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
        outputFormat: 'json',
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
              if (p.isText && p.metadata?['purpose'] == 'output') {
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
        outputSchema: TestObjectType,
      );

      expect(receivedInstructions, contains('Output should be in JSON format'));
      expect(receivedInstructions, contains('"foo"'));
    });

    test('defaults to json format when schema is present', () async {
      genkit.defineModel(
        name: 'defaultJsonModel',
        fn: (req, ctx) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{"foo": "bar", "bar": 1}')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('defaultJsonModel'),
        prompt: 'hi',
        outputSchema: TestObjectType,
      );

      expect(response.output, isA<TestObject>());
      expect(response.output!.toJson(), equals({'foo': 'bar', 'bar': 1}));
    });

    test('lets you define and use a custom output format', () async {
      ModelRequest? capturedRequest;
      genkit.defineModel(
        name: 'echoModel',
        fn: (req, ctx) async {
          capturedRequest = req;
          final text = req.messages.last.content.first.isText
              ? req.messages.last.content.first.text!
              : '';
          ctx.sendChunk(
            ModelResponseChunk.from(content: [TextPart.from(text: 'chunk 1')]),
          );
          ctx.sendChunk(
            ModelResponseChunk.from(content: [TextPart.from(text: 'chunk 2')]),
          );
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: 'Echo: $text')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('echoModel'),
        prompt: 'hi',
        outputFormat: 'banana',
      );

      expect(response.output, 'banana: Echo: hi');
      expect(capturedRequest?.output?.format, 'banana');
      expect(capturedRequest?.output?.constrained, false);

      final streamResponse = genkit.generateStream(
        model: modelRef('echoModel'),
        prompt: 'hi',
        outputFormat: 'banana',
      );

      final chunks = (await streamResponse.toList())
          .map((c) => c.output)
          .toList();
      expect(chunks, ['banana chunk: chunk 1', 'banana chunk: chunk 2']);

      // Simulation of echo chunks isn't implemented in the model, it returns single response.
      // But we can check the final result from the stream future.
      final finalResult = await streamResponse.onResult;
      expect(finalResult.output, 'banana: Echo: hi');
    });

    test('overrides format options with explicit output options', () async {
      ModelRequest? capturedRequest;
      genkit.defineModel(
        name: 'echoModel',
        fn: (req, ctx) async {
          capturedRequest = req;
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: 'Echo: hi')],
            ),
          );
        },
      );

      await genkit.generate(
        model: modelRef('echoModel'),
        prompt: 'hi',
        outputFormat: 'banana',
        outputConstrained: false,
      );

      expect(capturedRequest?.output?.format, 'banana');
      expect(capturedRequest?.output?.constrained, false);

      // Verify instructions were injected (because schema was provided)
      final messages = capturedRequest?.messages;
      final hasInstructions = messages?.any(
        (m) => m.content.any(
          (p) =>
              p.isText &&
              p.metadata?['purpose'] == 'output' &&
              p.text!.contains('Output should be in banana format'),
        ),
      );
      expect(hasInstructions, isTrue);
    });

    test('respects outputNoInstructions', () async {
      ModelRequest? capturedRequest;
      genkit.defineModel(
        name: 'echoModel',
        fn: (req, ctx) async {
          capturedRequest = req;
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: 'Echo: hi')],
            ),
          );
        },
      );

      await genkit.generate(
        model: modelRef('echoModel'),
        prompt: 'hi',
        outputFormat: 'banana',
        outputNoInstructions: true,
      );

      // Verify instructions were NOT injected even though schema was provided and format has instructions
      final messages = capturedRequest?.messages;
      final hasInstructions = messages?.any(
        (m) => m.content.any(
          (p) => p.isText && p.metadata?['purpose'] == 'output',
        ),
      );
      expect(hasInstructions, isFalse);
    });

    test('skips instruction injection if already present', () async {
      ModelRequest? capturedRequest;
      genkit.defineModel(
        name: 'echoModel',
        fn: (req, ctx) async {
          capturedRequest = req;
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{}')],
            ),
          );
        },
      );

      final manualInstructions = Message.from(
        role: Role.user,
        content: [
          TextPart.from(
            text: 'Manual instructions',
            metadata: {'purpose': 'output'},
          ),
        ],
      );

      await genkit.generate(
        model: modelRef('echoModel'),
        messages: [
          Message.from(
            role: Role.user,
            content: [TextPart.from(text: 'hi')],
          ),
          manualInstructions,
        ],
        outputSchema: TestObjectType,
      );

      final messages = capturedRequest?.messages;
      final instructionParts = messages
          ?.expand((m) => m.content)
          .where((p) => p.isText && p.metadata?['purpose'] == 'output')
          .toList();

      expect(instructionParts?.length, 1);
      expect(instructionParts!.first.text!, 'Manual instructions');
    });

    test('parses partial json chunks', () async {
      genkit.defineModel(
        name: 'streamingJsonModel',
        fn: (req, ctx) async {
          ctx.sendChunk(
            ModelResponseChunk.from(content: [TextPart.from(text: '{"a":')]),
          );
          ctx.sendChunk(
            ModelResponseChunk.from(content: [TextPart.from(text: ' 1,')]),
          );
          ctx.sendChunk(
            ModelResponseChunk.from(content: [TextPart.from(text: '"b": 2}')]),
          );
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: '{"a": 1, "b": 2}')],
            ),
          );
        },
      );

      final stream = genkit.generateStream(
        model: modelRef('streamingJsonModel'),
        prompt: 'hi',
        outputFormat: 'json',
      );

      final chunks = await stream.toList();
      final outputs = chunks.map((c) => c.jsonOutput).toList();

      expect(outputs.length, 3);
      // Chunk 1: '{"a":' -> repaired to {"a": null}
      expect(outputs[0], equals({'a': null}));
      // Chunk 2: '{"a": 1,' -> repaired to {"a": 1}
      expect(outputs[1], equals({'a': 1}));
      // Chunk 3: '{"a": 1, "b": 2}' -> valid
      expect(outputs[2], equals({'a': 1, 'b': 2}));
    });
  });
}
