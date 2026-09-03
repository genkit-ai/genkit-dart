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

/// Async sub-agent delegation demo — the `agents(async: true)` middleware.
///
/// The orchestrator delegates independent research tasks to a `researcher`
/// sub-agent in the *background*: each delegation returns a `taskId`
/// immediately, so the orchestrator can fan several out and then collect them
/// with `wait_for_background_tasks` instead of blocking on each in turn. Both
/// sub-agents are server-managed (they have a session store), which is what
/// makes background delegation and `continue_task` possible.
///
/// Run it (capturing a trace) with:
///
///   . ~/init-gemini.sh && \
///     genkit start -- dart run bin/async_agent_sample.dart
///
/// then inspect the trace:
///
///   genkit trace:list
///   genkit trace:get `<traceId>` --format=json
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/agents.dart';

final _model = googleAI.gemini('gemini-flash-lite-latest');

final Genkit ai = Genkit(plugins: [googleAI(), AgentsPlugin()], model: _model);

// Server-managed sub-agents (they have a store), so they can detach and run in
// the background, and their tasks leave continuable handles behind.
final researcher = ai.defineAgent(
  name: 'researcher',
  description:
      'Researches a single, focused topic and returns a concise summary.',
  system:
      'You are a focused research assistant. Given one topic, return a tight '
      '3-4 sentence summary of the most important facts. Do not ask follow-up '
      'questions.',
  store: InMemorySessionStore(),
  maxTurns: 4,
);

final writer = ai.defineAgent(
  name: 'writer',
  description: 'Writes a short, polished prose section from notes it is given.',
  system:
      'You are a crisp technical writer. Turn the notes you are given into a '
      'short, readable paragraph. Do not ask follow-up questions.',
  store: InMemorySessionStore(),
  maxTurns: 4,
);

final orchestrator = ai.defineAgent(
  name: 'asyncOrchestrator',
  system: '''
You are a research coordinator.

When the user asks about several topics, delegate each one to the "researcher"
sub-agent IN THE BACKGROUND (set "background": true) so they run in parallel,
keeping the taskId each delegation returns. Once every research task is
launched, call wait_for_background_tasks with all the taskIds to collect the
results. Then hand the combined notes to the "writer" sub-agent to produce a
final summary, and return that to the user.''',
  use: [
    agents(agents: ['researcher', 'writer'], async: true, maxDelegations: 8),
  ],
  store: InMemorySessionStore(),
);

/// Forces the sub-agent initializers to run so they register by name before the
/// orchestrator middleware looks them up. Dart initializes top-level `final`s
/// lazily, and the orchestrator references its sub-agents by name (not by
/// variable), so their initializers would otherwise never run.
List<Agent> registerSubAgents() => [researcher, writer];

Future<void> main() async {
  // Force the sub-agent initializers to run so they register by name before
  // the orchestrator middleware looks them up (reading each is enough).
  registerSubAgents();

  final chat = orchestrator.chat();
  final res = await chat.send(
    text:
        'Give me a brief on three topics in parallel: (1) how vector databases '
        'work, (2) what retrieval-augmented generation is, and (3) the tradeoffs '
        'of fine-tuning vs prompting. Then write a single cohesive summary.',
  );

  print('\n=== Orchestrator answer ===\n');
  print(res.text);

  await ai.shutdown();
}
