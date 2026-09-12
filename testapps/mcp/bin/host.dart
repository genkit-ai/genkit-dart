// Copyright 2025 Google LLC
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

import 'dart:async';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_mcp/genkit_mcp.dart';

/// A Genkit MCP host that connects to the stdio server in `bin/server.dart`.
///
/// `defineMcpHost` registers a [DynamicActionProvider] named `myServers`, so the
/// remote server's tools, prompts, and resources become resolvable through the
/// registry as `myServers:<name>` (e.g. `myServers:weather`). The Dev UI expands
/// the provider and lists each remote action individually.
///
/// Run it under the Dev UI (from the `testapps/mcp` directory so the relative
/// spawn command below resolves):
/// ```sh
/// export GEMINI_API_KEY=...   # or GOOGLE_API_KEY
/// genkit start -- dart run bin/host.dart
/// ```
/// Then in the Dev UI you can:
///  - see the `weather` / `greet` / `add` tools, the `echoPrompt`, and the
///    resources listed under the `myServers` host;
///  - run any of them directly; and
///  - run the `askWithMcpTools` flow, which lets Gemini call the MCP tools.
void main(List<String> args) async {
  final ai = Genkit(plugins: [googleAI(), RetryPlugin()]);

  final host = defineMcpHost(
    ai,
    McpHostOptionsWithCache(
      name: 'myServers',
      mcpServers: {
        // Spawns `dart run bin/server.dart` and talks to it over stdio. The
        // command is relative, so launch the host from `testapps/mcp`.
        'localServer': McpServerConfig(
          command: 'dart',
          args: ['run', 'bin/server.dart'],
        ),
      },
    ),
  );
  await host.ready();

  final askWithMcpTools = ai.defineFlow(
    name: 'askWithMcpTools',
    inputSchema: .string(),
    outputSchema: .string(),
    fn: (String question, context) async {
      final response = await ai.generate(
        model: googleAI.gemini('gemini-3.6-flash'),
        prompt: question,
        // `myServers:*` expands to every tool the host exposes.
        toolNames: ['myServers:*'],
        use: [retry()],
      );
      if (response.finishReason == .stop) {
        return response.text;
      }
      return 'generate did not complete successfully';
    },
  );

  // Allow a quick headless run: `dart run bin/host.dart "what's the weather in Tokyo?"`.
  if (args.isNotEmpty) {
    final result = await askWithMcpTools(args.join(' '));
    stdout.writeln(result);
    await host.close();
    return;
  }

  stdout.writeln(
    'Run under the Dev UI: genkit start -- dart run bin/host.dart',
  );
  stdout.writeln('Listening... (Press Ctrl+C to exit)');

  // Keep the process alive for the Dev UI reflection server, then shut down
  // cleanly. `genkit start` terminates the runtime with SIGTERM (not SIGINT),
  // so watch both: without handling SIGTERM the host never runs `host.close()`,
  // leaving the spawned server subprocess and the reflection server running.
  final done = Completer<void>();
  void stop() {
    if (!done.isCompleted) done.complete();
  }

  ProcessSignal.sigint.watch().listen((_) => stop());
  try {
    ProcessSignal.sigterm.watch().listen((_) => stop());
  } on SignalException {
    // SIGTERM cannot be watched on Windows; SIGINT still covers Ctrl+C there.
  }

  await done.future;
  await host.close(); // kills the spawned server subprocess
  await ai.shutdown(); // stops the reflection server
  exit(0);
}
