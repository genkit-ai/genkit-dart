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
import 'package:genkit/src/ai/middleware/simulate_constrained_generation.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

part 'simulate_constrained_generation_test.g.dart';

@Schema()
abstract class $Person {
  String get name;
  int get age;
}

/// The instruction part `injectInstructions` writes, if the model got one.
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

void main() {
  late Genkit genkit;
  late ModelRequest captured;

  /// Registers a model recording the request it was handed, declaring
  /// [supports] (verbatim, so a test can omit `constrained` entirely).
  void defineCapturingModel(String name, {Map<String, dynamic>? supports}) {
    genkit.defineModel(
      name: name,
      info: supports == null ? null : ModelInfo(supports: supports),
      fn: (req, ctx) async {
        captured = req;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"name": "Ada", "age": 36}')],
          ),
        );
      },
    );
  }

  /// Registers a model that streams [chunks] before returning their
  /// concatenation, recording the request it was handed.
  void defineStreamingModel(
    String name,
    List<String> chunks, {
    Map<String, dynamic>? supports,
  }) {
    genkit.defineModel(
      name: name,
      info: supports == null ? null : ModelInfo(supports: supports),
      fn: (req, ctx) async {
        captured = req;
        for (final chunk in chunks) {
          ctx.sendChunk(ModelResponseChunk(content: [TextPart(text: chunk)]));
        }
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: chunks.join())],
          ),
        );
      },
    );
  }

  setUp(() {
    genkit = Genkit();
  });

  tearDown(() async {
    await genkit.shutdown();
  });

  group('needsConstrainedSimulation', () {
    test('a model making no claim is simulated for', () {
      expect(needsConstrainedSimulation(null, hasTools: false), isTrue);
    });

    test('false and "none" are simulated for', () {
      expect(needsConstrainedSimulation(false, hasTools: false), isTrue);
      expect(needsConstrainedSimulation('none', hasTools: false), isTrue);
    });

    test('true is left alone', () {
      expect(needsConstrainedSimulation(true, hasTools: false), isFalse);
      expect(needsConstrainedSimulation(true, hasTools: true), isFalse);
    });

    test('"no-tools" is simulated for only when the request carries '
        'tools', () {
      expect(needsConstrainedSimulation('no-tools', hasTools: false), isFalse);
      expect(needsConstrainedSimulation('no-tools', hasTools: true), isTrue);
    });

    test('an unrecognised value is treated as a claim of support', () {
      expect(needsConstrainedSimulation('sometimes', hasTools: false), isFalse);
    });
  });

  group('a model without native constrained generation', () {
    test('is sent the schema as instructions', () async {
      defineCapturingModel('noClaim');

      await genkit.generate(
        model: modelRef('noClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(outputInstructionOf(captured), contains('"name"'));
      expect(outputInstructionOf(captured), contains('JSON'));
    });

    test('is not sent the schema or the constrained flag', () async {
      defineCapturingModel('noClaim');

      await genkit.generate(
        model: modelRef('noClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      // `schema` matters as much as `constrained`: several plugins send a
      // native schema whenever `output.schema` is set and never read
      // `output.constrained`.
      expect(captured.output?.schema, isNull);
      expect(captured.output?.constrained, isFalse);
    });

    test('keeps the signal plugins turn native JSON mode on with', () async {
      defineCapturingModel('noClaim');

      await genkit.generate(
        model: modelRef('noClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      // Deliberately unlike JS, which clears these too. Plugins read them to
      // enable JSON mode, which guarantees the response parses and is
      // independent of schema constraint. `genkit_google_genai` computes
      // `isJsonMode` from exactly this pair.
      expect(captured.output?.format, 'json');
      expect(captured.output?.contentType, 'application/json');
    });

    test('still parses into typed output', () async {
      defineCapturingModel('noClaim');

      final response = await genkit.generate(
        model: modelRef('noClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(response.output?.name, 'Ada');
      expect(response.output?.age, 36);
    });

    test('is left alone when the request carries no schema', () async {
      defineCapturingModel('noClaim');

      await genkit.generate(model: modelRef('noClaim'), prompt: 'Hello');

      expect(outputInstructionOf(captured), isNull);
      expect(captured.output?.constrained, isNull);
    });
  });

  group('a model declaring constrained support', () {
    test('receives the schema and the flag untouched', () async {
      defineCapturingModel('native', supports: {'constrained': true});

      await genkit.generate(
        model: modelRef('native'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(captured.output?.schema, isNotNull);
      expect(captured.output?.constrained, isTrue);
      expect(captured.output?.format, 'json');
      expect(outputInstructionOf(captured), isNull);
    });
  });

  group('a model declaring "none"', () {
    test('is simulated for', () async {
      defineCapturingModel('none', supports: {'constrained': 'none'});

      await genkit.generate(
        model: modelRef('none'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(outputInstructionOf(captured), isNotNull);
      expect(captured.output?.schema, isNull);
      expect(captured.output?.format, 'json');
    });
  });

  group('streaming', () {
    test('a simulated request is stripped on the streaming path too', () async {
      defineStreamingModel('streamingNoClaim', [
        '{"name": ',
        '"Ada", ',
        '"age": 36}',
      ]);

      final stream = genkit.generateStream(
        model: modelRef('streamingNoClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );
      await stream.toList();

      // Streaming takes the same middleware chain, but nothing else covered
      // it: the composed model is built once and used for both paths.
      expect(outputInstructionOf(captured), contains('"name"'));
      expect(captured.output?.schema, isNull);
      expect(captured.output?.constrained, isFalse);
      expect(captured.output?.format, 'json');
    });

    test('partial chunks still parse as they arrive', () async {
      defineStreamingModel('streamingPartial', [
        '{"name": ',
        '"Ada", ',
        '"age": 36}',
      ]);

      final stream = genkit.generateStream(
        model: modelRef('streamingPartial'),
        prompt: 'Describe a person.',
        outputFormat: 'json',
        outputSchema: Person.$schema,
      );
      final chunks = await stream.toList();

      // The json formatter repairs truncated JSON, so a simulated model's
      // half-written object is readable mid-stream exactly as a natively
      // constrained one's is.
      final outputs = chunks.map((c) => c.jsonOutput?.toJson()).toList();
      expect(outputs, [
        {'name': null},
        {'name': 'Ada'},
        {'name': 'Ada', 'age': 36},
      ]);
    });

    test('the final streamed result is typed', () async {
      defineStreamingModel('streamingTyped', [
        '{"name": ',
        '"Ada", ',
        '"age": 36}',
      ]);

      final stream = genkit.generateStream(
        model: modelRef('streamingTyped'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );
      await stream.toList();
      final result = await stream.onResult;

      expect(result.output?.name, 'Ada');
      expect(result.output?.age, 36);
    });
  });

  group('tools', () {
    /// A tool the model can be offered; never actually called by these tests
    /// unless the model asks for it.
    void defineLookupTool() {
      genkit.defineTool(
        name: 'lookupPerson',
        description: 'Look a person up.',
        fn: (input, context) async => .response('Ada, 36'),
      );
    }

    test('"no-tools" takes the native path when no tool is offered', () async {
      defineCapturingModel(
        'noToolsModel',
        supports: {'constrained': 'no-tools'},
      );

      await genkit.generate(
        model: modelRef('noToolsModel'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
      );

      expect(captured.output?.schema, isNotNull);
      expect(captured.output?.constrained, isTrue);
      expect(outputInstructionOf(captured), isNull);
    });

    test('"no-tools" is simulated for once a tool is offered', () async {
      defineLookupTool();
      defineCapturingModel(
        'noToolsWithTools',
        supports: {'constrained': 'no-tools'},
      );

      await genkit.generate(
        model: modelRef('noToolsWithTools'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        toolNames: ['lookupPerson'],
      );

      // The model's native constraint is mutually exclusive with tool calling,
      // so offering a tool is what tips it into simulation.
      expect(captured.output?.schema, isNull);
      expect(outputInstructionOf(captured), isNotNull);
      expect(captured.tools, isNotEmpty);
    });

    test('the tools survive the stripped request', () async {
      defineLookupTool();
      defineCapturingModel('toolsNoClaim');

      await genkit.generate(
        model: modelRef('toolsNoClaim'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        toolNames: ['lookupPerson'],
      );

      // Only the output config is rewritten. Dropping the tools while
      // rebuilding the request would silently disable tool calling for every
      // simulated model.
      expect(captured.tools?.single.name, 'lookupPerson');
      expect(captured.output?.schema, isNull);
    });

    test('instructions are injected once across a tool loop', () async {
      defineLookupTool();
      var turn = 0;
      genkit.defineModel(
        name: 'toolLoopModel',
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
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: '{"name": "Ada", "age": 36}')],
            ),
          );
        },
      );

      final response = await genkit.generate(
        model: modelRef('toolLoopModel'),
        prompt: 'Describe a person.',
        outputSchema: Person.$schema,
        toolNames: ['lookupPerson'],
      );

      // `injectInstructions` is a no-op once the conversation carries an
      // output part, so the second turn must not accumulate a copy.
      final instructionParts = captured.messages
          .expand((m) => m.content)
          .where((p) => p.isText && p.metadata?['purpose'] == 'output');
      expect(turn, 2);
      expect(instructionParts, hasLength(1));
      expect(response.output?.name, 'Ada');
    });
  });
}
