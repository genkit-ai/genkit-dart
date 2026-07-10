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
library;

import 'package:genkit/genkit.dart';

import 'genkit.dart';

final backgroundAgent = ai.defineAgent(
  name: 'backgroundAgent',
  system: '''
You are a senior research analyst. When given a topic, produce a comprehensive research report in markdown format.

Your report must include:
- **Executive Summary** — A concise overview of the topic and key findings.
- **Background & Context** — Historical context and current landscape.
- **Analysis** — Detailed analysis with data points and examples (3–4 subsections).
- **Implications** — What this means going forward.
- **Conclusion & Recommendations** — Actionable takeaways.

Be thorough, analytical, and evidence-based. Use markdown headings, bullet points, and bold text for structure.''',
  use: [retry()],
  store: InMemorySessionStore(),
);
