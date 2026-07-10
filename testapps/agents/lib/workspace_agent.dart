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

/// Workspace builder — artifact production.
///
/// Ported from the JS `workspace-agent.ts`. The JS sample uses the
/// `artifacts()` middleware to auto-inject `write_artifact` / `read_artifact`
/// tools. The Dart middleware suite does not yet include that middleware, so
/// this sample defines the two tools directly on top of the session artifact
/// API (`ai.currentSession().addArtifacts()` / `getArtifacts()`).
///
/// Adding an artifact to the session emits an `artifactAdded` /
/// `artifactUpdated` event, which the agent runtime forwards to the client as
/// an `artifact` stream chunk. Artifacts are deduplicated by name.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'workspace_agent.g.dart';

@Schema()
abstract class $WriteArtifactInput {
  @Field(description: 'The name (e.g. filename) of the artifact.')
  String get name;
  @Field(description: 'The full content of the artifact.')
  String get content;
}

@Schema()
abstract class $ReadArtifactInput {
  @Field(description: 'The name of the artifact to read.')
  String get name;
}

final writeArtifact = ai.defineTool(
  name: 'write_artifact',
  description:
      'Create or overwrite a named artifact (e.g. a file). Pass the filename '
      'as "name" and the full content as "content".',
  inputSchema: WriteArtifactInput.$schema,
  outputSchema: .string(),
  fn: (input, _) async {
    final session = ai.currentSession()!;
    session.addArtifacts([
      Artifact(
        name: input.name,
        parts: [TextPart(text: input.content)],
      ),
    ]);
    return 'Wrote artifact "${input.name}".';
  },
);

final readArtifact = ai.defineTool(
  name: 'read_artifact',
  description: 'Read the content of a previously created artifact by name.',
  inputSchema: ReadArtifactInput.$schema,
  outputSchema: .string(),
  fn: (input, _) async {
    final session = ai.currentSession()!;
    final artifact = session.getArtifacts().where((a) => a.name == input.name);
    if (artifact.isEmpty) {
      return 'Artifact "${input.name}" not found.';
    }
    return artifact.first.parts.map((p) => p.text ?? '').join();
  },
);

final workspaceAgent = ai.defineAgent(
  name: 'workspaceAgent',
  system: '''
You are a helpful code generation assistant. When the user asks you to create a file, use the write_artifact tool to produce it.

Rules:
- Use the write_artifact tool to create files. Pass the filename as "name" and the full file content as "content".
- You can create multiple files in a single turn if requested.
- After writing artifacts, briefly confirm what you created.
- If the user asks you to modify a previously created file, use read_artifact to view the current content, then write_artifact with the same name and updated content.
- You can use read_artifact to review any previously created files.''',
  use: [retry()],
  tools: [writeArtifact, readArtifact],
  store: InMemorySessionStore(),
);
