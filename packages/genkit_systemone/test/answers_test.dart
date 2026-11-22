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
    SystemOne.typeSafe(
      httpClient: server.client,
      configVar: env({'TYPESAFE_API_KEY': 'k'}),
    ),
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
}
