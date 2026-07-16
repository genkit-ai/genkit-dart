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

/// Reusable "How It Works" educational side panels.
///
/// Ported from the `info-sidebar` asides in the JS pages. Each page exposes a
/// small builder that returns an `<aside class="info-sidebar">` component with a
/// "How It Works" list, "Key APIs" code block, and any extra notes.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Renders inline text that may contain `<code>` spans. Each entry is either a
/// plain [String] (rendered as text) or a [Component] (e.g. `code(...)` or
/// `strong(...)`).
List<Component> _inline(List<Object> parts) => [
  for (final part in parts)
    if (part is Component) part else Component.text(part.toString()),
];

/// A single `<li>` built from mixed text/code [parts].
Component _li(List<Object> parts) => li(_inline(parts));

/// A `<p>` built from mixed text/code [parts].
Component _p(List<Object> parts) => p(_inline(parts));

/// The canonical info sidebar shell: an `<aside class="info-sidebar">`.
Component infoSidebar(List<Component> children) =>
    aside(classes: 'info-sidebar', children);

/// A monospace "Key APIs" code block.
Component keyApisBlock(String code) => pre([Component.text(code)]);

// ---------------------------------------------------------------------------
// Weather
// ---------------------------------------------------------------------------

Component weatherSidebar() => infoSidebar([
  h3([.text('📋 How It Works')]),
  ol([
    _li([
      'Client sends user message via ',
      code([.text('chat.sendStream()')]),
      " — responses arrive as they're generated.",
    ]),
    _li([
      'The model can invoke ',
      strong([.text('tools')]),
      ' (e.g. ',
      code([.text('getWeather')]),
      '). Tool calls and responses render inline in the chat.',
    ]),
    _li([
      'The ',
      code([.text('remoteAgent')]),
      ' client tracks the session across turns automatically — no manual '
          'state threading.',
    ]),
  ]),
  h4([.text('Key APIs')]),
  keyApisBlock('''
// Streaming multi-turn
final agent = remoteAgent(url: '/api/weatherAgent');
final chat = agent.chat();

final turn = chat.sendStream(text: 'Weather in Tokyo?');
await for (final chunk in turn.stream) {
  // chunk.text → streamed text
  // chunk.raw.modelChunk.content → tool req/resp
}
final res = await turn.response;'''),
]);

// ---------------------------------------------------------------------------
// Banking (interrupt)
// ---------------------------------------------------------------------------

Component bankingSidebar() => infoSidebar([
  h3([.text('📋 How It Works')]),
  ol([
    _li([
      'User sends a request like ',
      em([.text('"Transfer \$500 to savings"')]),
      ' via ',
      code([.text('chat.sendStream()')]),
      '.',
    ]),
    _li([
      'The model decides to call the ',
      code([.text('userApproval')]),
      ' tool. Instead of a final answer, the response carries an entry in ',
      code([.text('response.interrupts')]),
      ' with the action details.',
    ]),
    _li([
      'The client detects the interrupt and shows an inline approval dialog — '
          'the flow is ',
      strong([.text('paused')]),
      '.',
    ]),
    _li([
      'When the user approves or denies, the client calls ',
      code([.text('chat.resumeStream(interrupt.respond(output))')]),
      ' to ',
      strong([.text('resume')]),
      ' from the exact point where the flow paused.',
    ]),
    _li([
      'The model processes the approval result and returns a final '
          'confirmation or denial message.',
    ]),
  ]),
  h4([.text('Interrupt Pattern')]),
  _p([
    'The interrupt pattern uses ',
    strong([.text('tool calls as control flow')]),
    '. The ',
    code([.text('userApproval')]),
    ' tool never executes server-side — it exists solely to pause the flow and '
        "hand control back to the client. The client's ",
    code([.text('resume')]),
    ' payload resumes execution.',
  ]),
]);

// ---------------------------------------------------------------------------
// Sub-agent delegation
// ---------------------------------------------------------------------------

Component subAgentSidebar() => infoSidebar([
  h3([.text('🤝 How It Works')]),
  ol([
    _li([
      'The ',
      strong([.text('orchestrator')]),
      ' agent has two sub-agents wired via the ',
      code([.text('agents')]),
      ' middleware: ',
      strong([.text('researcher')]),
      ' and ',
      strong([.text('coder')]),
      '.',
    ]),
    _li([
      'The middleware injects a ',
      code([.text('call_agent')]),
      ' tool that the orchestrator model can invoke to delegate tasks.',
    ]),
    _li([
      'When the model calls ',
      code([.text('call_agent')]),
      ', the middleware intercepts it, runs the sub-agent via its ',
      code([.text('.run()')]),
      " method, and returns the sub-agent's response as the tool result.",
    ]),
    _li([
      'The orchestrator synthesizes sub-agent responses into a final answer '
          'for the user.',
    ]),
  ]),
  h4([.text('Architecture')]),
  _p([
    'The ',
    code([.text('agents')]),
    ' middleware resolves sub-agents from the registry, calls their ',
    code([.text('.run()')]),
    ' method with the delegated task, and extracts the text response. '
        'Interrupts from sub-agents propagate up automatically.',
  ]),
]);

// ---------------------------------------------------------------------------
// Trip planner (prompt file)
// ---------------------------------------------------------------------------

Component tripPlannerSidebar() => infoSidebar([
  h3([.text('📋 How It Works')]),
  _p([
    'This agent demonstrates ',
    code([.text('definePromptAgent')]),
    ' — the prompt template lives in a ',
    strong([.text('.prompt file')]),
    ' (',
    code([.text('prompts/tripPlanner.prompt')]),
    ') rather than being defined inline in code.',
  ]),
  h4([.text('Prompt File')]),
  keyApisBlock('''
---
model: googleai/gemini-flash-latest
tools:
  - getAttractions
  - getFlightInfo
---

{{role "system"}}
You are a friendly trip planning
assistant...

{{history}}'''),
  h4([.text('Why use definePromptAgent?')]),
  ul([
    _li([
      strong([.text('Separation of concerns')]),
      ' — prompt authors can edit ',
      code([.text('.prompt')]),
      ' files without touching code',
    ]),
    _li([
      strong([.text('Reuse')]),
      ' — the same prompt can power multiple agents with different stores or '
          'configurations',
    ]),
    _li([
      strong([.text('Dotprompt features')]),
      ' — use Handlebars templates, ',
      code([.text('{{history}}')]),
      ', roles, helpers, and partials',
    ]),
  ]),
]);

// ---------------------------------------------------------------------------
// Background agent (detached execution)
// ---------------------------------------------------------------------------

Component backgroundSidebar() => infoSidebar([
  h3([.text('📋 How It Works')]),
  ol([
    _li([
      'Client sends ',
      code([.text('detach: true')]),
      ' with the input message.',
    ]),
    _li([
      'Server saves a snapshot with status ',
      code([.text('"pending"')]),
      ' and returns the ',
      code([.text('snapshotId')]),
      ' immediately.',
    ]),
    _li(['The LLM request continues running in the background on the server.']),
    _li([
      'Client polls the ',
      code([.text('/state')]),
      ' endpoint with the snapshotId every couple of seconds.',
    ]),
    _li([
      'When ',
      code([.text('status')]),
      ' becomes terminal, the report is extracted from the '
          "snapshot's message history.",
    ]),
  ]),
  h4([.text('Status Values')]),
  ul(classes: 'background-status-list', [
    _li([
      code([.text('pending')]),
      ' — still processing',
    ]),
    _li([
      code([.text('completed')]),
      ' — completed successfully',
    ]),
    _li([
      code([.text('failed')]),
      ' — error during processing',
    ]),
    _li([
      code([.text('aborted')]),
      ' — cancelled by the client',
    ]),
    _li([
      code([.text('expired')]),
      ' — the background worker stopped heartbeating',
    ]),
  ]),

  h4([.text('Key APIs')]),
  keyApisBlock('''
// Submit a detached (background) turn
final agent = remoteAgent(
  url: '/api/backgroundAgent',
);
final task = await agent.chat().detach(text: topic);
// task.snapshotId available now

// Poll until a terminal status
await for (final snap in task.poll(
  interval: Duration(seconds: 2),
)) {
  // snap.status, snap.messages
}

// Abort
await task.abort();'''),
]);
