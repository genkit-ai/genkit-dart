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
import 'package:test/test.dart';

/// Registers a simple echo model that replies with a fixed/templated message.
void _defineEchoModel(Genkit ai) {
  ai.defineModel(
    name: 'echo',
    fn: (request, ctx) async {
      final lastUser = request.messages.lastWhere(
        (m) => m.role == Role.user,
        orElse: () => request.messages.last,
      );
      final reply = 'echo: ${lastUser.text}';
      if (ctx.streamingRequested) {
        ctx.sendChunk(ModelResponseChunk(content: [TextPart(text: reply)]));
      }
      return ModelResponse(
        message: Message(
          role: Role.model,
          content: [TextPart(text: reply)],
        ),
        finishReason: FinishReason.stop,
      );
    },
  );
}

void main() {
  group('defineCustomAgent (client-managed)', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(promptDir: null);
    });

    tearDown(() => ai.shutdown());

    test('runs a turn and tracks client state across turns', () async {
      final agent = ai.defineCustomAgent(
        name: 'counter',
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            sess.updateCustom((custom) {
              final map = (custom as Map?)?.cast<String, dynamic>() ?? {};
              final count = (map['count'] as int?) ?? 0;
              return {'count': count + 1};
            });
            sess.addMessages([
              Message(
                role: Role.model,
                content: [TextPart(text: 'ok')],
              ),
            ]);
            return TurnResult(finishReason: AgentFinishReason.stop);
          });
          final msgs = sess.getMessages();
          return AgentResult(
            message: msgs.isNotEmpty ? msgs.last : null,
            finishReason: sess.lastTurnFinishReason,
          );
        },
      );

      final chat = agent.chat();
      final res1 = await chat.send(agentInputFromText('hi'));
      expect(res1.finishReason, AgentFinishReason.stop);
      expect(chat.state, {'count': 1});

      final res2 = await chat.send(agentInputFromText('again'));
      expect(res2.finishReason, AgentFinishReason.stop);
      expect(chat.state, {'count': 2});
    });

    test('streams model chunks and customPatch chunks', () async {
      final agent = ai.defineCustomAgent(
        name: 'streamer',
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            sess.updateCustom((_) => {'status': 'working'});
            options.sendChunk(
              AgentStreamChunk(
                modelChunk: ModelResponseChunk(
                  content: [TextPart(text: 'hello')],
                ),
              ),
            );
            sess.addMessages([
              Message(
                role: Role.model,
                content: [TextPart(text: 'hello')],
              ),
            ]);
            return TurnResult(finishReason: AgentFinishReason.stop);
          });
          final msgs = sess.getMessages();
          return AgentResult(message: msgs.last);
        },
      );

      final chat = agent.chat();
      final turn = chat.sendStream(agentInputFromText('go'));

      final texts = <String>[];
      final customs = <dynamic>[];
      await for (final c in turn.stream) {
        if (c.text.isNotEmpty) texts.add(c.text);
        if (c.custom != null) customs.add(c.custom);
      }
      final res = await turn.response;

      expect(texts, contains('hello'));
      expect(customs, [
        {'status': 'working'},
      ]);

      expect(res.text, 'hello');
      expect(chat.state, {'status': 'working'});
    });

    test('failed turn surfaces an AgentError with last-good state', () async {
      var turnCount = 0;
      final agent = ai.defineCustomAgent(
        name: 'flaky',
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            turnCount++;
            if (turnCount == 1) {
              sess.updateCustom((_) => {'ok': true});
              return TurnResult(finishReason: AgentFinishReason.stop);
            }
            throw GenkitException('boom', status: StatusCodes.INTERNAL);
          });
          final msgs = sess.getMessages();
          return AgentResult(
            message: msgs.isNotEmpty ? msgs.last : null,
            finishReason: sess.lastTurnFinishReason,
          );
        },
      );

      final chat = agent.chat();
      await chat.send(agentInputFromText('first'));
      expect(chat.state, {'ok': true});

      await expectLater(
        chat.send(agentInputFromText('second')),
        throwsA(
          isA<AgentError>()
              .having((e) => e.status, 'status', 'INTERNAL')
              .having((e) => e.message, 'message', 'boom')
              .having((e) => e.state, 'state', {'ok': true}),
        ),
      );
    });
  });

  group('defineCustomAgent (server-managed)', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(promptDir: null);
    });

    tearDown(() => ai.shutdown());

    test('persists snapshots and resumes a session by id', () async {
      final store = InMemorySessionStore();
      final agent = ai.defineCustomAgent(
        name: 'persistent',
        store: store,
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            sess.updateCustom((custom) {
              final map = (custom as Map?)?.cast<String, dynamic>() ?? {};
              final count = (map['count'] as int?) ?? 0;
              return {'count': count + 1};
            });
            return TurnResult(finishReason: AgentFinishReason.stop);
          });
          final msgs = sess.getMessages();
          return AgentResult(
            message: msgs.isNotEmpty ? msgs.last : null,
            finishReason: sess.lastTurnFinishReason,
          );
        },
      );

      final sessionId = generateUuidV4();
      final chat = agent.chat(sessionId: sessionId);
      final res1 = await chat.send(agentInputFromText('one'));
      expect(res1.snapshotId, isNotNull);

      // A fresh chat resuming the same session sees prior state.
      final snapshot = await agent.getSnapshot(sessionId: sessionId);
      expect(snapshot, isNotNull);
      expect(snapshot!.state?.custom, {'count': 1});

      final chat2 = agent.chat(sessionId: sessionId);
      await chat2.send(agentInputFromText('two'));
      final snapshot2 = await agent.getSnapshot(sessionId: sessionId);
      expect(snapshot2!.state?.custom, {'count': 2});
    });

    test('abort returns the prior status', () async {
      final store = InMemorySessionStore();
      final agent = ai.defineCustomAgent(
        name: 'abortable',
        store: store,
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            return TurnResult(finishReason: AgentFinishReason.stop);
          });
          return AgentResult(finishReason: sess.lastTurnFinishReason);
        },
      );

      final sessionId = generateUuidV4();
      final chat = agent.chat(sessionId: sessionId);
      final res = await chat.send(agentInputFromText('hi'));
      final prior = await agent.abort(res.snapshotId!);
      // Turn already completed, so abort reports the prior status.
      expect(prior, 'completed');
    });

    test(
      'getSnapshotData reports a stale pending snapshot as expired',
      () async {
        final store = InMemorySessionStore();
        final agent = ai.defineCustomAgent(
          name: 'heartbeating',
          store: store,
          fn: (sess, options) async {
            await sess.run((input, ctx) async => null);
            return AgentResult();
          },
        );

        final sessionId = generateUuidV4();
        // Seed a `pending` snapshot whose heartbeat is well past the timeout.
        final stale = DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 5))
            .toIso8601String();
        final id = await store.saveSnapshot(
          null,
          (_) => SessionSnapshot(
            snapshotId: '',
            createdAt: stale,
            updatedAt: stale,
            heartbeatAt: stale,
            status: SnapshotStatus.pending,
            state: SessionState(
              sessionId: sessionId,
              messages: [],
              artifacts: [],
            ),
          ),
        );

        // Stored status is still `pending`.
        final raw = await store.getSnapshot(snapshotId: id);
        expect(raw!.status?.value, 'pending');

        // ...but a read through the agent surfaces it as `expired`.
        final snapshot = await agent.getSnapshotData(snapshotId: id);
        expect(snapshot!.status?.value, 'expired');

        // The expiry is read-only: the stored snapshot stays `pending`.
        final after = await store.getSnapshot(snapshotId: id);
        expect(after!.status?.value, 'pending');
      },
    );

    test('getSnapshotData requires a store', () async {
      final agent = ai.defineCustomAgent(
        name: 'noStore',
        fn: (sess, options) async {
          await sess.run((input, ctx) async => null);
          return AgentResult();
        },
      );
      await expectLater(
        agent.getSnapshotData(snapshotId: 's_x'),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('defineAgent (prompt-backed)', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(promptDir: null);
      _defineEchoModel(ai);
    });

    tearDown(() => ai.shutdown());

    test('runs a prompt-driven turn and echoes the user message', () async {
      final agent = ai.defineAgent(
        name: 'assistant',
        model: modelRef('echo'),
        system: 'You are helpful.',
      );

      final chat = agent.chat();
      final res = await chat.send(agentInputFromText('world'));
      expect(res.text, 'echo: world');
      expect(res.finishReason, AgentFinishReason.stop);
    });

    test('accumulates history across turns', () async {
      final agent = ai.defineAgent(name: 'assistant2', model: modelRef('echo'));

      final chat = agent.chat();
      await chat.send(agentInputFromText('first'));
      final res2 = await chat.send(agentInputFromText('second'));
      expect(res2.text, 'echo: second');
      // History should include both user turns + model replies.
      expect(chat.messages.length, greaterThanOrEqualTo(4));
    });
  });

  group('currentSession', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(promptDir: null);
    });

    tearDown(() => ai.shutdown());

    test('is available inside an agent turn', () async {
      Session? seen;
      final agent = ai.defineCustomAgent(
        name: 'introspect',
        fn: (sess, options) async {
          await sess.run((input, ctx) async {
            seen = ai.currentSession();
            return TurnResult(finishReason: AgentFinishReason.stop);
          });
          return AgentResult(finishReason: sess.lastTurnFinishReason);
        },
      );

      expect(ai.currentSession(), isNull);
      await agent.chat().send(agentInputFromText('hi'));
      expect(seen, isNotNull);
    });
  });
}
