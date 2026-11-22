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

import 'dart:convert';

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:genkit_systemone/src/plugin.dart' show hasText, pathEscape;
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import 'fake_server.dart';
import 'test_types.dart';

const _ticket = 'I was charged twice and need it refunded today!';

/// A Genkit instance over [plugin], shut down after the test.
Genkit genkitWith(GenkitPlugin plugin) {
  final ai = Genkit(isDevEnv: false, plugins: [plugin], promptDir: null);
  addTearDown(ai.shutdown);
  return ai;
}

SystemOne typeSafe(FakeServer server) => SystemOne.typeSafe(
  httpClient: server.client,
  configVar: env({'TYPESAFE_API_KEY': 'ts-key'}),
);

/// A generate call whose model failed: generate resolves it, with the
/// failure on the result, rather than throwing.
TypeMatcher<GenerateResult<Object?>> failed() => isA<GenerateResult<Object?>>()
    .having((r) => r.finishReason, 'finishReason', FinishReason.failed);

extension on TypeMatcher<GenerateResult<Object?>> {
  TypeMatcher<GenerateResult<Object?>> withMessage(Object matcher) =>
      having((r) => r.error?.message, 'error message', matcher);

  TypeMatcher<GenerateResult<Object?>> withStatus(StatusCode status) =>
      having((r) => r.error?.status, 'error status', status.wireName);
}

void main() {
  group('a decision', () {
    test('is one typed generate call', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);

      final result = await ai.generate(
        model: plugin.modelRef('jev-1.13.0'),
        system: 'The state is a support ticket.',
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );

      final triage = result.output!;
      expect(triage.department.choice, Dept.billing);
      expect(triage.department.confidence, 0.6);
      expect(triage.isUrgent.probability, 0.93);
      expect(triage.frustration.score, 1.3);
      expect(triage.frustration.label, 'Concerned but civil');
      expect(triage.deadline.probability, 0.93);

      final (req, body) = server.last;
      expect(req.url.toString(), 'https://api.typesafe.ai/v1/systemone');
      expect(req.headers['Authorization'], 'Bearer ts-key');
      expect(body['model'], 'jev-1.13.0');
      // The system message is instructions, never state.
      expect(body['state'], _ticket);
      final questions = body['questions'] as Map;
      expect(questions.keys, [
        'deadline',
        'department',
        'frustration',
        'is_urgent',
      ]);
      expect(
        (questions['is_urgent'] as Map)['instructions'],
        'The state is a support ticket.\n\n'
        'Does the ticket explicitly communicate time pressure?',
      );

      expect(result.usage?.inputTokens, 312);
      expect(result.usage?.outputTokens, 48);
      expect(result.usage?.totalTokens, 360);
      final info = SystemOneInfo.of(result.modelResponse);
      expect(info.model, 'jev-1.13.0');
      expect(info.answers['department']?['type'], 'choice');
    });

    test('rebuilds the legend from the rubric and clamps the score', () async {
      final server = FakeServer(
        reply: (req) async => http.Response(
          jsonEncode({
            'model': 'jev-1.13.0',
            'answers': {
              'anger': {
                'type': 'score',
                'score': 2.0000000001,
                'confidence': 0.9,
                // The API echoes a level's guidance in its legend.
                'legend': {
                  '0': 'Calm',
                  '1': 'Concerned but civil',
                  '2': {'what': 'Very angry', 'signals': <String>[]},
                },
                'extra_field': 'added by a gateway later',
              },
            },
          }),
          200,
        ),
      );
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      final result = await ai.generate(
        model: plugin.modelRef('jev-1.13.0'),
        prompt: _ticket,
        outputSchema: decisionSchema({
          'anger': ScoreOf.schema(Anger.values, description: 'How angry?'),
        }, (a) => a['anger'] as ScoreOf<Anger>),
      );
      final score = result.output!;
      expect(score.score, 2);
      expect(score.legend, {
        '0': 'Calm',
        '1': 'Concerned but civil',
        '2': 'Very angry',
      });
      // The answer as the API sent it stays on the info.
      expect(
        SystemOneInfo.of(result.modelResponse).answers['anger']?['extra_field'],
        'added by a gateway later',
      );
    });

    test('takes a data part as an object state', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      await ai.generate(
        model: plugin.modelRef('jev-1.13.0'),
        promptParts: [
          DataPart(data: {'ticket': _ticket, 'tier': 'pro'}),
        ],
        outputSchema: Triage.$schema,
      );
      expect(server.last.$2['state'], {'ticket': _ticket, 'tier': 'pro'});
    });

    test('parses a rendered template with stateJSON', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      await ai.generate(
        model: plugin.modelRef(
          'jev-1.13.0',
          config: SystemOneOptions(stateJSON: true, extra: {'session_id': 's'}),
        ),
        prompt: '{"ticket": "x", "id": 9007199254740993}',
        outputSchema: Triage.$schema,
      );
      final (req, body) = server.last;
      expect(body['session_id'], 's');
      expect(req.body, contains('"id": 9007199254740993'));
    });

    test('refuses an extra field the request builds itself', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      final result = await ai.generate(
        model: plugin.modelRef(
          'jev-1.13.0',
          config: SystemOneOptions(extra: {'questions': {}}),
        ),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(
        result,
        failed()
            .withStatus(StatusCode.invalidArgument)
            .withMessage(contains('extra field "questions"')),
      );
      expect(server.calls, 0);
    });

    test('needs an output schema, and calls no tools', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      expect(
        await ai.generate(
          model: plugin.modelRef('jev-1.13.0'),
          prompt: _ticket,
        ),
        failed().withMessage(
          contains('answers questions encoded in an output type'),
        ),
      );
      final tool = ai.defineTool(
        name: 'lookup',
        description: 'Looks things up',
        inputSchema: SchemanticType.string(),
        fn: (input, _) async => ToolResult.response('found'),
      );
      expect(
        await ai.generate(
          model: plugin.modelRef('jev-1.13.0'),
          prompt: _ticket,
          tools: [tool],
          outputSchema: Triage.$schema,
        ),
        failed().withMessage(contains('calls no tools')),
      );
      expect(server.calls, 0);
    });
  });

  test('the enum format is one choice, answered as text', () async {
    final server = FakeServer();
    final plugin = typeSafe(server);
    final ai = genkitWith(plugin);
    final result = await ai.generate(
      model: plugin.modelRef('jev-1.13.0'),
      system: 'Which team should handle this ticket?',
      prompt: _ticket,
      outputFormat: 'enum',
      outputSchema: SchemanticType.string(
        enumValues: ['technical', 'billing', 'sales'],
      ),
    );
    expect(result.text, 'billing');
    final questions = server.last.$2['questions'] as Map;
    expect(questions, {
      'choice': {
        'type': 'choice',
        'instructions': 'Which team should handle this ticket?',
        'criteria': {
          'technical': 'technical',
          'billing': 'billing',
          'sales': 'sales',
        },
      },
    });
  });

  test('runtime questions answer as a map of Answer', () async {
    final server = FakeServer();
    final plugin = typeSafe(server);
    final ai = genkitWith(plugin);
    final result = await ai.generate(
      model: plugin.modelRef('typesafe/jev-1.13.0'),
      prompt: 'Move my 3pm meeting to Thursday.',
      outputSchema: questionsSchema({
        'tool': ChoiceQuestion(
          instructions: 'Which tool serves the request?',
          options: [
            ChoiceOption('weather', criteria: 'Forecasts'),
            ChoiceOption('calendar', criteria: 'Meetings and events'),
          ],
        ),
        'personal': NoulQuestion(
          instructions: "Does the request involve the user's own data?",
          yes: "Names the user's files, mail, or calendar",
          no: 'Asks about the world at large',
        ),
      }),
    );
    final answers = result.output!;
    expect(answers['tool']!.choice, 'calendar');
    expect(answers['tool']!.type, 'choice');
    expect(answers['personal']!.probability, 0.93);
  });

  group('servers', () {
    test('TypeSafe needs a key, and reads its base URL too', () {
      expect(
        () => SystemOne.typeSafe(configVar: env({})),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('TYPESAFE_API_KEY'),
          ),
        ),
      );
      final server = FakeServer();
      final plugin = SystemOne.typeSafe(
        httpClient: server.client,
        configVar: env({
          'TYPESAFE_API_KEY': 'k',
          'TYPESAFE_BASE_URL': 'https://proxy.test/',
        }),
      );
      expect(plugin.name, 'typesafe');
      return genkitWith(plugin)
          .generate(
            model: plugin.modelRef('jev-latest'),
            prompt: _ticket,
            outputSchema: Triage.$schema,
          )
          .then((_) {
            expect(
              server.last.$1.url.toString(),
              'https://proxy.test/v1/systemone',
            );
          });
    });

    test('OpenRouter posts to its alpha path and reports the cost', () async {
      final server = FakeServer(
        usage: {'input_tokens': 10, 'output_tokens': 2, 'cost': 0.0004},
      );
      final plugin = SystemOne.openRouter(
        httpClient: server.client,
        configVar: env({'OPENROUTER_API_KEY': 'or-key'}),
      );
      final ai = genkitWith(plugin);
      final result = await ai.generate(
        model: plugin.modelRef('liquid/d1'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      final (req, body) = server.last;
      expect(req.url.toString(), 'https://openrouter.ai/api/alpha/decisions');
      expect(body['model'], 'liquid/d1');
      expect(result.usage?.custom, {'cost': 0.0004});
    });

    test('OpenRouter refuses media before sending it', () async {
      final server = FakeServer();
      final plugin = SystemOne.openRouter(
        httpClient: server.client,
        configVar: env({'OPENROUTER_API_KEY': 'k'}),
      );
      final ai = genkitWith(plugin);
      expect(
        await ai.generate(
          model: plugin.modelRef('liquid/d1'),
          promptParts: [
            TextPart(text: 'Arrived like this.'),
            MediaPart(media: Media(url: 'data:image/png;base64,AAA')),
          ],
          outputSchema: Triage.$schema,
        ),
        failed().withMessage(contains('reads no image/png media')),
      );
      expect(server.calls, 0);
    });

    test('Ollama sends images as raw base64 and needs text', () async {
      final server = FakeServer();
      final plugin = SystemOne.ollama(httpClient: server.client);
      final ai = genkitWith(plugin);
      await ai.generate(
        model: plugin.modelRef('clef'),
        promptParts: [
          TextPart(text: 'Arrived like this.'),
          MediaPart(media: Media(url: 'data:image/jpeg;base64,AAAA')),
        ],
        outputSchema: Triage.$schema,
      );
      final (req, body) = server.last;
      expect(req.url.toString(), 'http://localhost:11434/v1/systemone');
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(body['images'], ['AAAA']);
      expect(body['state'], 'Arrived like this.');

      expect(
        await ai.generate(
          model: plugin.modelRef('clef'),
          promptParts: [
            MediaPart(media: Media(url: 'data:image/jpeg;base64,AAAA')),
          ],
          outputSchema: Triage.$schema,
        ),
        failed().withMessage(
          contains('so a request with images needs text too'),
        ),
      );
    });

    group('Workers AI', () {
      SystemOne workersAI(FakeServer server, {String? accountId}) =>
          SystemOne.workersAI(
            accountId: accountId,
            httpClient: server.client,
            configVar: env({
              'CLOUDFLARE_API_TOKEN': 'cf',
              'CLOUDFLARE_ACCOUNT_ID': 'from-env',
            }),
          );

      test('runs its own models by path, in the result envelope', () async {
        final server = FakeServer(
          wrap: (reply) => {'result': reply, 'success': true, 'errors': []},
        );
        final plugin = workersAI(server, accountId: 'acc 1');
        final ai = genkitWith(plugin);
        final result = await ai.generate(
          model: plugin.modelRef('@cf/cloudflare/clef-omni'),
          promptParts: [
            TextPart(text: 'Clip from the server room.'),
            MediaPart(media: Media(url: 'data:audio/wav;base64,AAA')),
            MediaPart(media: Media(url: 'data:video/mp4;base64,BBB')),
          ],
          outputSchema: Triage.$schema,
        );
        expect(result.output!.department.choice, Dept.billing);
        final (req, body) = server.last;
        expect(
          req.url.toString(),
          'https://api.cloudflare.com/client/v4/accounts/acc%201'
          '/ai/run/@cf/cloudflare/clef-omni',
        );
        expect(body['model'], 'clef-omni');
        expect(body['audio'], ['data:audio/wav;base64,AAA']);
        expect(body['videos'], ['data:video/mp4;base64,BBB']);
      });

      test('runs a partner model with the body under input', () async {
        final server = FakeServer();
        final plugin = workersAI(server);
        final ai = genkitWith(plugin);
        await ai.generate(
          model: plugin.modelRef('typesafe/jev'),
          prompt: _ticket,
          outputSchema: Triage.$schema,
        );
        final (req, body) = server.last;
        expect(
          req.url.toString(),
          'https://api.cloudflare.com/client/v4/accounts/from-env/ai/run',
        );
        expect(body['model'], 'typesafe/jev');
        expect((body['input'] as Map)['state'], _ticket);
        expect((body['input'] as Map).containsKey('model'), isFalse);
      });

      test('a partner model reads no images, Clef-omni does', () async {
        final server = FakeServer();
        final plugin = workersAI(server);
        final ai = genkitWith(plugin);
        final parts = [
          TextPart(text: 'Look'),
          MediaPart(media: Media(url: 'data:image/png;base64,AAA')),
        ];
        expect(
          await ai.generate(
            model: plugin.modelRef('typesafe/jev'),
            promptParts: parts,
            outputSchema: Triage.$schema,
          ),
          failed()
              .withStatus(StatusCode.invalidArgument)
              .withMessage('systemone: the model reads no image/png media'),
        );
        expect(server.calls, 0);
        await ai.generate(
          model: plugin.modelRef('@cf/cloudflare/clef'),
          promptParts: parts,
          outputSchema: Triage.$schema,
        );
        expect(server.last.$2['images'], ['data:image/png;base64,AAA']);
      });

      test('a failed envelope is an error with its messages', () async {
        final server = FakeServer(
          wrap: (_) => {
            'result': null,
            'success': false,
            'errors': [
              {'code': 5007, 'message': 'No such model'},
            ],
          },
        );
        final plugin = workersAI(server);
        final ai = genkitWith(plugin);
        expect(
          await ai.generate(
            model: plugin.modelRef('@cf/cloudflare/clef'),
            prompt: _ticket,
            outputSchema: Triage.$schema,
          ),
          failed()
              .withStatus(StatusCode.unknown)
              .withMessage('cloudflare-decisions: No such model'),
        );
      });

      test('a model ID cannot reach another path', () async {
        final server = FakeServer();
        final plugin = workersAI(server);
        final ai = genkitWith(plugin);
        expect(
          await ai.generate(
            model: plugin.modelRef('@cf/../../tokens'),
            prompt: _ticket,
            outputSchema: Triage.$schema,
          ),
          failed().withMessage(contains('is not a Workers AI model ID')),
        );
        expect(server.calls, 0);
      });

      test('needs an account unless the base URL has no account segment', () {
        expect(
          () => SystemOne.workersAI(
            configVar: env({'CLOUDFLARE_API_TOKEN': 'cf'}),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              contains('CLOUDFLARE_ACCOUNT_ID'),
            ),
          ),
        );
        expect(
          SystemOne.workersAI(
            baseUrl: 'https://ai-proxy.test/cloudflare',
            configVar: env({'CLOUDFLARE_API_TOKEN': 'cf'}),
          ).name,
          'cloudflare-decisions',
        );
      });
    });

    test('any other server takes its settings and hooks', () async {
      final server = FakeServer(wrap: (reply) => {'envelope': reply});
      final plugin = SystemOne(
        provider: 'wrapped',
        baseUrl: 'https://decisions.test',
        path: '/run',
        httpClient: server.client,
        headers: {'X-Tenant': 't1'},
        route: (model, body) {
          body.remove('model');
          return (path: model, body: {'input': body});
        },
        unwrap: (body) => jsonEncode((jsonDecode(body) as Map)['envelope']),
      );
      final ai = genkitWith(plugin);
      final result = await ai.generate(
        model: plugin.modelRef('d1'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(result.output!.isUrgent.probability, 0.93);
      final (req, _) = server.last;
      expect(req.url.toString(), 'https://decisions.test/run/d1');
      expect(req.headers['X-Tenant'], 't1');
      expect(req.headers.containsKey('Authorization'), isFalse);
    });

    test('a path of "/" is the base URL itself', () async {
      final server = FakeServer();
      final plugin = SystemOne(
        provider: 'liquid',
        baseUrl: 'https://api.liquid.test/decide',
        path: '/',
        httpClient: server.client,
      );
      await genkitWith(plugin).generate(
        model: plugin.modelRef('liquid/d1'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(server.last.$1.url.toString(), 'https://api.liquid.test/decide');
      expect(server.last.$2['model'], 'd1');
    });

    test('an empty path is the default one, as in Go', () async {
      final server = FakeServer();
      final plugin = SystemOne(
        provider: 'liquid',
        baseUrl: 'https://api.liquid.test',
        path: '',
        httpClient: server.client,
      );
      await genkitWith(plugin).generate(
        model: plugin.modelRef('d1'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(
        server.last.$1.url.toString(),
        'https://api.liquid.test/v1/systemone',
      );
    });

    test('a preset takes the overrides Go allows', () async {
      final server = FakeServer();
      final plugin = SystemOne.ollama(
        baseUrl: 'http://gpu-box:11434',
        path: '/decide',
        audio: MediaSupport.supported,
        httpClient: server.client,
      );
      await genkitWith(plugin).generate(
        model: plugin.modelRef('clef'),
        promptParts: [
          TextPart(text: 'Hear this'),
          MediaPart(media: Media(url: 'data:audio/wav;base64,AAA')),
        ],
        outputSchema: Triage.$schema,
      );
      final (req, body) = server.last;
      expect(req.url.toString(), 'http://gpu-box:11434/decide');
      expect(body['audio'], ['data:audio/wav;base64,AAA']);
    });

    test('a base URL with no scheme is a configuration error', () {
      expect(
        () => SystemOne(provider: 'p', baseUrl: 'decisions.example.com'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.failedPrecondition,
          ),
        ),
      );
    });

    test('a cancelled call returns at once, resolved as aborted', () async {
      // The server would answer validly, but late: only the cancel can make
      // the call return early and aborted.
      final server = FakeServer();
      final slow = FakeServer(
        reply: (req) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return server.client.send(req).then(http.Response.fromStream);
        },
      );
      final plugin = typeSafe(slow);
      final controller = CancellationController();
      final watch = Stopwatch()..start();
      final call = genkitWith(plugin).generate(
        model: plugin.modelRef('jev-1.13.0'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
        cancel: controller.token,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.cancel('user left');
      final result = await call;
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(result.finishReason, FinishReason.aborted);
      expect(result.output, isNull);
    });

    test('a config of the wrong type is INVALID_ARGUMENT', () async {
      final server = FakeServer();
      final plugin = typeSafe(server);
      final ai = genkitWith(plugin);
      for (final config in [
        {'extra': 'not an object'},
        {'stateJSON': 'yes'},
      ]) {
        final result = await ai.generate(
          model: modelRef<Map<String, dynamic>>(
            'typesafe/jev-1.13.0',
            config: config,
          ),
          prompt: _ticket,
          outputSchema: Triage.$schema,
        );
        expect(
          result,
          failed()
              .withStatus(StatusCode.invalidArgument)
              .withMessage(contains('does not fit SystemOneOptions')),
        );
      }
      expect(server.calls, 0);
    });

    test('a missing usage leaves the counts null', () async {
      final server = FakeServer(usage: {});
      final plugin = typeSafe(server);
      final result = await genkitWith(plugin).generate(
        model: plugin.modelRef('jev-1.13.0'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(result.usage?.inputTokens, isNull);
      expect(result.usage?.totalTokens, isNull);
    });

    group('preset models, as in Go', () {
      test('an entry with a known ID replaces its whole spec', () async {
        final server = FakeServer();
        final plugin = SystemOne.workersAI(
          accountId: 'a',
          httpClient: server.client,
          configVar: env({'CLOUDFLARE_API_TOKEN': 'cf'}),
          models: {'@cf/cloudflare/clef-omni': ModelSpec(label: 'Omni')},
        );
        final result = await genkitWith(plugin).generate(
          model: plugin.modelRef('@cf/cloudflare/clef-omni'),
          promptParts: [
            TextPart(text: 'Hear this'),
            MediaPart(media: Media(url: 'data:audio/wav;base64,AAA')),
          ],
          outputSchema: Triage.$schema,
        );
        // The preset's audio support went with the spec it replaced.
        expect(
          result,
          failed().withMessage(contains('reads no audio/wav media')),
        );
        final listed = await plugin.list();
        final omni = listed.firstWhere(
          (a) => a.name == 'cloudflare-decisions/@cf/cloudflare/clef-omni',
        );
        expect((omni.metadata['model'] as Map)['label'], 'Omni');
      });

      test('a new entry is added beside the preset models', () async {
        final plugin = SystemOne.typeSafe(
          httpClient: FakeServer().client,
          configVar: env({'TYPESAFE_API_KEY': 'k'}),
          models: {'typesafe/jev-1.14.0': ModelSpec(label: 'jev next')},
        );
        final names = (await plugin.list()).map((a) => a.name);
        expect(
          names,
          containsAll([
            'typesafe/jev-1.13.0',
            'typesafe/jev-latest',
            'typesafe/jev-1.14.0',
          ]),
        );
      });

      test('a full name for a preset model is refused', () {
        expect(
          () => SystemOne.typeSafe(
            configVar: env({'TYPESAFE_API_KEY': 'k'}),
            models: {'typesafe/jev-1.13.0': ModelSpec(label: 'x')},
          ),
          throwsA(
            isA<GenkitException>()
                .having(
                  (e) => e.status,
                  'status',
                  StatusCode.failedPrecondition,
                )
                .having(
                  (e) => e.message,
                  'message',
                  contains(
                    'already defined by the preset as jev-1.13.0; use the bare ID',
                  ),
                ),
          ),
        );
      });
    });

    test('a preset takes its provider name, and Ollama a key', () async {
      final server = FakeServer();
      final plugin = SystemOne.ollama(
        provider: 'clef-proxy',
        apiKey: 'proxy-key',
        httpClient: server.client,
      );
      expect(plugin.name, 'clef-proxy');
      await genkitWith(plugin).generate(
        model: plugin.modelRef('clef'),
        prompt: _ticket,
        outputSchema: Triage.$schema,
      );
      expect(server.last.$1.headers['Authorization'], 'Bearer proxy-key');
    });

    test('a model named twice is refused', () {
      expect(
        () => SystemOne(
          provider: 'liquid',
          baseUrl: 'https://api.liquid.test',
          models: {'d1': ModelSpec(), 'liquid/d1': ModelSpec()},
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('names d1 twice'),
          ),
        ),
      );
    });
  });

  group('listing', () {
    test('adds the listed models to the known ones', () async {
      final server = FakeServer(
        models: '{"models":[{"name":"jev-1.14.0"},{"name":"jev-latest"}]}',
      );
      final plugin = typeSafe(server);
      final first = await plugin.list();
      expect(first.map((a) => a.name), [
        'typesafe/jev-1.13.0',
        'typesafe/jev-1.14.0',
        'typesafe/jev-latest',
      ]);
      final metadata = first.first.metadata['model'] as Map;
      expect(metadata['label'], 'TypeSafe - jev-1.13.0');
      expect((metadata['supports'] as Map)['constrained'], 'all');
      expect((metadata['supports'] as Map)['media'], isFalse);
      expect(server.listings, ['/v1/models']);
    });

    test('falls back to the known models when the listing fails', () async {
      final server = FakeServer();
      final plugin = SystemOne.openRouter(
        httpClient: server.client,
        configVar: env({'OPENROUTER_API_KEY': 'k'}),
        models: {'~liquid/d1-latest': ModelSpec(label: 'd1, latest')},
      );
      final listed = await plugin.list();
      expect(server.listings, ['/api/v1/models?output_modalities=decisions']);
      expect(
        listed.map((a) => a.name),
        contains('openrouter-decisions/liquid/d1'),
      );
      final custom = listed.firstWhere(
        (a) => a.name == 'openrouter-decisions/~liquid/d1-latest',
      );
      expect((custom.metadata['model'] as Map)['label'], 'd1, latest');
    });
  });

  test('the registry asks the server for the listing once', () async {
    final server = FakeServer(models: '[{"name":"jev-1.14.0"}]');
    final ai = genkitWith(typeSafe(server));
    final first = await ai.registry.listActions();
    await ai.registry.listActions();
    expect(
      first.map((a) => a.name),
      containsAll(['typesafe/jev-1.13.0', 'typesafe/jev-1.14.0']),
    );
    expect(server.listings, hasLength(1));
  });

  test('modelRef takes the ID or the full name', () {
    final plugin = typeSafe(FakeServer());
    expect(plugin.modelRef('jev-1.13.0').name, 'typesafe/jev-1.13.0');
    expect(plugin.modelRef('typesafe/jev-1.13.0').name, 'typesafe/jev-1.13.0');
  });

  test('path segments are escaped as Go url.PathEscape does', () {
    expect(pathEscape('@cf'), '@cf');
    expect(
      pathEscape(r'a b;c,d?e/f!g$h&i+j:k=l~m'),
      r'a%20b%3Bc%2Cd%3Fe%2Ff%21g$h&i+j:k=l~m',
    );
    expect(pathEscape('é'), '%C3%A9');
  });

  test('Ollama sees text in turns, parts, and values as Go does', () {
    expect(hasText(''), isFalse);
    expect(
      hasText(<Map<String, Object?>>[
        {'role': 'user', 'content': ''},
      ]),
      isFalse,
    );
    expect(
      hasText(<Map<String, Object?>>[
        {'role': 'user', 'content': ''},
        {'role': 'model', 'content': 'hi'},
      ]),
      isTrue,
    );
    // A message's several values are not turns: any of them is text.
    expect(hasText(<Object?>['', '']), isTrue);
    expect(hasText({'ticket': 'x'}), isTrue);
    expect(hasText(<String, Object?>{}), isFalse);
  });
}
