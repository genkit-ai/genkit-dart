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

/// Background agent — detached (background) execution.
///
/// Ported from the JS `background-agent.ts`. Key concepts:
///   * `detach: true` causes the server to start processing in the background
///     and return a snapshotId immediately.
///   * The client polls `getSnapshotData` to check status
///     (pending -> done/failed/aborted).
///   * The client can call `abort` to cancel background work.
///   * A persistent store is REQUIRED for detach to work.
///
/// Continue-after-abort: the agent researches the report one section at a time
/// via the `research_section` tool. Each completed tool round is threaded into
/// the turn's message history, so when the client aborts mid-loop the runtime
/// records those finished sections in the `aborted` snapshot (its intermediate
/// last-good state). The client can then resume from that snapshot
/// (`chat(snapshotId: ...).detach(...)`) and the agent picks up where it left
/// off instead of restarting from scratch.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'background_agent.g.dart';

@Schema()
abstract class $ResearchSectionInput {
  @Field(
    description:
        'The section of the report to research (e.g. "Executive Summary").',
  )
  String get section;
}

/// A deliberately slow, cancellation-aware research tool.
///
/// The delay makes a multi-section report take long enough to abort mid-loop;
/// racing the wait against [ToolFnArgs.cancel] lets a detached abort interrupt
/// the in-flight section promptly (rather than blocking until the timer fires),
/// so the turn settles quickly with the already-finished sections preserved.
final researchSection = ai.defineTool(
  name: 'research_section',
  description:
      'Research ONE section of the report and return its findings. Call this '
      'once per section, sequentially, before writing the final report.',
  inputSchema: ResearchSectionInput.$schema,
  outputSchema: .string(),
  fn: (input, ctx) async {
    final cancel = ctx.cancel;
    final work = Future<void>.delayed(const Duration(seconds: 4));
    if (cancel != null) {
      await Future.any([
        work,
        cancel.whenCancelled.then(
          (_) => throw CancelledException(reason: cancel.reason),
        ),
      ]);
    } else {
      await work;
    }
    return .response(
      'Findings for "${input.section}":\n'
      '- Simulated key data points, trends, and representative examples.\n'
      '- Notable context and one counterpoint worth addressing.',
    );
  },
);

final backgroundAgent = ai.defineAgent(
  name: 'backgroundAgent',
  system: '''
You are a senior research analyst. When given a topic, produce a comprehensive research report in markdown format.

Work in two phases:
1. Research each section BELOW by calling the research_section tool exactly once per section, one at a time (wait for each result before the next). Do not skip this step.
2. Only after every section has been researched, write the final report in markdown, weaving in the findings from each tool result.

Your report must include these sections (research each one):
- **Executive Summary** — A concise overview of the topic and key findings.
- **Background & Context** — Historical context and current landscape.
- **Analysis** — Detailed analysis with data points and examples.
- **Implications** — What this means going forward.
- **Conclusion & Recommendations** — Actionable takeaways.

Be thorough, analytical, and evidence-based. Use markdown headings, bullet points, and bold text for structure.''',
  use: [retry()],
  tools: [researchSection],
  // Each research_section round is a model turn; the report needs one per
  // section plus the final write-up, so raise the default cap of 5.
  maxTurns: 12,
  store: InMemorySessionStore(),
);
