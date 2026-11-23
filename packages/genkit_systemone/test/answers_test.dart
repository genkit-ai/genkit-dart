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

/// The answers a server sends, checked before they reach a decision type:
/// Genkit Dart's generate loop parses the output but does not validate it
/// against its schema, as Go's and JS's do, so the plugin does.
library;

import 'dart:convert';

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import 'fake_server.dart';
import 'test_types.dart';

/// A plugin whose server answers every request with [answers].
(SystemOne, FakeServer) answering(Map<String, Object?> answers) {
  final server = FakeServer(
    reply: (_) async => http.Response(
      jsonEncode({'model': 'jev-1.13.0', 'answers': answers}),
      200,
    ),
  );
  return (
    withEnv({
      'TYPESAFE_API_KEY': 'k',
    }, () => SystemOne.typeSafe(httpClient: server.client)),
    server,
  );
}

final _oneOfEach = decisionSchema({
  'dept': Choice.schema(Dept.values, description: 'Which team?'),
  'anger': ScoreOf.schema(Anger.values, description: 'How angry?'),
  'urgent': Noul.schema(description: 'Urgent?'),
}, (a) => a);

const _valid = {
  'dept': {'choice': 'billing', 'confidence': 0.5},
  'anger': {'score': 1.0},
  'urgent': {'noul': 0.4},
};

Future<GenerateResult<Object?>> decide(
  Map<String, Object?> answers, {
  SchemanticType<Object?>? schema,
  String? outputFormat,
}) async {
  final (plugin, _) = answering(answers);
  final ai = Genkit(isDevEnv: false, plugins: [plugin], promptDir: null);
  addTearDown(ai.shutdown);
  return ai.generate(
    model: plugin.modelRef('jev-1.13.0'),
    prompt: 'ticket',
    outputSchema: schema ?? _oneOfEach,
    outputFormat: outputFormat,
  );
}

Matcher failsWith(Object message) => isA<GenerateResult<Object?>>()
    .having((r) => r.finishReason, 'finishReason', FinishReason.failed)
    .having((r) => r.error?.status, 'status', StatusCode.internal.wireName)
    .having((r) => r.error?.message, 'message', message);

void main() {
  test('a valid set of answers goes through', () async {
    final result = await decide(_valid);
    expect(result.finishReason, FinishReason.stop);
    final answers = result.output! as Map<String, Object?>;
    expect((answers['dept']! as Choice<Dept>).choice, Dept.billing);
  });

  test('a question with no answer fails the call', () async {
    expect(
      await decide({..._valid}..remove('anger')),
      failsWith('systemone: no answer for question "anger"'),
    );
  });

  test("an answer missing its kind's field fails the call", () async {
    expect(
      await decide({
        ..._valid,
        'anger': {'confidence': 0.3},
      }),
      failsWith('systemone: answer for question "anger" has no numeric score'),
    );
    expect(
      await decide({
        ..._valid,
        'urgent': {'noul': 'yes'},
      }),
      failsWith('systemone: answer for question "urgent" has no numeric noul'),
    );
  });

  test('a choice outside the options fails the call', () async {
    expect(
      await decide({
        ..._valid,
        'dept': {'choice': 'sales'},
      }),
      failsWith(contains('chose "sales", which is not one of its options')),
    );
  });

  test('an enum answer outside the values fails the call', () async {
    expect(
      await decide(
        {
          'choice': {'choice': 'legal'},
        },
        schema: SchemanticType.string(enumValues: ['billing', 'sales']),
        outputFormat: 'enum',
      ),
      failsWith(contains('chose "legal", which is not one of its options')),
    );
  });

  test('a noul outside 0 to 1 fails the call', () async {
    expect(
      await decide({
        ..._valid,
        'urgent': {'noul': 1.2},
      }),
      failsWith(contains('has noul 1.2, which is not a probability')),
    );
  });

  test('a distribution that is not numbers fails the call', () async {
    expect(
      await decide({
        ..._valid,
        'dept': {
          'choice': 'billing',
          'probabilities': {'billing': 'high'},
        },
      }),
      failsWith(contains('has probabilities that are not numbers')),
    );
  });

  test('a missing confidence reads as 0, as Go decodes it', () async {
    final result = await decide({
      ..._valid,
      'dept': {'choice': 'billing'},
    });
    final answers = result.output! as Map<String, Object?>;
    expect((answers['dept']! as Choice<Dept>).confidence, 0);
  });

  test('a probability for a name the enum lacks is left out', () async {
    final result = await decide({
      ..._valid,
      'dept': {
        'choice': 'billing',
        'probabilities': {'billing': 0.9, 'legacy': 0.1},
      },
    });
    final answers = result.output! as Map<String, Object?>;
    expect((answers['dept']! as Choice<Dept>).probabilities, {
      Dept.billing: 0.9,
    });
  });

  test('one choice can be asked by two questions', () async {
    final dept = Choice.schema(Dept.values, description: 'Which team?');
    final result = await decide(
      {
        'first': {'choice': 'billing'},
        'second': {'choice': 'other'},
      },
      schema: decisionSchema({
        'first': dept,
        'second': dept,
      }, (a) => (a['first']! as Choice<Dept>, a['second']! as Choice<Dept>)),
    );
    final (first, second) = result.output! as (Choice<Dept>, Choice<Dept>);
    expect(first.choice, Dept.billing);
    expect(second.choice, Dept.other);
  });

  test('a build that casts wrong is a FormatException naming the decision', () {
    final schema = decisionSchema(
      {'urgent': Noul.schema(description: 'Urgent?')},
      (a) => a['urgent']! as Choice<Dept>,
      description: 'Triage',
    );
    expect(
      () => schema.parse({
        'urgent': {'noul': 0.5},
      }),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('the decision "Triage" cannot be built'),
        ),
      ),
    );
  });

  group('the checked fields', () {
    for (final (what, answers, message)
        in <(String, Map<String, Object?>, String)>[
          (
            'a choice that is not a string',
            {
              ..._valid,
              'dept': {'choice': 3},
            },
            'has no choice',
          ),
          (
            'a confidence that is not a number',
            {
              ..._valid,
              'dept': {'choice': 'billing', 'confidence': 'high'},
            },
            'has confidence high',
          ),
          (
            'a confidence above 1',
            {
              ..._valid,
              'anger': {'score': 1, 'confidence': 1.5},
            },
            'has confidence 1.5',
          ),
          (
            'a confidence sent as null',
            {
              ..._valid,
              'dept': {'choice': 'billing', 'confidence': null},
            },
            'has confidence null',
          ),
          (
            'a probability below 0',
            {
              ..._valid,
              'anger': {
                'score': 1,
                'probabilities': {'0': -0.1, '1': 1.1},
              },
            },
            'has probabilities that are not numbers from 0 to 1',
          ),
          (
            'a negative noul',
            {
              ..._valid,
              'urgent': {'noul': -0.01},
            },
            'has noul -0.01, which is not a probability',
          ),
        ]) {
      test('$what fails the call', () async {
        expect(await decide(answers), failsWith(contains(message)));
      });
    }

    test('a noul of 0 or 1 is a probability', () async {
      for (final noul in [0, 1]) {
        final result = await decide({
          ..._valid,
          'urgent': {'noul': noul},
        });
        expect(result.finishReason, FinishReason.stop, reason: '$noul');
      }
    });

    test('a noul is checked on its own field only', () async {
      // A noul answer is projected onto noul alone, so what else it carries
      // is not checked.
      final result = await decide({
        ..._valid,
        'urgent': {'noul': 0.5, 'confidence': 'n/a'},
      });
      expect(result.finishReason, FinishReason.stop);
    });

    test('a score a hair below 0 is clamped to 0', () async {
      final result = await decide({
        ..._valid,
        'anger': {'score': -1e-17},
      });
      final answers = result.output! as Map<String, Object?>;
      expect((answers['anger']! as ScoreOf<Anger>).score, 0);
    });

    test('a level number the rubric lacks is left out of a score', () async {
      final result = await decide({
        ..._valid,
        'anger': {
          'score': 1,
          'probabilities': {'1': 0.9, '7': 0.1},
        },
      });
      final answers = result.output! as Map<String, Object?>;
      expect((answers['anger']! as ScoreOf<Anger>).probabilities, {'1': 0.9});
      expect(
        SystemOneInfo.of(
          result.modelResponse,
        ).answers['anger']?['probabilities'],
        {'1': 0.9, '7': 0.1},
      );
    });
  });

  test('the info does not alias the response it was read from', () async {
    final result = await decide(_valid);
    final info = SystemOneInfo.of(result.modelResponse);
    expect(
      () => (info.answers['dept']! as Map)['choice'] = 'other',
      throwsUnsupportedError,
    );
  });

  group('only declared probability keys exist', () {
    final runtime = questionsSchema({
      'pick': ChoiceQuestion(
        instructions: 'Pick one',
        options: [ChoiceOption('a'), ChoiceOption('b')],
      ),
      'rate': ScoreQuestion(instructions: 'Rate it', levels: ['low', 'high']),
    });
    for (final extra in <Object?>[1.5, null, 'x']) {
      test('an undeclared key valued $extra is dropped everywhere', () async {
        final answers = {
          'pick': {
            'choice': 'a',
            'probabilities': {'a': 0.7, 'b': 0.3, 'c': extra},
          },
          'rate': {
            'score': 0.3,
            'probabilities': {'0': 0.7, '1': 0.3, '2': extra},
          },
        };
        final result = await decide(answers, schema: runtime);
        expect(result.finishReason, FinishReason.stop);
        expect(result.text, isNot(contains('"c"')));
        expect(result.text, isNot(contains('"2"')));
        final parsed = result.output! as Map<String, Answer>;
        expect(parsed['pick']!.probabilities, {'a': 0.7, 'b': 0.3});
        expect(parsed['rate']!.probabilities, {'0': 0.7, '1': 0.3});

        final typed = await decide({
          ..._valid,
          'dept': {
            'choice': 'billing',
            'probabilities': {'billing': 0.7, 'other': 0.3, 'c': extra},
          },
          'anger': {
            'score': 1,
            'probabilities': {'0': 0.7, '1': 0.3, '7': extra},
          },
        });
        expect(typed.finishReason, FinishReason.stop);
        final out = typed.output! as Map<String, Object?>;
        expect((out['dept']! as Choice<Dept>).probabilities, {
          Dept.billing: 0.7,
          Dept.other: 0.3,
        });
        expect((out['anger']! as ScoreOf<Anger>).probabilities, {
          '0': 0.7,
          '1': 0.3,
        });
      });
    }

    test('a declared key that is null or not a number fails', () async {
      for (final bad in <Object?>[null, 'x', 1.5]) {
        expect(
          await decide({
            ..._valid,
            'dept': {
              'choice': 'billing',
              'probabilities': {'billing': bad},
            },
          }),
          failsWith(contains('has probabilities that are not numbers')),
          reason: '$bad',
        );
      }
    });
  });

  test("another model's raw with a model field is not System One info", () {
    final info = SystemOneInfo.of(
      ModelResponse(
        finishReason: FinishReason.stop,
        raw: {'model': 'gpt-4o', 'id': 'chatcmpl-1'},
      ),
    );
    expect(info.model, '');
    expect(info.id, '');
  });

  test('the info round-trips through its JSON with its marker', () async {
    final result = await decide(_valid);
    final raw = result.modelResponse.raw!;
    expect(raw['systemOneInfo'], true);
    final again = SystemOneInfo.of(
      ModelResponse(finishReason: FinishReason.stop, raw: {...raw}),
    );
    expect(again.model, 'jev-1.13.0');
  });
}
