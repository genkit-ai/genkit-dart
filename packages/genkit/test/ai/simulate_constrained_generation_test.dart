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

import 'package:genkit/genkit.dart';
import 'package:genkit/lite.dart' as lite;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'simulate_constrained_generation_test.g.dart';

@Schema()
abstract class $Person {
  String get name;
  int get age;
}

/// The instruction part the middleware writes, if the model got one.
String? outputInstructionOf(ModelRequest request) {
  for (final message in request.messages) {
    for (final part in message.content) {
      if (part.isText && part.metadata?['purpose'] == 'output') {
        return part.text;
      }
    }
  }
  return null;
}

ModelResponse _personResponse(String text) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [TextPart(text: text)],
  ),
);

void main() {
  late Genkit genkit;
  late ModelRequest captured;

  /// Registers a model recording the request it was handed. [info] is
  /// optional: the middleware must not care what the model declares.
  void defineCapturingModel(String name, {ModelInfo? info}) {
    genkit.defineModel(
      name: name,
      info: info,
      fn: (req, ctx) async {
        captured = req;
        return _personResponse('{"name": "Ada", "age": 36}');
      },
    );
  }

  setUp(() {
    genkit = Genkit();
  });

  tearDown(() async {
    await genkit.shutdown();
  });

  group('without the middleware', () {
    test('a model that declares nothing gets the schema natively', () async {
      defineCapturingModel('undeclared');

      await genkit.generate(
        model: modelRef('undeclared'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      // Core adds no fallback of its own: what happens to the schema is up
      // to the plugin.
      expect(captured.output?.schema, isNotNull);
      expect(captured.output?.constrained, isTrue);
      expect(outputInstructionOf(captured), isNull);
    });

    test('a model declaring no support is not simulated for either', () async {
      defineCapturingModel(
        'declaresNone',
        info: ModelInfo(supports: {'constrained': 'none'}),
      );

      await genkit.generate(
        model: modelRef('declaresNone'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(captured.output?.schema, isNotNull);
      expect(outputInstructionOf(captured), isNull);
    });

    test('a direct model call is untouched', () async {
      defineCapturingModel('direct');

      final model =
          await genkit.registry.lookupAction(.model, 'direct') as Model?;
      await model!(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'Describe a person.')],
            ),
          ],
          output: OutputConfig(
            constrained: true,
            format: 'json',
            schema: Person.$schema.jsonSchema(),
          ),
        ),
      );

      expect(captured.output?.schema, isNotNull);
      expect(outputInstructionOf(captured), isNull);
    });
  });

  group('with the middleware', () {
    test('the schema goes in the prompt instead of the request', () async {
      defineCapturingModel('simulated');

      await genkit.generate(
        model: modelRef('simulated'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      expect(outputInstructionOf(captured), contains('"name"'));
      expect(outputInstructionOf(captured), contains('JSON'));
      // `schema` matters as much as `constrained`: several plugins send a
      // native schema whenever `output.schema` is set.
      expect(captured.output?.schema, isNull);
      expect(captured.output?.constrained, isFalse);
    });

    test('applies whatever the model declares', () async {
      defineCapturingModel(
        'claimsNative',
        info: ModelInfo(supports: {'constrained': true}),
      );

      await genkit.generate(
        model: modelRef('claimsNative'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      expect(captured.output?.schema, isNull);
      expect(outputInstructionOf(captured), isNotNull);
    });

    test('keeps the signal plugins turn native JSON mode on with', () async {
      defineCapturingModel('jsonMode');

      await genkit.generate(
        model: modelRef('jsonMode'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      // Deliberately unlike JS, which clears these too: JSON mode guarantees
      // the response parses and is independent of schema constraint.
      expect(captured.output?.format, 'json');
      expect(captured.output?.contentType, 'application/json');
    });

    test('still parses into typed output', () async {
      defineCapturingModel('typed');

      final response = await genkit.generate(
        model: modelRef('typed'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      expect(response.output?.name, 'Ada');
      expect(response.output?.age, 36);
    });

    test('leaves a request with no schema alone', () async {
      defineCapturingModel('noSchema');

      await genkit.generate(
        model: modelRef('noSchema'),
        prompt: 'Hello',
        use: [simulateConstrainedGeneration()],
      );

      expect(outputInstructionOf(captured), isNull);
      expect(captured.output?.constrained, isNull);
    });

    test('leaves an unconstrained request alone', () async {
      defineCapturingModel('unconstrained');

      await genkit.generate(
        model: modelRef('unconstrained'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        outputConstrained: false,
        use: [simulateConstrainedGeneration()],
      );

      expect(outputInstructionOf(captured), isNull);
      expect(captured.output?.schema, isNotNull);
      expect(captured.output?.constrained, isFalse);
    });

    test('works as an instance with the lite API', () async {
      ModelRequest? liteCaptured;
      final model = Model<void>(
        name: 'liteModel',
        fn: (req, ctx) async {
          liteCaptured = req;
          return _personResponse('{"name": "Ada", "age": 36}');
        },
      );

      final response = await lite.generate(
        model: model,
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [SimulateConstrainedGenerationMiddleware()],
      );

      expect(outputInstructionOf(liteCaptured!), contains('"name"'));
      expect(liteCaptured!.output?.schema, isNull);
      expect(response.output?.name, 'Ada');
    });
  });

  group('where the middleware puts the instructions', () {
    test("a caller's own instructions do not suppress the schema", () async {
      defineCapturingModel('customInstructions');

      await genkit.generate(
        model: modelRef('customInstructions'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        outputInstructions: 'Answer tersely.',
        use: [simulateConstrainedGeneration()],
      );

      final texts = captured.messages
          .expand((m) => m.content)
          .where((p) => p.isText)
          .map((p) => p.text!)
          .join('\n');
      expect(texts, contains('Answer tersely.'));
      expect(texts, contains('"name"'));
      expect(captured.output?.schema, isNull);
    });

    test('two system messages put them on the first', () async {
      defineCapturingModel('twoSystems');

      await genkit.generate(
        model: modelRef('twoSystems'),
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'first system')],
          ),
          Message(
            role: Role.system,
            content: [TextPart(text: 'second system')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'Describe a person.')],
          ),
        ],
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      // A provider that folds system messages into one field may keep only
      // the first.
      final first = captured.messages.first;
      expect(first.content.first.text, 'first system');
      expect(
        first.content.any((p) => p.metadata?['purpose'] == 'output'),
        isTrue,
      );
    });

    test('a request with nowhere to put them is left alone', () async {
      defineCapturingModel('noTarget');

      await genkit.generate(
        model: modelRef('noTarget'),
        messages: [
          Message(
            role: Role.model,
            content: [TextPart(text: 'prior')],
          ),
        ],
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );

      // No system or user message. Stripping the schema would leave the
      // model with nothing, so the request goes through untouched.
      expect(captured.output?.schema, isNotNull);
      expect(captured.output?.constrained, isTrue);
      expect(outputInstructionOf(captured), isNull);
    });
  });

  group('streaming', () {
    test('the request is rewritten and chunks parse as they arrive', () async {
      genkit.defineModel(
        name: 'streaming',
        fn: (req, ctx) async {
          captured = req;
          const chunks = ['{"name": ', '"Ada", ', '"age": 36}'];
          for (final chunk in chunks) {
            ctx.sendChunk(ModelResponseChunk(content: [TextPart(text: chunk)]));
          }
          return _personResponse(chunks.join());
        },
      );

      final stream = genkit.generateStream(
        model: modelRef('streaming'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        use: [simulateConstrainedGeneration()],
      );
      final chunks = await stream.toList();
      final result = await stream.onResult;

      expect(outputInstructionOf(captured), contains('"name"'));
      expect(captured.output?.schema, isNull);
      expect(chunks.map((c) => c.jsonOutput?.toJson()).toList(), [
        {'name': null},
        {'name': 'Ada'},
        {'name': 'Ada', 'age': 36},
      ]);
      expect(result.output?.age, 36);
    });
  });

  group('tools', () {
    void defineLookupTool() {
      genkit.defineTool(
        name: 'lookupPerson',
        description: 'Look a person up.',
        fn: (input, context) async => .response('Ada, 36'),
      );
    }

    test('the tools survive the rewritten request', () async {
      defineLookupTool();
      defineCapturingModel('withTools');

      await genkit.generate(
        model: modelRef('withTools'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        toolNames: ['lookupPerson'],
        use: [simulateConstrainedGeneration()],
      );

      expect(captured.tools?.single.name, 'lookupPerson');
      expect(captured.output?.schema, isNull);
    });

    test('instructions are injected once across a tool loop', () async {
      defineLookupTool();
      var turn = 0;
      genkit.defineModel(
        name: 'toolLoop',
        fn: (req, ctx) async {
          captured = req;
          turn++;
          if (turn == 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'lookupPerson',
                      input: <String, dynamic>{},
                    ),
                  ),
                ],
              ),
            );
          }
          return _personResponse('{"name": "Ada", "age": 36}');
        },
      );

      final response = await genkit.generate(
        model: modelRef('toolLoop'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        toolNames: ['lookupPerson'],
        use: [simulateConstrainedGeneration()],
      );

      final instructionParts = captured.messages
          .expand((m) => m.content)
          .where((p) => p.isText && p.metadata?['purpose'] == 'output');
      expect(turn, 2);
      expect(instructionParts, hasLength(1));
      expect(response.output?.name, 'Ada');
    });
  });
}
