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
/// `/api/<agentName>` (the turn action), plus `/api/<agentName>/state` and
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
import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

/// Mounts an agent's turn action plus its `/state` and `/abort` actions.
void _mountAgent(Router router, String path, Agent agent) {
  router.post('/api/$path', shelfHandler(agent.action));
  router.post('/api/$path/state', shelfHandler(agent.getSnapshotDataAction));
  router.post('/api/$path/abort', shelfHandler(agent.abortAgentAction));
}

void main() async {
  final router = Router();

  // Friendly root route. This server only exposes the agents API under
  // `/api/...`; the web UI is a separate Jaspr app served on its own port.
  router.get('/', (Request request) {
    return Response.ok(
      'Genkit Dart agents API server.\n\n'
      'This is the API server (agents are mounted under /api/...).\n'
      'It does NOT serve the web UI.\n\n'
      'To use the web UI:\n'
      '  cd web && jaspr serve --port 5173\n'
      'then open http://localhost:5173\n',
      headers: {'Content-Type': 'text/plain'},
    );
  });

  // Server-managed agents (turn + state + abort).
  _mountAgent(router, 'weatherAgent', weatherAgent);

  _mountAgent(router, 'bankingAgent', bankingAgent);
  _mountAgent(router, 'backgroundAgent', backgroundAgent);
  _mountAgent(router, 'branchingAgent', branchingAgent);
  _mountAgent(router, 'taskAgent', taskAgent);
  _mountAgent(router, 'tripPlannerAgent', tripPlannerAgent);
  _mountAgent(router, 'codingAgent', codingAgent);
  _mountAgent(router, 'orchestratorAgent', orchestratorAgent);
  _mountAgent(router, 'workspaceAgent', workspaceAgent);
  _mountAgent(router, 'researchAgent', researchAgent);

  // Client-managed (stateless) agent — only the turn action is meaningful.
  router.post(
    '/api/weatherAgentStateless',
    shelfHandler(weatherAgentStateless.action),
  );

  // Workspace browser flows used by the coding-agent page.
  router.post('/api/workspace/files', shelfHandler(listWorkspaceFiles));
  router.post('/api/workspace/file', shelfHandler(readWorkspaceFile));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers':
                'Content-Type, Accept, X-Genkit-Stream-Id',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          },
        ),
      )
      .addHandler(router.call);

  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('\n🚀 Agents API server running on http://localhost:${server.port}');
  print('   (This serves the agents API under /api/... — NOT the web UI.)');
  print(
    '   Web UI: in another terminal run '
    '"cd web && jaspr serve --port 5173"\n'
    '           then open http://localhost:5173\n',
  );
}
