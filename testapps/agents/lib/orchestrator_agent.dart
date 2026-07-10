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

/// Sub-agent delegation demo.
///
/// Ported from the JS `orchestrator-agent.ts`. The JS sample uses the
/// `agents()` middleware to auto-inject one delegation tool per sub-agent. The
/// Dart middleware suite does not yet include that middleware, so this sample
/// wires delegation explicitly: the orchestrator is given two tools
/// (`delegate_to_researcher`, `delegate_to_coder`) that run the corresponding
/// sub-agent (via its in-process chat API) and return the sub-agent's text
/// response as the tool result.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'orchestrator_agent.g.dart';

@Schema()
abstract class $DelegateInput {
  @Field(description: 'The task or question to hand to the sub-agent.')
  String get task;
}

// ---------------------------------------------------------------------------
// Sub-agents.
// ---------------------------------------------------------------------------

final researcher = ai.defineAgent(
  name: 'researcher',
  description:
      'A thorough research assistant that provides well-sourced answers.',
  system:
      'You are a thorough research assistant. When asked a question, provide a '
      'clear, well-structured, and well-sourced answer.',
  maxTurns: 10,
);

final coder = ai.defineAgent(
  name: 'coder',
  description: 'An expert programmer that writes clean, well-commented code.',
  maxTurns: 10,
  system:
      'You are an expert programmer. When asked to write code, provide clean, '
      'well-commented code with explanations. Use Dart by default unless asked '
      'otherwise.',
);

// ---------------------------------------------------------------------------
// Delegation tools.
// ---------------------------------------------------------------------------

final delegateToResearcher = ai.defineTool(
  name: 'delegate_to_researcher',
  description:
      'Delegate a research task to the researcher sub-agent. Returns the '
      "sub-agent's findings.",
  inputSchema: DelegateInput.$schema,
  outputSchema: .string(),
  fn: (input, _) async {
    final res = await researcher.chat().send(agentInputFromText(input.task));
    return res.text;
  },
);

final delegateToCoder = ai.defineTool(
  name: 'delegate_to_coder',
  description:
      'Delegate a coding task to the coder sub-agent. Writes, debugs, and '
      'explains code. Use for any programming tasks.',
  inputSchema: DelegateInput.$schema,
  outputSchema: .string(),
  fn: (input, _) async {
    final res = await coder.chat().send(agentInputFromText(input.task));
    return res.text;
  },
);

// ---------------------------------------------------------------------------
// Orchestrator.
// ---------------------------------------------------------------------------

final orchestratorAgent = ai.defineAgent(
  name: 'orchestratorAgent',
  system: '''
You are a helpful project assistant.

Analyze the user's request and delegate to the appropriate sub-agent using the delegation tools:
- Use delegate_to_researcher for research questions.
- Use delegate_to_coder for programming tasks.

If the request requires both research AND code, call them sequentially.
After receiving sub-agent responses, synthesize a final answer for the user.''',
  tools: [delegateToResearcher, delegateToCoder],
  store: InMemorySessionStore(),
);
