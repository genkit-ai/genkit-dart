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
import 'package:genkit/experimental_io.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';

// This example serves Genkit agents over HTTP (dart:io, no extra packages).
//
// To run it:
//   dart run example/http_agent_example.dart
//
// It uses a tiny local echo model so it runs without an API key; swap in any
// real model (e.g. `googleAI.gemini('gemini-flash-latest')` from
// `package:genkit_google_genai`).
//
// Each agent gets a turn route, plus `/getSnapshot` and `/abort` when it has a
// session store. That's the layout `remoteAgent` from
// `package:genkit/client.dart` expects:
//
//   final agent = remoteAgent(url: 'http://localhost:3400/assistant');
//   final res = await agent.chat().send(text: 'Hi!');
//
// Or with curl (one turn):
//   curl -X POST http://localhost:3400/assistant \
//     -H "Content-Type: application/json" \
//     -d '{"data": {"message": {"role": "user", "content": [{"text": "Hi!"}]}}}'

void main() async {
  final ai = Genkit();
  final model = ai.defineModel(
    name: 'echo',
    fn: (request, _) async => ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: 'You said: ${request.messages.last.text}')],
      ),
    ),
  );

  // Server-managed agent: conversation state lives in the session store, so
  // clients resume by sessionId/snapshotId and can read or abort snapshots.
  final assistant = ai.defineAgent(
    name: 'assistant',
    model: modelRef(model.name),
    system: 'You are a concise, friendly assistant.',
    store: InMemorySessionStore(),
  );

  // Client-managed agent: the client round-trips the state itself, so there
  // are no snapshots to read or abort. addAgent detects this and mounts only
  // the turn route.
  final statelessAssistant = ai.defineAgent(
    name: 'statelessAssistant',
    model: modelRef(model.name),
    system: 'You are a concise, friendly assistant.',
  );

  // Server-managed agent that only signed-in users may call. The context
  // provider guards the turn and getSnapshot routes alike; abort is hidden
  // because this agent's turns are short and never detached.
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
    ..addAgent(assistant) // turn + getSnapshot + abort
    ..addAgent(statelessAssistant) // turn only
    ..addAgent(accountAgent, contextProvider: _bearerAuth, hideAbort: true);

  await genkit.serve(port: 3400, cors: const CorsOptions());
}

Map<String, dynamic> _bearerAuth(RequestData request) {
  // Replace with real token verification.
  if (request.headers['authorization'] != 'Bearer secret') {
    throw GenkitException('Unauthorized', status: StatusCode.unauthenticated);
  }
  return {'user': 'Admin'};
}
