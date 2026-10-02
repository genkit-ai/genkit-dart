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

/// Server exposing the A2UI-enabled agent over HTTP, using only `dart:io`
/// (`package:genkit/io.dart`), no web framework.
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
import 'package:genkit/experimental_io.dart';
import 'package:genkit/io.dart';

void main() async {
  // Register the app's custom A2UI catalog before serving any turns, so the
  // agent's `a2ui(catalog: weatherCatalogId)` can resolve it from the registry.
  await registerCatalogs();

  // Server-managed agent (turn + snapshot + abort).
  final genkit = GenkitRouter()..addAgent(uiAgent, path: '/api/uiAgent');

  final server = await genkit.serve(
    // $PORT, else 8080 (what the Flutter client expects).
    port: int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080,
    // The Flutter web client runs on another origin.
    cors: const CorsOptions(
      allowedHeaders: ['Content-Type', 'Accept', 'X-Genkit-Stream-Id'],
    ),
  );
  print('\nA2UI sample API server on http://localhost:${server.port}');
  print('   uiAgent mounted at /api/uiAgent');
  print('   Run the Flutter client: flutter run -d chrome\n');
}
