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

/// Inputs from a caller or a server that must not crash, leak, or pass.
library;

import 'dart:convert';

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:genkit_systemone/src/plugin.dart' show ollamaRoute;
import 'package:genkit_systemone/src/protocol/client.dart';
import 'package:genkit_systemone/src/protocol/state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fake_server.dart';
import 'test_types.dart';

Matcher misconfigured(Object message) => throwsA(
  isA<GenkitException>()
      .having((e) => e.status, 'status', StatusCode.failedPrecondition)
      .having((e) => e.message, 'message', message),
);

void main() {
  group('usage counts', () {
    for (final (raw, expected) in <(String, int?)>[
      ('3', 3),
      ('3.0', 3),
      ('3.5', null),
      ('-1', null),
      ('1e400', null),
      ('"3"', null),
    ]) {
      test('$raw reads as $expected and never fails the answer', () async {
        final client = DecideClient(
          httpClient: MockClient(
            (_) async => http.Response(
              '{"model":"m","answers":{},"usage":{"input_tokens":$raw,'
              '"output_tokens":$raw}}',
              200,
            ),
          ),
          baseUrl: 'https://d.test',
          endpoint: Endpoint(name: 't', path: ''),
        );
        final resp = await client.decide(
          'm',
          DecideRequest(state: 's', media: RequestMedia(), questions: {}),
        );
        expect(resp.inputTokens, expected);
        expect(resp.outputTokens, expected);
      });
    }
  });

  group('a base URL', () {
    for (final url in [
      'decisions.example.com',
      'ftp://decisions.example.com',
      'https://',
      'https://user:pass-secret@decisions.example.com',
      'https://decisions.example.com/root?tenant=secret',
      'https://decisions.example.com/root#secret',
    ]) {
      test('"$url" is refused and not quoted', () {
        expect(
          () => SystemOne(provider: 'p', baseUrl: url),
          misconfigured(
            allOf(
              contains('baseUrl must be'),
              isNot(contains('secret')),
              isNot(contains('decisions.example.com')),
            ),
          ),
        );
      });
    }
  });

  test('a full name for a preset model is named as such first', () {
    expect(
      () => SystemOne.typeSafe(
        apiKey: 'k',
        models: {'jev-latest': ModelSpec(), 'typesafe/jev-latest': ModelSpec()},
      ),
      misconfigured(contains('already defined by the preset as jev-latest')),
    );
  });

  test('Ollama refuses an image that is not base64, as INTERNAL', () {
    expect(
      () => ollamaRoute('clef', {
        'state': 'look',
        'images': ['data:image/png,raw'],
      }),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.internal,
        ),
      ),
    );
  });

  test(
    'a listing contributes at most 1000 IDs of at most 256 characters',
    () async {
      final listed = [
        {'name': 'x' * 257},
        for (var i = 0; i < 1200; i++) {'name': 'm$i'},
      ];
      final server = FakeServer(models: jsonEncode(listed));
      final plugin = SystemOne(
        provider: 'p',
        baseUrl: 'https://d.test',
        modelsPath: '/models',
        httpClient: server.client,
      );
      final names = (await plugin.list()).map((a) => a.name).toList();
      expect(names, hasLength(1000));
      expect(names.any((n) => n.length > 300), isFalse);
    },
  );

  test('an extra with keys that are not strings is INVALID_ARGUMENT', () async {
    final server = FakeServer();
    final plugin = SystemOne.typeSafe(apiKey: 'k', httpClient: server.client);
    final ai = Genkit(isDevEnv: false, plugins: [plugin], promptDir: null);
    addTearDown(ai.shutdown);
    final result = await ai.generate(
      model: modelRef<Map<String, dynamic>>(
        'typesafe/jev-1.13.0',
        config: {
          'extra': <Object, Object>{1: 'x'},
        },
      ),
      prompt: 'ticket',
      outputSchema: Triage.$schema,
    );
    expect(result.finishReason, FinishReason.failed);
    expect(result.error?.status, StatusCode.invalidArgument.wireName);
    expect(server.calls, 0);
  });

  test('output instructions of any part kind are not state', () {
    final built = buildState(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'ticket'),
              Part.fromJson({
                'data': {'schema': 'x'},
                'metadata': {'purpose': 'output'},
              }),
            ],
          ),
        ],
      ),
      stateJson: false,
      reads: const Reads(),
    );
    expect(built.state, 'ticket');
  });

  test('a score keeps its own copy of the levels', () {
    final levels = [...Anger.values];
    final score = ScoreOf(levels: levels, score: 2);
    levels.clear();
    expect(score.label, 'Very angry');
    expect(() => score.levels.add(Anger.calm), throwsUnsupportedError);
  });

  test('a NoulOf prints as a NoulOf', () {
    expect(NoulOf<Urgent>(0.4).toString(), startsWith('NoulOf{'));
  });

  test('an answer and an info do not alias what they were built from', () {
    final probabilities = {'a': 0.5};
    final answer = Answer(
      type: 'choice',
      choice: 'a',
      probabilities: probabilities,
    );
    probabilities['a'] = 0.9;
    expect(answer.probabilities['a'], 0.5);

    final inner = <String, Object?>{'choice': 'a'};
    final info = SystemOneInfo(answers: {'q': inner});
    inner['choice'] = 'b';
    expect(info.answers['q']?['choice'], 'a');
  });
}
