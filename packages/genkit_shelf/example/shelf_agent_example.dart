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

import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_shelf/agents.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';

// This example serves Genkit agents over HTTP.
//
// To run it:
//   GEMINI_API_KEY=... dart run example/shelf_agent_example.dart
//
// Each agent gets a turn route plus `/getSnapshot` and `/abort`, which is the
// layout `remoteAgent` from `package:genkit/client.dart` expects:
//
//   final agent = remoteAgent(url: 'http://localhost:3400/assistant');
//   final res = await agent.chat().send(text: 'Hi!');
//
// Or with curl (one turn):
//   curl -X POST http://localhost:3400/assistant \
//     -H "Content-Type: application/json" \
//     -d '{"data": {"message": {"role": "user", "content": [{"text": "Hi!"}]}}}'

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  // Server-managed agent: conversation state lives in the session store, so
  // clients resume by sessionId/snapshotId and can read or abort snapshots.
  final assistant = ai.defineAgent(
    name: 'assistant',
    model: googleAI.gemini('gemini-flash-latest'),
    system: 'You are a concise, friendly assistant.',
    store: InMemorySessionStore(),
  );

  // Client-managed agent: the client round-trips the state itself, so there
  // are no snapshots to read or abort.
  final statelessAssistant = ai.defineAgent(
    name: 'statelessAssistant',
    model: googleAI.gemini('gemini-flash-latest'),
    system: 'You are a concise, friendly assistant.',
  );

  // Server-managed agent that only signed-in users may call. The context
  // provider guards the turn, getSnapshot and abort routes alike.
  final accountAgent = ai.defineCustomAgent(
    name: 'accountAgent',
    store: InMemorySessionStore(),
    fn: (session, options) async {
      await session.run((input, ctx) async => null);
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Hello, ${options.context?['user']}!')],
        ),
      );
    },
  );

  final genkit = GenkitRouter()
    ..addAgent(assistant)
    ..addAgent(statelessAssistant, hideGetSnapshot: true, hideAbort: true)
    ..addAgent(accountAgent, contextProvider: _bearerAuth);

  await genkit.serve(port: 3400, cors: const CorsOptions());
}

Map<String, dynamic> _bearerAuth(Request request) {
  // Replace with real token verification.
  if (request.headers['authorization'] != 'Bearer secret') {
    throw GenkitException('Unauthorized', status: StatusCodes.UNAUTHENTICATED);
  }
  return {'user': 'Admin'};
}
