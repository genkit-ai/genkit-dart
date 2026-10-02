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

/// Shelf server exposing the agents over HTTP for the Jaspr web UI.
///
/// Ported from the JS `src/index.ts` Express server. Each agent is mounted at
/// `/api/<agentName>` (the turn action), plus `/api/<agentName>/getSnapshot` and
/// `/api/<agentName>/abort` for the snapshot and abort actions where relevant.
/// The wire body matches the Genkit client: `{ "data": <input>, "init": <init> }`.
library;

import 'dart:io';

import 'package:agents_sample/background_agent.dart';
import 'package:agents_sample/banking_agent.dart';
import 'package:agents_sample/branching_agent.dart';
import 'package:agents_sample/coding_agent.dart';
import 'package:agents_sample/orchestrator_agent.dart';
import 'package:agents_sample/research_agent.dart';
import 'package:agents_sample/task_agent.dart';
import 'package:agents_sample/trip_planner_agent.dart';
import 'package:agents_sample/weather_agent.dart';
import 'package:agents_sample/weather_agent_stateless.dart';
import 'package:agents_sample/workspace_agent.dart';
import 'package:agents_sample/workspace_browser.dart';
import 'package:genkit/experimental_io.dart';
import 'package:genkit/io.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  // The orchestrator references its sub-agents ('researcher', 'coder') by name,
  // and Dart initializes their top-level `final`s lazily, so force their
  // `defineAgent(...)` registration before any delegation happens.
  registerSubAgents();

  final api = GenkitRouter()
    // Workspace browser flows used by the coding-agent page.
    ..addAction(listWorkspaceFiles, path: '/workspace/files')
    ..addAction(readWorkspaceFile, path: '/workspace/file');

  // Server-managed agents get turn + getSnapshot + abort; the client-managed
  // weatherAgentStateless gets only its turn route.
  for (final agent in [
    weatherAgent,
    weatherAgentStateless,
    bankingAgent,
    backgroundAgent,
    branchingAgent,
    taskAgent,
    tripPlannerAgent,
    codingAgent,
    orchestratorAgent,
    workspaceAgent,
    researchAgent,
  ]) {
    api.addAgent(agent);
  }

  final router = Router()
    // Friendly root route. This server only exposes the agents API under
    // `/api/...`; the web UI is a separate Jaspr app served on its own port.
    ..get('/', (Request request) {
      return Response.ok(
        'Genkit Dart agents API server.\n\n'
        'This is the API server (agents are mounted under /api/...).\n'
        'It does NOT serve the web UI.\n\n'
        'To use the web UI:\n'
        '  cd web && jaspr serve --port 5173\n'
        'then open http://localhost:5173\n',
        headers: {'Content-Type': 'text/plain'},
      );
    })
    // `mount` strips the prefix, so agents are served at `/api/<agentName>`.
    // The web UI runs on another port, so the API needs CORS (any origin by
    // default, and the trace id headers are readable by browser code).
    ..mount(
      '/api/',
      api.asShelfHandler(
        cors: const CorsOptions(
          allowedHeaders: ['Content-Type', 'Accept', 'X-Genkit-Stream-Id'],
        ),
      ),
    );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('\nAgents API server running on http://localhost:${server.port}');
  print('   (This serves the agents API under /api/..., NOT the web UI.)');
  print(
    '   Web UI: in another terminal run '
    '"cd web && jaspr serve --port 5173"\n'
    '           then open http://localhost:5173\n',
  );
}
