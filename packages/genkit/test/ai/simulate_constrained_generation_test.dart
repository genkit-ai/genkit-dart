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
}
