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
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

/// A small domain type used to exercise schema-aware (parsed) `State` typing.
/// Uses the BYOT bridge (`SchemanticType.from`) so the test needs no codegen.
class _Counter {
  _Counter(this.count);

  final int count;

  factory _Counter.fromJson(Map<String, dynamic> json) =>
      _Counter(json['count'] as int);

  static final schema = SchemanticType.from<_Counter>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'count': {'type': 'integer'},
      },
      'required': ['count'],
    },
    parse: (json) => _Counter.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// A scripted transport: each turn returns the queued [_TurnScript].
final class _FakeTransport extends AgentTransport {
  _FakeTransport(this._scripts, {this.supportsRun = false});

  final List<_TurnScript> _scripts;
  final bool supportsRun;
  int _index = 0;
  final Map<String, SessionSnapshot> snapshots = {};
  final List<String> aborted = [];

  _TurnScript _next() => _scripts[_index++];

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) {
    final script = _next();
    return (stream: script.streamOf(), output: script.outputOf());
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) {
    if (!supportsRun) return null;
    return _next().outputOf();
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) async => snapshots[snapshotId];

  @override
  Future<SnapshotStatus?> abort(String snapshotId) async {
    aborted.add(snapshotId);
    return SnapshotStatus.aborted;
  }
}

class _TurnScript {
  _TurnScript({this.chunks = const [], required this.output});

  final List<AgentStreamChunk> chunks;
  final AgentOutput output;

  Stream<AgentStreamChunk> streamOf() => Stream.fromIterable(chunks);
  Future<AgentOutput> outputOf() async => output;
}

/// A single scripted step for [_StepTransport]: either yields [output] or
/// throws [error] from the turn's `output` future.
class _Step {
  _Step.output(this.output) : error = null;
  _Step.error(this.error) : output = null;

  final AgentOutput? output;
  final Error? error;

  Future<AgentOutput> resolve() async {
    final err = error;
    if (err != null) throw err;
    return output!;
  }
}

_Step _outputStep(AgentOutput output) => _Step.output(output);
_Step _throwStep(String message) => _Step.error(StateError(message));

/// A transport whose turns can throw, to exercise the thrown-error rollback.
final class _StepTransport extends AgentTransport {
  _StepTransport(this._steps, {this.supportsRun = false});

  final List<_Step> _steps;
  final bool supportsRun;
  int _index = 0;

  _Step _next() => _steps[_index++];

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) {
    final step = _next();
    return (
      stream: const Stream<AgentStreamChunk>.empty(),
      output: step.resolve(),
    );
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) {
    if (!supportsRun) return null;
    return _next().resolve();
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) async => null;

  @override
  Future<SnapshotStatus?> abort(String snapshotId) async => null;
}

Message _modelMessage(String text) => Message(
  role: Role.model,
  content: [TextPart(text: text)],
);

AgentStreamChunk _textChunk(String text) => AgentStreamChunk(
  modelChunk: ModelResponseChunk(content: [TextPart(text: text)]),
);

void main() {
  group('AgentChat.sendStream', () {
    test('streams chunks and resolves the final response', () async {
      final transport = _FakeTransport([
        _TurnScript(
          chunks: [_textChunk('Hello '), _textChunk('world')],
          output: AgentOutput(
            snapshotId: 's_x',
            message: _modelMessage('Hello world'),
            finishReason: AgentFinishReason.stop,
          ),
        ),
      ]);
      final chat = AgentApi(transport).chat();
      final turn = chat.sendStream(text: 'hi');

      final texts = <String>[];
      await for (final c in turn.stream) {
        texts.add(c.text);
      }
      expect(texts, ['Hello ', 'world']);

      final res = await turn.response;
      expect(res.text, 'Hello world');
      expect(res.snapshotId, 's_x');
      expect(res.finishReason, AgentFinishReason.stop);
      // The chat tracked the snapshot for the next turn.
      expect(chat.snapshotId, 's_x');
    });

    test('accumulatedText accumulates across chunks', () async {
      final transport = _FakeTransport([
        _TurnScript(
          chunks: [_textChunk('a'), _textChunk('b'), _textChunk('c')],
          output: AgentOutput(message: _modelMessage('abc')),
        ),
      ]);
      final chat = AgentApi(transport).chat();
      final turn = chat.sendStream(text: 'hi');
      final acc = <String>[];
      await for (final c in turn.stream) {
        acc.add(c.accumulatedText);
      }
      expect(acc, ['a', 'ab', 'abc']);
    });

    test('applies customPatch and surfaces live custom on chunks', () async {
      final transport = _FakeTransport([
        _TurnScript(
          chunks: [
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '',
                  value: {'count': 0},
                ),
              ],
            ),
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '/count',
                  value: 1,
                ),
              ],
            ),
          ],
          output: AgentOutput(
            state: SessionState(custom: {'count': 1}),
            message: _modelMessage('done'),
          ),
        ),
      ]);
      final chat = AgentApi(transport).chat();
      final turn = chat.sendStream(text: 'go');

      final customs = <dynamic>[];
      await for (final c in turn.stream) {
        if (c.custom != null) customs.add(c.custom);
      }
      await turn.response;

      expect(customs, [
        {'count': 0},
        {'count': 1},
      ]);
      expect(chat.state, {'count': 1});
    });
  });

  group('AgentChat.send', () {
    test('uses the non-streaming transport path when available', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            snapshotId: 's_y',
            message: _modelMessage('pong'),
            finishReason: AgentFinishReason.stop,
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi(transport).chat();
      final res = await chat.send(text: 'ping');
      expect(res.text, 'pong');
      expect(res.snapshotId, 's_y');
    });

    test('throws AgentError with recoverable state on a failed turn', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            finishReason: AgentFinishReason.failed,
            state: SessionState(custom: {'last': 'good'}),
            error: AgentErrorInfo(status: 'INTERNAL', message: 'boom'),
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi(transport).chat();
      await expectLater(
        chat.send(text: 'x'),
        throwsA(
          isA<AgentError>()
              .having((e) => e.status, 'status', 'INTERNAL')
              .having((e) => e.message, 'message', 'boom')
              .having((e) => e.state, 'state', {'last': 'good'}),
        ),
      );
    });
  });

  group('AgentChat pre-aborted bail', () {
    test(
      'send() bails before dispatching when the token is cancelled',
      () async {
        final transport = _FakeTransport([], supportsRun: true);
        final token = CancellationToken()..cancel();
        final chat = AgentApi(transport).chat();
        final res = await chat.send(text: 'hi', cancel: token);
        expect(res.finishReason, AgentFinishReason.aborted);
        // No user message was pushed and no turn was dispatched.
        expect(chat.messages, isEmpty);
      },
    );

    test(
      'sendStream() bails with an empty stream when the token is cancelled',
      () async {
        final transport = _FakeTransport([]);
        final token = CancellationToken()..cancel();
        final chat = AgentApi(transport).chat();
        final turn = chat.sendStream(text: 'hi', cancel: token);
        final chunks = <AgentChunk>[];
        await for (final c in turn.stream) {
          chunks.add(c);
        }
        expect(chunks, isEmpty);
        final res = await turn.response;
        expect(res.finishReason, AgentFinishReason.aborted);
        // No user message was pushed and no turn was dispatched.
        expect(chat.messages, isEmpty);
      },
    );
  });

  group('AgentChat.resume', () {
    test('passes resume payload through to the transport', () async {
      late AgentInput captured;
      final transport = _CaptureTransport((input) {
        captured = input;
        return AgentOutput(message: _modelMessage('ok'));
      });
      final chat = AgentApi(transport).chat();
      await chat.resume(
        respond: [
          ToolResponsePart(
            toolResponse: ToolResponse(name: 'approve', output: true),
          ),
        ],
      );
      expect(captured.resume, isNotNull);
      expect(captured.resume!.respond!.first.toolResponse.name, 'approve');
    });
  });

  group('AgentChat.abort', () {
    test('aborts the tracked snapshot', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(snapshotId: 's_z', message: _modelMessage('hi')),
        ),
      ], supportsRun: true);
      final chat = AgentApi(transport).chat();
      await chat.send(text: 'hi');
      final status = await chat.abort();
      expect(status?.value, 'aborted');
      expect(transport.aborted, ['s_z']);
    });

    test('returns null when there is no snapshot', () async {
      final transport = _FakeTransport([]);
      final chat = AgentApi(transport).chat();
      expect(await chat.abort(), isNull);
    });
  });

  group('AgentChat.sessionId', () {
    test('is adopted from connectInit on construction', () {
      final transport = _FakeTransport([]);
      final chat = AgentApi(transport).chat(sessionId: 'sess_1');
      expect(chat.sessionId, 'sess_1');
    });

    test('is restored from a hydrated state', () {
      final transport = _FakeTransport([]);
      final chat = AgentApi(transport).chat(
        state: SessionState(sessionId: 'sess_2', custom: {'a': 1}),
      );
      expect(chat.sessionId, 'sess_2');
    });

    test(
      'is adopted from a turn output and surfaced on the response',
      () async {
        final transport = _FakeTransport([
          _TurnScript(
            output: AgentOutput(
              snapshotId: 's_1',
              sessionId: 'sess_3',
              message: _modelMessage('hi'),
            ),
          ),
        ], supportsRun: true);
        final chat = AgentApi(transport).chat();
        final res = await chat.send(text: 'hi');
        expect(chat.sessionId, 'sess_3');
        expect(res.sessionId, 'sess_3');
      },
    );
  });

  group('AgentChat message rollback on error', () {
    test(
      'a thrown transport error rolls back the eager user message',
      () async {
        final transport = _StepTransport([
          _throwStep('INTERNAL: transport blew up'),
        ], supportsRun: true);
        final chat = AgentApi(transport).chat();
        await expectLater(chat.send(text: 'hi'), throwsA(isA<AgentError>()));
        // The eagerly-pushed user message must not be left orphaned.
        expect(chat.messages, isEmpty);
      },
    );

    test(
      'a follow-up send after a thrown error does not stack a stale message',
      () async {
        final transport = _StepTransport([
          _throwStep('INTERNAL: transport blew up'),
          _outputStep(
            AgentOutput(
              message: _modelMessage('pong'),
              finishReason: AgentFinishReason.stop,
            ),
          ),
        ], supportsRun: true);
        final chat = AgentApi(transport).chat();
        await expectLater(chat.send(text: 'first'), throwsA(isA<AgentError>()));
        expect(chat.messages, isEmpty);

        final res = await chat.send(text: 'second');
        expect(res.text, 'pong');
        // Only the second turn's user + model messages remain; the first
        // (failed) turn's user message did not stack.
        expect(chat.messages.length, 2);
        expect(chat.messages.first.content.first.text, 'second');
      },
    );
  });

  group('CancellationToken.onCancel', () {
    test('fires registered callbacks on cancel', () {
      final token = CancellationToken();
      var fired = 0;
      token.onCancel(() => fired++);
      token.onCancel(() => fired++);
      expect(fired, 0);
      token.cancel();
      expect(fired, 2);
    });

    test('only fires once even if cancel is called repeatedly', () {
      final token = CancellationToken();
      var fired = 0;
      token.onCancel(() => fired++);
      token
        ..cancel()
        ..cancel();
      expect(fired, 1);
    });

    test('the disposer unregisters the callback', () {
      final token = CancellationToken();
      var fired = 0;
      final dispose = token.onCancel(() => fired++);
      dispose();
      token.cancel();
      expect(fired, 0);
    });

    test('runs the callback synchronously if already cancelled', () {
      final token = CancellationToken()..cancel();
      var fired = 0;
      final dispose = token.onCancel(() => fired++);
      expect(fired, 1);
      // The disposer for an already-cancelled token is a harmless no-op.
      expect(dispose, returnsNormally);
    });
  });

  group('AgentInterrupt', () {
    test('respond/restart build the right parts', () {
      final part = ToolRequestPart(
        toolRequest: ToolRequest(
          name: 'userApproval',
          ref: 'r1',
          input: {'amount': 500},
        ),
        metadata: {'interrupt': true},
      );
      final raw = AgentOutput(
        message: Message(role: Role.model, content: [part]),
      );
      final response = AgentResponse.forTesting(raw, []);
      expect(response.interrupts.length, 1);
      final interrupt = response.interrupts.first;
      expect(interrupt.name, 'userApproval');
      expect(interrupt.ref, 'r1');

      final respondPart = interrupt.respond({'approved': true});
      expect(respondPart.toolResponse.name, 'userApproval');
      expect(respondPart.toolResponse.output, {'approved': true});

      final restartPart = interrupt.restart();
      expect(restartPart.toolRequest.name, 'userApproval');
      expect(restartPart.toolRequest.input, {'amount': 500});
    });

    test('restart preserves non-Map (list/scalar) tool inputs', () {
      for (final input in <Object?>[
        [1, 2, 3],
        'just-a-string',
        42,
        true,
      ]) {
        final part = ToolRequestPart(
          toolRequest: ToolRequest(name: 'tool', ref: 'r', input: input),
          metadata: {'interrupt': true},
        );
        final response = AgentResponse.forTesting(
          AgentOutput(
            message: Message(role: Role.model, content: [part]),
          ),
          [],
        );
        final restartPart = response.interrupts.first.restart();
        // The original input round-trips verbatim, no coercion to a Map.
        expect(restartPart.toolRequest.input, input);
      }
    });
  });

  group('generic State typing (wire -> client)', () {
    test('typed Map state flows from the wire to the client', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            state: SessionState(custom: {'count': 3}),
            message: _modelMessage('hi'),
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi<Map<String, dynamic>>(transport).chat();
      final res = await chat.send(text: 'hi');

      // The chat's tracked state and the response state are both typed Maps.
      expect(chat.state, isA<Map<String, dynamic>>());
      expect(chat.state?['count'], 3);
      expect(res.state, isA<Map<String, dynamic>>());
      expect(res.state?['count'], 3);
      // `res.state` and `chat.state` agree.
      expect(res.state, chat.state);
    });

    test(
      'typed state is recovered via the fallback when the wire omits state',
      () async {
        // A server-managed agent: the wire carries only a snapshotId plus
        // customPatch chunks; `state` is never sent. The chat tracks custom
        // state locally, and the typed fallback surfaces it on the response.
        final transport = _FakeTransport([
          _TurnScript(
            chunks: [
              AgentStreamChunk(
                customPatch: [
                  JsonPatchOperation(
                    op: JsonPatchOp.replace,
                    path: '',
                    value: {'count': 1},
                  ),
                ],
              ),
            ],
            output: AgentOutput(
              snapshotId: 's_1',
              message: _modelMessage('done'),
            ),
          ),
        ]);
        final chat = AgentApi<Map<String, dynamic>>(transport).chat();
        final turn = chat.sendStream(text: 'go');
        await for (final _ in turn.stream) {
          // Drain so the customPatch is applied.
        }
        final res = await turn.response;

        expect(chat.state, isA<Map<String, dynamic>>());
        expect(chat.state?['count'], 1);
        // No `state` on the wire, so this exercises the typed fallback.
        expect(res.raw.state, isNull);
        expect(res.state, isA<Map<String, dynamic>>());
        expect(res.state?['count'], 1);
      },
    );

    test('AgentChunk.custom is typed mid-stream', () async {
      final transport = _FakeTransport([
        _TurnScript(
          chunks: [
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '',
                  value: {'count': 0},
                ),
              ],
            ),
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '/count',
                  value: 1,
                ),
              ],
            ),
          ],
          output: AgentOutput(message: _modelMessage('done')),
        ),
      ]);
      final chat = AgentApi<Map<String, dynamic>>(transport).chat();
      final turn = chat.sendStream(text: 'go');

      final customs = <Map<String, dynamic>?>[];
      await for (final c in turn.stream) {
        if (c.custom != null) {
          // The chunk's custom state is statically typed as the chat's State.
          expect(c.custom, isA<Map<String, dynamic>>());
          customs.add(c.custom);
        }
      }
      await turn.response;

      expect(customs, [
        {'count': 0},
        {'count': 1},
      ]);
    });

    test('scalar State round-trips from the wire', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            state: SessionState(custom: 7),
            message: _modelMessage('hi'),
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi<int>(transport).chat();
      final res = await chat.send(text: 'hi');
      expect(chat.state, 7);
      expect(res.state, 7);
    });

    test('a mismatched State throws at read time', () async {
      // The wire carries a Map, but the chat is parameterized with String.
      // Dart generics are reified, so the turn resolves fine but *reading*
      // the state casts and throws (the documented contract).
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            state: SessionState(custom: {'a': 1}),
            message: _modelMessage('hi'),
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi<String>(transport).chat();
      final res = await chat.send(text: 'hi');
      expect(() => chat.state, throwsA(isA<TypeError>()));
      expect(() => res.state, throwsA(isA<TypeError>()));
    });

    test('loadChat preserves the typed State', () async {
      final transport = _FakeTransport([]);
      transport.snapshots['s1'] = SessionSnapshot(
        snapshotId: 's1',
        createdAt: 't',
        updatedAt: 't',
        status: SnapshotStatus.completed,
        state: SessionState(custom: {'k': 'v'}, messages: [], artifacts: []),
      );
      final chat = await AgentApi<Map<String, dynamic>>(
        transport,
      ).loadChat(snapshotId: 's1');
      expect(chat.state, isA<Map<String, dynamic>>());
      expect(chat.state?['k'], 'v');
    });
  });

  group('schema-aware State typing (SchemanticType<State>)', () {
    test('parses the wire state into a typed domain object', () async {
      final transport = _FakeTransport([
        _TurnScript(
          output: AgentOutput(
            state: SessionState(custom: {'count': 3}),
            message: _modelMessage('hi'),
          ),
        ),
      ], supportsRun: true);
      final chat = AgentApi<_Counter>(
        transport,
        stateSchema: _Counter.schema,
      ).chat();
      final res = await chat.send(text: 'hi');

      // With a schema, state is a *parsed* domain instance, not a raw Map.
      expect(chat.state, isA<_Counter>());
      expect(chat.state?.count, 3);
      expect(res.state, isA<_Counter>());
      expect(res.state?.count, 3);
    });

    test(
      'parses via the fallback when the wire omits state (server-managed)',
      () async {
        final transport = _FakeTransport([
          _TurnScript(
            chunks: [
              AgentStreamChunk(
                customPatch: [
                  JsonPatchOperation(
                    op: JsonPatchOp.replace,
                    path: '',
                    value: {'count': 5},
                  ),
                ],
              ),
            ],
            output: AgentOutput(
              snapshotId: 's_1',
              message: _modelMessage('done'),
            ),
          ),
        ]);
        final chat = AgentApi<_Counter>(
          transport,
          stateSchema: _Counter.schema,
        ).chat();
        final turn = chat.sendStream(text: 'go');
        await for (final _ in turn.stream) {
          // Drain so the customPatch is applied.
        }
        final res = await turn.response;

        expect(chat.state, isA<_Counter>());
        expect(chat.state?.count, 5);
        // No `state` on the wire, so this exercises the typed/parsed fallback.
        expect(res.raw.state, isNull);
        expect(res.state, isA<_Counter>());
        expect(res.state?.count, 5);
      },
    );

    test('AgentChunk.custom is a parsed domain object mid-stream', () async {
      final transport = _FakeTransport([
        _TurnScript(
          chunks: [
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '',
                  value: {'count': 0},
                ),
              ],
            ),
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(
                  op: JsonPatchOp.replace,
                  path: '/count',
                  value: 2,
                ),
              ],
            ),
          ],
          output: AgentOutput(message: _modelMessage('done')),
        ),
      ]);
      final chat = AgentApi<_Counter>(
        transport,
        stateSchema: _Counter.schema,
      ).chat();
      final turn = chat.sendStream(text: 'go');

      final counts = <int>[];
      await for (final c in turn.stream) {
        final custom = c.custom;
        if (custom != null) {
          expect(custom, isA<_Counter>());
          counts.add(custom.count);
        }
      }
      await turn.response;

      expect(counts, [0, 2]);
    });

    test('loadChat parses the typed State', () async {
      final transport = _FakeTransport([]);
      transport.snapshots['s1'] = SessionSnapshot(
        snapshotId: 's1',
        createdAt: 't',
        updatedAt: 't',
        status: SnapshotStatus.completed,
        state: SessionState(custom: {'count': 9}, messages: [], artifacts: []),
      );
      final chat = await AgentApi<_Counter>(
        transport,
        stateSchema: _Counter.schema,
      ).loadChat(snapshotId: 's1');
      expect(chat.state, isA<_Counter>());
      expect(chat.state?.count, 9);
    });

    test(
      'a failed turn surfaces parsed last-good state on AgentError',
      () async {
        final transport = _FakeTransport([
          _TurnScript(
            output: AgentOutput(
              finishReason: AgentFinishReason.failed,
              state: SessionState(custom: {'count': 42}),
              error: AgentErrorInfo(status: 'INTERNAL', message: 'boom'),
            ),
          ),
        ], supportsRun: true);
        final chat = AgentApi<_Counter>(
          transport,
          stateSchema: _Counter.schema,
        ).chat();
        await expectLater(
          chat.send(text: 'x'),
          throwsA(
            isA<AgentError<_Counter>>()
                .having((e) => e.status, 'status', 'INTERNAL')
                .having((e) => e.state, 'state', isA<_Counter>())
                .having((e) => e.state?.count, 'state.count', 42),
          ),
        );
      },
    );
  });
}

/// A transport that captures the [AgentInput] and returns a fixed output.
final class _CaptureTransport extends AgentTransport {
  _CaptureTransport(this._handler);

  final AgentOutput Function(AgentInput input) _handler;

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) {
    final output = _handler(input);
    return (
      stream: const Stream<AgentStreamChunk>.empty(),
      output: Future.value(output),
    );
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
    Map<String, dynamic>? context,
  }) => Future.value(_handler(input));

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) async => null;

  @override
  Future<SnapshotStatus?> abort(String snapshotId) async => null;
}
