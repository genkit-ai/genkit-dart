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

/// Coerces a tool response output into a JSON map. In-process, a tool with a
/// typed output schema returns the typed object (here [AgentDelegationResult]);
/// serialize it so assertions can read plain fields.
Map<String, dynamic> _asMap(Object? output) {
  if (output is AgentDelegationResult) return output.toJson();
  return output as Map<String, dynamic>;
}

/// A model that always echoes a fixed text response.
void _defineEchoModel(Genkit ai, String name, String text) {
  ai.defineModel(
    name: name,
    fn: (req, ctx) async => ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: text)],
      ),
    ),
  );
}

/// Returns the output of the first `tool` role message, coerced to a map.
Map<String, dynamic> _firstToolOutput(List<Message> messages) {
  final toolMsg = messages.firstWhere((m) => m.role == Role.tool);
  return _asMap(toolMsg.content.first.toolResponse!.output);
}

void main() {
  group('AgentsMiddleware', () {
    late Genkit ai;

    setUp(() {
      ai = Genkit(isDevEnv: false, plugins: [AgentsPlugin()]);
    });

    tearDown(() async {
      await ai.shutdown();
    });

    test('injects per-agent delegation tools and system prompt', () async {
      _defineEchoModel(
        ai,
        'researcher-model',
        'Research result: quantum computing is cool.',
      );

      ai.defineAgent(
        name: 'researcher',
        model: modelRef('researcher-model'),
        system: 'You are a research assistant.',
        store: InMemorySessionStore(),
      );

      var modelTurn = 0;
      ai.defineModel(
        name: 'main-model',
        fn: (req, ctx) async {
          modelTurn++;
          if (modelTurn == 1) {
            // Verify system prompt contains sub-agents instructions.
            final systemMsg = req.messages.firstWhere(
              (m) => m.role == Role.system,
            );
            expect(
              systemMsg.content.any(
                (p) => p.text?.contains('<sub-agents>') == true,
              ),
              isTrue,
              reason: 'System should contain sub-agent instructions',
            );
            expect(
              systemMsg.content.any(
                (p) => p.text?.contains('delegate_to_researcher') == true,
              ),
              isTrue,
              reason: 'System should reference per-agent tool name',
            );

            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_researcher',
                      input: {'task': 'Explain quantum computing briefly.'},
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
              content: [
                TextPart(
                  text: 'Based on the research: quantum computing uses qubits.',
                ),
              ],
            ),
          );
        },
      );

      final result = await ai.generate(
        model: modelRef('main-model'),
        prompt: 'Tell me about quantum computing',
        use: [
          agents(agents: ['researcher']),
        ],
      );

      expect(result.text, contains('quantum computing'));

      final toolMsg = result.messages.firstWhere((m) => m.role == Role.tool);
      final toolResponse = toolMsg.content.firstWhere(
        (p) => p.toolResponse != null,
      );
      expect(toolResponse.toolResponse!.name, 'delegate_to_researcher');
      final output = _asMap(toolResponse.toolResponse!.output);
      expect(
        output['response'] as String,
        contains('quantum computing'),
        reason: 'Sub-agent response should be in tool output',
      );
    });

    test('returns error message for unregistered agent', () async {
      _defineEchoModel(ai, 'coder-model', 'code result');
      ai.defineAgent(
        name: 'coder',
        model: modelRef('coder-model'),
        system: 'You write code.',
        store: InMemorySessionStore(),
      );

      var modelTurn = 0;
      ai.defineModel(
        name: 'main-err',
        fn: (req, ctx) async {
          modelTurn++;
          if (modelTurn == 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_nonexistent',
                      input: {'task': 'do something'},
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
              content: [TextPart(text: 'handled error')],
            ),
          );
        },
      );

      // 'nonexistent' is in the agents list (so its tool exists) but has no
      // corresponding agent registered — the middleware should return an error
      // as tool output instead of throwing.
      final result = await ai.generate(
        model: modelRef('main-err'),
        prompt: 'test',
        use: [
          agents(agents: ['coder', 'nonexistent']),
        ],
      );

      expect(result.text, isNotEmpty);
      final output = _firstToolOutput(result.messages);
      expect(output['response'] as String, contains('not found in registry'));
    });

    test('supports custom tool prefix', () async {
      _defineEchoModel(ai, 'helper-model', 'helped!');
      ai.defineAgent(
        name: 'helper',
        model: modelRef('helper-model'),
        system: 'You help.',
        store: InMemorySessionStore(),
      );

      var modelTurn = 0;
      ai.defineModel(
        name: 'main-custom',
        fn: (req, ctx) async {
          modelTurn++;
          if (modelTurn == 1) {
            final systemMsg = req.messages.firstWhere(
              (m) => m.role == Role.system,
            );
            expect(
              systemMsg.content.any(
                (p) => p.text?.contains('ask_helper') == true,
              ),
              isTrue,
              reason: 'System should reference custom tool name',
            );
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'ask_helper',
                      input: {'task': 'help me'},
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
              content: [TextPart(text: 'final')],
            ),
          );
        },
      );

      final result = await ai.generate(
        model: modelRef('main-custom'),
        prompt: 'test custom prefix',
        use: [
          agents(agents: ['helper'], toolPrefix: 'ask'),
        ],
      );

      expect(result.text, isNotEmpty);
    });

    test('auto-discovers agent descriptions from registry', () async {
      _defineEchoModel(ai, 'autodesc-model', 'discovered!');
      ai.defineAgent(
        name: 'smartagent',
        description: 'A very smart agent that knows everything.',
        model: modelRef('autodesc-model'),
        system: 'You know things.',
        store: InMemorySessionStore(),
      );

      var modelTurn = 0;
      ai.defineModel(
        name: 'main-autodesc',
        fn: (req, ctx) async {
          modelTurn++;
          if (modelTurn == 1) {
            final systemMsg = req.messages.firstWhere(
              (m) => m.role == Role.system,
            );
            expect(
              systemMsg.content.any(
                (p) =>
                    p.text?.contains(
                      'A very smart agent that knows everything',
                    ) ==
                    true,
              ),
              isTrue,
              reason: 'System should contain auto-discovered description',
            );
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'no tools needed')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          );
        },
      );

      final result = await ai.generate(
        model: modelRef('main-autodesc'),
        prompt: 'test auto-discovery',
        use: [
          agents(agents: ['smartagent']),
        ],
      );

      expect(result.text, isNotEmpty);
    });

    test('enforces maxDelegations limit', () async {
      _defineEchoModel(ai, 'sub-limit', 'sub result');
      ai.defineAgent(
        name: 'worker',
        model: modelRef('sub-limit'),
        system: 'You work.',
        store: InMemorySessionStore(),
      );

      var modelTurn = 0;
      ai.defineModel(
        name: 'main-limit',
        fn: (req, ctx) async {
          modelTurn++;
          if (modelTurn <= 3) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_worker',
                      input: {'task': 'task $modelTurn'},
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
              content: [TextPart(text: 'final')],
            ),
          );
        },
      );

      final result = await ai.generate(
        model: modelRef('main-limit'),
        prompt: 'test max delegations',
        maxTurns: 10,
        use: [
          agents(agents: ['worker'], maxDelegations: 2),
        ],
      );

      final toolMsgs = result.messages
          .where((m) => m.role == Role.tool)
          .toList();
      expect(
        toolMsgs.length,
        greaterThanOrEqualTo(3),
        reason: 'Should have at least 3 tool responses',
      );

      final limitResponse = toolMsgs.any(
        (m) => m.content.any((p) {
          if (p.toolResponse == null) return false;
          final response =
              _asMap(p.toolResponse!.output)['response'] as String?;
          return response?.contains('Delegation limit reached') == true;
        }),
      );
      expect(
        limitResponse,
        isTrue,
        reason: 'Should have a delegation limit response',
      );
    });

    test('throws if no agents provided', () {
      expect(
        () => AgentsPlugin().middleware().first.create(
          AgentsOptions(agents: []),
          (ai: ai),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('at least one agent'),
          ),
        ),
      );
    });

    test(
      'inline artifactStrategy includes artifact content in tool result',
      () async {
        final subArtifact = Artifact(
          name: 'result.md',
          parts: [TextPart(text: '# Research Results\nSome findings.')],
        );
        ai.defineCustomAgent(
          name: 'inlineResearcher',
          store: InMemorySessionStore(),
          fn: (sess, options) async {
            sess.addArtifacts([subArtifact]);
            return AgentResult(
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Here are my research results.')],
              ),
              artifacts: sess.getArtifacts(),
              finishReason: AgentFinishReason.stop,
            );
          },
        );

        var mainTurn = 0;
        Map<String, dynamic>? capturedToolOutput;
        ai.defineModel(
          name: 'main-inline',
          fn: (req, ctx) async {
            mainTurn++;
            if (mainTurn == 1) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(
                        name: 'delegate_to_inlineResearcher',
                        input: {'task': 'Research something.'},
                      ),
                    ),
                  ],
                ),
              );
            }
            capturedToolOutput = _firstToolOutput(req.messages);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Synthesis complete.')],
              ),
            );
          },
        );

        await ai.generate(
          model: modelRef('main-inline'),
          prompt: 'Research and summarize',
          use: [
            agents(agents: ['inlineResearcher'], artifactStrategy: 'inline'),
          ],
        );

        expect(capturedToolOutput, isNotNull);
        final artifacts = capturedToolOutput!['artifacts'] as List;
        expect(artifacts, isNotEmpty);
        final artifact = artifacts.first as Map<String, dynamic>;
        expect(
          artifact['name'] as String,
          contains('inlineResearcher'),
          reason: 'Artifact name should be namespaced with agent name',
        );
        expect(artifact['name'] as String, contains('result.md'));
        expect(
          artifact['content'] as String,
          contains('Research Results'),
          reason: 'Inline strategy should include content in tool result',
        );
      },
    );

    test(
      'session artifactStrategy includes only names in tool result',
      () async {
        final subArtifact = Artifact(
          name: 'code.ts',
          parts: [TextPart(text: 'console.log("hello world")')],
        );
        ai.defineCustomAgent(
          name: 'sessionCoder',
          store: InMemorySessionStore(),
          fn: (sess, options) async {
            sess.addArtifacts([subArtifact]);
            return AgentResult(
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Here is the code.')],
              ),
              artifacts: sess.getArtifacts(),
              finishReason: AgentFinishReason.stop,
            );
          },
        );

        var mainTurn = 0;
        Map<String, dynamic>? capturedToolOutput;
        ai.defineModel(
          name: 'main-session',
          fn: (req, ctx) async {
            mainTurn++;
            if (mainTurn == 1) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(
                        name: 'delegate_to_sessionCoder',
                        input: {'task': 'Write hello world.'},
                      ),
                    ),
                  ],
                ),
              );
            }
            capturedToolOutput = _firstToolOutput(req.messages);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Done.')],
              ),
            );
          },
        );

        await ai.generate(
          model: modelRef('main-session'),
          prompt: 'Write some code',
          use: [
            agents(agents: ['sessionCoder'], artifactStrategy: 'session'),
          ],
        );

        expect(capturedToolOutput, isNotNull);
        final artifacts = capturedToolOutput!['artifacts'] as List;
        expect(artifacts, isNotEmpty);
        final artifact = artifacts.first as Map<String, dynamic>;
        expect(artifact['name'] as String, contains('sessionCoder'));
        expect(artifact['name'] as String, contains('code.ts'));
        expect(
          artifact['content'],
          isNull,
          reason: 'Session strategy should not include content in tool result',
        );
      },
    );

    test('artifact names are namespaced with invocation ID pattern', () async {
      final subArtifact = Artifact(
        name: 'output.txt',
        parts: [TextPart(text: 'hello')],
      );
      ai.defineCustomAgent(
        name: 'nsAgent',
        store: InMemorySessionStore(),
        fn: (sess, options) async {
          sess.addArtifacts([subArtifact]);
          return AgentResult(
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'done')],
            ),
            artifacts: sess.getArtifacts(),
            finishReason: AgentFinishReason.stop,
          );
        },
      );

      var mainTurn = 0;
      Map<String, dynamic>? capturedToolOutput;
      ai.defineModel(
        name: 'main-ns',
        fn: (req, ctx) async {
          mainTurn++;
          if (mainTurn == 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_nsAgent',
                      input: {'task': 'produce output'},
                    ),
                  ),
                ],
              ),
            );
          }
          capturedToolOutput = _firstToolOutput(req.messages);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          );
        },
      );

      await ai.generate(
        model: modelRef('main-ns'),
        prompt: 'test namespace',
        use: [
          agents(agents: ['nsAgent']),
        ],
      );

      expect(capturedToolOutput, isNotNull);
      final artifacts = capturedToolOutput!['artifacts'] as List;
      expect(artifacts, isNotEmpty);
      final name = (artifacts.first as Map<String, dynamic>)['name'] as String;
      // Pattern: nsAgent_{4chars}/output.txt
      expect(
        RegExp(r'^nsAgent_[a-z0-9]{4}/output\.txt$').hasMatch(name),
        isTrue,
        reason:
            'Artifact name "$name" should match pattern nsAgent_XXXX/output.txt',
      );
    });

    test(
      'returns a tool response (does not propagate) when a sub-agent interrupts',
      () async {
        ai.defineCustomAgent(
          name: 'interrupter',
          store: InMemorySessionStore(),
          fn: (sess, options) async {
            return AgentResult(
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'needs approval')],
              ),
              finishReason: AgentFinishReason.interrupted,
            );
          },
        );

        var mainTurn = 0;
        Map<String, dynamic>? capturedToolOutput;
        ai.defineModel(
          name: 'main-interrupt',
          fn: (req, ctx) async {
            mainTurn++;
            if (mainTurn == 1) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(
                        name: 'delegate_to_interrupter',
                        input: {'task': 'do something requiring approval'},
                      ),
                    ),
                  ],
                ),
              );
            }
            capturedToolOutput = _firstToolOutput(req.messages);
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'acknowledged the interrupt')],
              ),
            );
          },
        );

        final result = await ai.generate(
          model: modelRef('main-interrupt'),
          prompt: 'delegate to an agent that interrupts',
          use: [
            agents(agents: ['interrupter']),
          ],
        );

        expect(
          result.finishReason,
          isNot(FinishReason.interrupted),
          reason:
              'Orchestrator should not be interrupted by a sub-agent interrupt',
        );
        expect(capturedToolOutput, isNotNull);
        expect(
          (capturedToolOutput!['response'] as String).toLowerCase(),
          contains('interrupt'),
        );
        expect(result.text, contains('acknowledged'));
      },
    );

    test('forwards recent history (text only) to sub-agents', () async {
      final capturedSubMessages = <Message>[];
      ai.defineCustomAgent(
        name: 'historyWorker',
        // No store => client-managed, so history seeding is allowed.
        fn: (sess, options) async {
          // Seeded history is available up-front; the delegated task arrives as
          // the turn input message.
          capturedSubMessages.addAll(sess.getMessages());
          await sess.run((input, ctx) async {
            if (input.message != null) capturedSubMessages.add(input.message!);
            return null;
          });
          return AgentResult(
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'sub done')],
            ),
            finishReason: AgentFinishReason.stop,
          );
        },
      );

      var mainTurn = 0;
      ai.defineModel(
        name: 'main-history',
        fn: (req, ctx) async {
          mainTurn++;
          if (mainTurn == 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_historyWorker',
                      input: {'task': 'do the main task'},
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
              content: [TextPart(text: 'final')],
            ),
          );
        },
      );

      await ai.generate(
        model: modelRef('main-history'),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'please search for X')],
          ),
          Message(
            role: Role.model,
            content: [
              ToolRequestPart(
                toolRequest: ToolRequest(name: 'search', ref: '1', input: {}),
              ),
            ],
          ),
          Message(
            role: Role.tool,
            content: [
              ToolResponsePart(
                toolResponse: ToolResponse(
                  name: 'search',
                  ref: '1',
                  output: {},
                ),
              ),
            ],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'I found the answer.')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'now do the work')],
          ),
        ],
        use: [
          agents(agents: ['historyWorker'], historyLength: 10),
        ],
      );

      expect(capturedSubMessages, isNotEmpty);

      // No forwarded part should be a tool/tool-request part.
      final hasToolParts = capturedSubMessages.any(
        (m) => m.content.any(
          (p) => p.toolRequestPart != null || p.toolResponsePart != null,
        ),
      );
      expect(
        hasToolParts,
        isFalse,
        reason: 'Forwarded history must not contain tool/tool-request parts',
      );

      final hasToolRole = capturedSubMessages.any((m) => m.role == Role.tool);
      expect(
        hasToolRole,
        isFalse,
        reason: 'Forwarded history must not contain tool messages',
      );

      final allText = capturedSubMessages
          .expand((m) => m.content)
          .map((p) => p.text ?? '')
          .join('\n');
      expect(allText, contains('please search for X'));
      expect(allText, contains('I found the answer.'));
      expect(allText, contains('do the main task'));
    });

    test('returns sub-agent failure as an error tool response', () async {
      ai.defineCustomAgent(
        name: 'failer',
        store: InMemorySessionStore(),
        fn: (sess, options) async {
          return AgentResult(finishReason: AgentFinishReason.failed);
        },
      );

      var mainTurn = 0;
      Map<String, dynamic>? capturedToolOutput;
      ai.defineModel(
        name: 'main-failing',
        fn: (req, ctx) async {
          mainTurn++;
          if (mainTurn == 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'delegate_to_failer',
                      input: {'task': 'do the impossible'},
                    ),
                  ),
                ],
              ),
            );
          }
          capturedToolOutput = _firstToolOutput(req.messages);
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'recovered from failure')],
            ),
          );
        },
      );

      final result = await ai.generate(
        model: modelRef('main-failing'),
        prompt: 'delegate to a failing agent',
        use: [
          agents(agents: ['failer']),
        ],
      );

      expect(capturedToolOutput, isNotNull);
      expect(
        capturedToolOutput!['response'] as String,
        contains("Error calling agent 'failer'"),
      );
      expect(result.text, contains('recovered'));
    });
  });
}
