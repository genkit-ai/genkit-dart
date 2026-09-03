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
import 'package:genkit_middleware/agents.dart';
import 'package:test/test.dart';

/// Coerces a tool response output into a JSON map.
Map<String, dynamic> _asMap(Object? output) {
  if (output is AgentDelegationResult) return output.toJson();
  if (output is BackgroundTasksResult) return output.toJson();
  return output as Map<String, dynamic>;
}

/// A scripted orchestrator model: each entry is a turn producing either tool
/// requests or a final text answer. Tool-loop turns are consumed in order; the
/// last entry (or the fallback) ends the loop with text.
class _Script {
  _Script(this.turns);
  final List<ModelResponse> turns;
  int _i = 0;

  void install(Genkit ai, String name) {
    ai.defineModel(
      name: name,
      fn: (req, ctx) async {
        final turn = _i < turns.length ? turns[_i] : turns.last;
        _i++;
        return turn;
      },
    );
  }
}

ModelResponse _toolCall(
  String tool,
  Map<String, dynamic> input, {
  String? ref,
}) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [
      ToolRequestPart(
        toolRequest: ToolRequest(name: tool, ref: ref, input: input),
      ),
    ],
  ),
);

ModelResponse _text(String text) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [TextPart(text: text)],
  ),
);

/// Returns the output map of the tool response with the given name, or `null`.
Map<String, dynamic>? _toolOutput(List<Message> messages, String name) {
  for (final m in messages.where((m) => m.role == Role.tool)) {
    for (final p in m.content) {
      final tr = p.toolResponse;
      if (tr != null && tr.name == name) return _asMap(tr.output);
    }
  }
  return null;
}

void main() {
  group('AgentsMiddleware async', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(isDevEnv: false, plugins: [AgentsPlugin()]);
    });

    tearDown(() async {
      await ai.shutdown();
    });

    test(
      'background delegation returns a pending taskId and check/wait collect '
      'the result',
      () async {
        _defineEchoAgent(ai, 'worker', 'worker-model', 'work done');

        String? taskId;
        final script = _Script([
          // Turn 1: launch in the background.
          _toolCall('delegate_to_worker', {
            'task': 'do async work',
            'background': true,
          }),
          // Turn 2: wait for it. taskId is filled in below via a wrapper model.
          _text('unused'),
        ]);

        // Custom orchestrator: capture the pending taskId from turn 1's tool
        // response, then call wait_for_background_tasks with it.
        var turn = 0;
        ai.defineModel(
          name: 'orchestrator',
          fn: (req, ctx) async {
            turn++;
            if (turn == 1) {
              return _toolCall('delegate_to_worker', {
                'task': 'do async work',
                'background': true,
              });
            }
            if (turn == 2) {
              final launch = _toolOutput(req.messages, 'delegate_to_worker')!;
              expect(launch['status'], 'pending');
              taskId = launch['taskId'] as String;
              expect(taskId, startsWith('worker:'));
              return _toolCall('wait_for_background_tasks', {
                'taskIds': [taskId],
              });
            }
            final waited = _toolOutput(
              req.messages,
              'wait_for_background_tasks',
            )!;
            final tasks = waited['tasks'] as List;
            expect(tasks, hasLength(1));
            final report = tasks.first as Map<String, dynamic>;
            expect(report['status'], 'completed');
            expect(report['response'], contains('work done'));
            return _text('all done: ${report['response']}');
          },
        );

        final result = await ai.generate(
          model: modelRef('orchestrator'),
          prompt: 'run async work and collect it',
          maxTurns: 10,
          use: [
            agents(agents: ['worker'], async: true),
          ],
        );

        expect(result.text, contains('work done'));
        // Keep the script referenced so the analyzer doesn't flag it.
        expect(script.turns, isNotEmpty);
      },
    );

    test('background launch is refused for a client-managed agent', () async {
      // No store => client-managed => cannot detach.
      ai.defineCustomAgent(
        name: 'local',
        fn: (sess, options) async => AgentResult(
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'hi')],
          ),
          finishReason: AgentFinishReason.stop,
        ),
      );

      var turn = 0;
      Map<String, dynamic>? launch;
      ai.defineModel(
        name: 'orchestrator-refuse',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('delegate_to_local', {
              'task': 'do it',
              'background': true,
            });
          }
          launch = _toolOutput(req.messages, 'delegate_to_local');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-refuse'),
        prompt: 'try background on a local agent',
        maxTurns: 5,
        use: [
          agents(agents: ['local'], async: true),
        ],
      );

      expect(launch, isNotNull);
      expect(launch!['taskId'], isNull);
      expect(
        launch!['response'] as String,
        contains('cannot run in the background'),
      );
    });

    test('check_background_tasks reports an unresolvable taskId', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'done');

      var turn = 0;
      Map<String, dynamic>? checked;
      ai.defineModel(
        name: 'orchestrator-unknown',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('check_background_tasks', {
              'taskIds': ['worker:does-not-exist'],
            });
          }
          checked = _toolOutput(req.messages, 'check_background_tasks');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-unknown'),
        prompt: 'check a bogus task',
        maxTurns: 5,
        use: [
          agents(agents: ['worker'], async: true),
        ],
      );

      expect(checked, isNotNull);
      final tasks = checked!['tasks'] as List;
      final report = tasks.first as Map<String, dynamic>;
      expect(report['status'], 'unknown');
      expect(report['error'], isNotNull);
    });

    test('background-task tools guide when called with no task IDs', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'done');

      var turn = 0;
      Map<String, dynamic>? checked;
      ai.defineModel(
        name: 'orchestrator-empty',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('check_background_tasks', <String, dynamic>{});
          }
          checked = _toolOutput(req.messages, 'check_background_tasks');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-empty'),
        prompt: 'check with no ids',
        maxTurns: 5,
        use: [
          agents(agents: ['worker'], async: true),
        ],
      );

      expect(checked, isNotNull);
      expect(checked!['note'] as String, contains('No task IDs'));
    });

    test(
      'synchronous delegation to a server-managed agent carries a taskId',
      () async {
        _defineEchoAgent(ai, 'worker', 'worker-model', 'sync done');

        var turn = 0;
        Map<String, dynamic>? delegation;
        ai.defineModel(
          name: 'orchestrator-sync',
          fn: (req, ctx) async {
            turn++;
            if (turn == 1) {
              return _toolCall('delegate_to_worker', {'task': 'do it'});
            }
            delegation = _toolOutput(req.messages, 'delegate_to_worker');
            return _text('ok');
          },
        );

        await ai.generate(
          model: modelRef('orchestrator-sync'),
          prompt: 'delegate synchronously',
          maxTurns: 5,
          use: [
            agents(agents: ['worker'], async: true),
          ],
        );

        expect(delegation, isNotNull);
        expect(delegation!['response'], contains('sync done'));
        expect(delegation!['taskId'], startsWith('worker:'));
        expect(delegation!['status'], 'completed');
      },
    );

    test('continue_task follows up on a completed task', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'first answer');

      var turn = 0;
      String? taskId;
      Map<String, dynamic>? continued;
      ai.defineModel(
        name: 'orchestrator-continue',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('delegate_to_worker', {'task': 'first'});
          }
          if (turn == 2) {
            final d = _toolOutput(req.messages, 'delegate_to_worker')!;
            taskId = d['taskId'] as String;
            return _toolCall('continue_task', {
              'taskId': taskId,
              'instructions': 'now the follow-up',
            });
          }
          continued = _toolOutput(req.messages, 'continue_task');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-continue'),
        prompt: 'delegate then continue',
        maxTurns: 6,
        use: [
          agents(agents: ['worker'], async: true),
        ],
      );

      expect(continued, isNotNull);
      // The echo agent replies the same text; the point is that continuing a
      // completed task with instructions runs another turn and returns a result
      // (not a refusal).
      expect(continued!['response'], contains('first answer'));
      expect(continued!['taskId'], startsWith('worker:'));
    });

    test(
      'continue_task refuses an empty follow-up on a completed task',
      () async {
        _defineEchoAgent(ai, 'worker', 'worker-model', 'answer');

        var turn = 0;
        Map<String, dynamic>? continued;
        ai.defineModel(
          name: 'orchestrator-empty-continue',
          fn: (req, ctx) async {
            turn++;
            if (turn == 1) {
              return _toolCall('delegate_to_worker', {'task': 'first'});
            }
            if (turn == 2) {
              final d = _toolOutput(req.messages, 'delegate_to_worker')!;
              return _toolCall('continue_task', {'taskId': d['taskId']});
            }
            continued = _toolOutput(req.messages, 'continue_task');
            return _text('ok');
          },
        );

        await ai.generate(
          model: modelRef('orchestrator-empty-continue'),
          prompt: 'delegate then continue with nothing',
          maxTurns: 6,
          use: [
            agents(agents: ['worker'], async: true),
          ],
        );

        expect(continued, isNotNull);
        expect(continued!['response'] as String, contains('already completed'));
      },
    );

    test('continue_task rejects a client-managed agent', () async {
      ai.defineCustomAgent(
        name: 'local',
        fn: (sess, options) async => AgentResult(
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'hi')],
          ),
          finishReason: AgentFinishReason.stop,
        ),
      );

      var turn = 0;
      Map<String, dynamic>? continued;
      ai.defineModel(
        name: 'orchestrator-local-continue',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('continue_task', {
              'taskId': 'local:whatever',
              'instructions': 'go',
            });
          }
          continued = _toolOutput(req.messages, 'continue_task');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-local-continue'),
        prompt: 'continue a client-managed task',
        maxTurns: 5,
        use: [
          agents(agents: ['local'], async: true),
        ],
      );

      expect(continued, isNotNull);
      expect(
        continued!['response'] as String,
        contains('manages its state on the client'),
      );
    });

    test('continue_task reports an unresolvable taskId', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'done');

      var turn = 0;
      Map<String, dynamic>? continued;
      ai.defineModel(
        name: 'orchestrator-badid',
        fn: (req, ctx) async {
          turn++;
          if (turn == 1) {
            return _toolCall('continue_task', {'taskId': 'nope:123'});
          }
          continued = _toolOutput(req.messages, 'continue_task');
          return _text('ok');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-badid'),
        prompt: 'continue a bogus id',
        maxTurns: 5,
        use: [
          agents(agents: ['worker'], async: true),
        ],
      );

      expect(continued, isNotNull);
      expect(
        continued!['response'] as String,
        contains('does not match any configured agent'),
      );
    });

    test('async tools are absent when async is not enabled', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'done');

      final toolNames = <String>{};
      ai.defineModel(
        name: 'orchestrator-tools',
        fn: (req, ctx) async {
          toolNames.addAll(req.tools?.map((t) => t.name) ?? const []);
          return _text('done');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-tools'),
        prompt: 'list tools',
        use: [
          agents(agents: ['worker']),
        ],
      );

      expect(toolNames, contains('delegate_to_worker'));
      // continue_task is always available.
      expect(toolNames, contains('continue_task'));
      // Background-task tools require async.
      expect(toolNames, isNot(contains('check_background_tasks')));
      expect(toolNames, isNot(contains('wait_for_background_tasks')));
      expect(toolNames, isNot(contains('abort_background_tasks')));
    });

    test('async tools are present when async is enabled', () async {
      _defineEchoAgent(ai, 'worker', 'worker-model', 'done');

      final toolNames = <String>{};
      ai.defineModel(
        name: 'orchestrator-tools-async',
        fn: (req, ctx) async {
          toolNames.addAll(req.tools?.map((t) => t.name) ?? const []);
          return _text('done');
        },
      );

      await ai.generate(
        model: modelRef('orchestrator-tools-async'),
        prompt: 'list tools',
        use: [
          agents(agents: ['worker'], async: true),
        ],
      );

      expect(toolNames, contains('delegate_to_worker'));
      expect(toolNames, contains('check_background_tasks'));
      expect(toolNames, contains('wait_for_background_tasks'));
      expect(toolNames, contains('abort_background_tasks'));
      expect(toolNames, contains('continue_task'));
    });
  });
}

/// Defines a server-managed (store-backed, so detach-capable) agent whose model
/// echoes a fixed [reply].
void _defineEchoAgent(Genkit ai, String name, String modelName, String reply) {
  ai.defineModel(
    name: modelName,
    fn: (req, ctx) async => ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: reply)],
      ),
    ),
  );
  ai.defineAgent(
    name: name,
    model: modelRef(modelName),
    system: 'You are $name.',
    store: InMemorySessionStore(),
  );
}
