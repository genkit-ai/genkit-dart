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
import 'package:genkit/src/ai/agents/agent_core.dart';
import 'package:test/test.dart';

/// A scripted transport: each turn returns the queued [_TurnScript].

class _FakeTransport extends AgentTransport {
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
  }) {
    final script = _next();
    return (stream: script.streamOf(), output: script.outputOf());
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
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
  Future<String?> abort(String snapshotId) async {
    aborted.add(snapshotId);
    return 'aborted';
  }
}

class _TurnScript {
  _TurnScript({this.chunks = const [], required this.output});

  final List<AgentStreamChunk> chunks;
  final AgentOutput output;

  Stream<AgentStreamChunk> streamOf() => Stream.fromIterable(chunks);
  Future<AgentOutput> outputOf() async => output;
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
      final turn = chat.sendStream(agentInputFromText('hi'));

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
      final turn = chat.sendStream(agentInputFromText('hi'));
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
                  op: 'replace',
                  path: '',
                  value: {'count': 0},
                ),
              ],
            ),
            AgentStreamChunk(
              customPatch: [
                JsonPatchOperation(op: 'replace', path: '/count', value: 1),
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
      final turn = chat.sendStream(agentInputFromText('go'));

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
      final res = await chat.send(agentInputFromText('ping'));
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
        chat.send(agentInputFromText('x')),
        throwsA(
          isA<AgentError>()
              .having((e) => e.status, 'status', 'INTERNAL')
              .having((e) => e.message, 'message', 'boom')
              .having((e) => e.state, 'state', {'last': 'good'}),
        ),
      );
    });
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
        AgentResume(
          respond: [
            ToolResponsePart(
              toolResponse: ToolResponse(name: 'approve', output: true),
            ),
          ],
        ),
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
      await chat.send(agentInputFromText('hi'));
      final status = await chat.abort();
      expect(status, 'aborted');
      expect(transport.aborted, ['s_z']);
    });

    test('returns null when there is no snapshot', () async {
      final transport = _FakeTransport([]);
      final chat = AgentApi(transport).chat();
      expect(await chat.abort(), isNull);
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
      final response = AgentResponse(raw, []);
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
  });
}

/// A transport that captures the [AgentInput] and returns a fixed output.
class _CaptureTransport extends AgentTransport {
  _CaptureTransport(this._handler);

  final AgentOutput Function(AgentInput input) _handler;

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
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
  }) => Future.value(_handler(input));

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) async => null;

  @override
  Future<String?> abort(String snapshotId) async => null;
}
