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

/// Shelf server exposing the A2UI-enabled agent over HTTP.
///
/// The agent is mounted at `/api/uiAgent` (the turn action), plus
/// `/api/uiAgent/getSnapshot` and `/api/uiAgent/abort`. The Flutter client
/// (`lib/main.dart`) talks to it with `remoteAgent` from
/// `package:genkit/client.dart`.
///
/// Run with: `GEMINI_API_KEY=... dart run bin/server.dart`
library;

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:a2ui_sample/agent.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final router = Router();

  router.get('/', (Request request) {
    return Response.ok(
      'Genkit Dart A2UI sample API server.\n\n'
      'The uiAgent is mounted under /api/uiAgent.\n'
      'Run the Flutter client with: flutter run -d chrome\n',
      headers: {'Content-Type': 'text/plain'},
    );
  });

  // Server-managed agent (turn + snapshot + abort).
  router.post('/api/uiAgent', shelfHandler(uiAgent.action));
  router.post(
    '/api/uiAgent/getSnapshot',
    shelfHandler(uiAgent.getSnapshotDataAction),
  );
  router.post('/api/uiAgent/abort', shelfHandler(uiAgent.abortAgentAction));

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
  print('\n🚀 A2UI sample API server on http://localhost:${server.port}');
  print('   uiAgent mounted at /api/uiAgent');
  print('   Run the Flutter client: flutter run -d chrome\n');
}
