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

/// Sub-agent delegation demo — demonstrates the `agents` middleware.
///
/// Ported from the JS `orchestrator-agent.ts`. The `agents()` middleware
/// auto-injects one delegation tool per sub-agent (e.g.
/// `delegate_to_researcher`, `delegate_to_coder`) and appends a `<sub-agents>`
/// block to the orchestrator's system prompt listing the available agents and
/// their descriptions. When the orchestrator model calls a delegation tool the
/// middleware resolves the target agent from the registry, runs it, and returns
/// its response as the tool result.
///
/// Key features demonstrated:
///   * Per-agent delegation tools (one tool per agent).
///   * Auto-discovered agent descriptions from registry metadata.
///   * `maxDelegations` guard rail to prevent runaway loops.
///   * `historyLength` to forward conversation context to sub-agents.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/agents.dart';

import 'genkit.dart';

// ---------------------------------------------------------------------------
// Sub-agents. Both declare a `description`, which the `agents` middleware
// auto-discovers and surfaces in the orchestrator's system prompt.
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
  description:
      'Writes, debugs, and explains code. Use for any programming tasks.',
  maxTurns: 10,
  system:
      'You are an expert programmer. When asked to write code, provide clean, '
      'well-commented code with explanations. Use Dart by default unless asked '
      'otherwise.',
);

// ---------------------------------------------------------------------------
// Orchestrator. The `agents()` middleware injects the delegation tools and the
// `<sub-agents>` prompt block, so the system prompt only needs high-level
// guidance on how to coordinate.
// ---------------------------------------------------------------------------

final orchestratorAgent = ai.defineAgent(
  name: 'orchestratorAgent',
  system: '''
You are a helpful project assistant.

Analyze the user's request and delegate to the appropriate sub-agent.
If the request requires both research AND code, call them sequentially.
After receiving sub-agent responses, synthesize a final answer for the user.''',
  use: [
    agents(
      agents: ['researcher', 'coder'],
      maxDelegations: 5,
      historyLength: 4,
    ),
  ],
  store: InMemorySessionStore(),
);
