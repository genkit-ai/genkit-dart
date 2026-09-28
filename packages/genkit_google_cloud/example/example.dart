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

/// Persists a server-managed agent's sessions in Cloud Firestore.
///
/// Uses Application Default Credentials; set `GOOGLE_CLOUD_PROJECT`, or point
/// `FIRESTORE_EMULATOR_HOST` at a local emulator:
///
/// ```sh
/// GOOGLE_CLOUD_PROJECT=my-project dart run example/example.dart
/// ```
///
/// Sessions and agents are experimental Genkit APIs
/// (`package:genkit/experimental.dart`), and so is this store.
library;

import 'package:genkit/experimental.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_cloud/firestore_session_store.dart';

Future<void> main() async {
  final ai = Genkit();

  // A trivial model so the example runs without an API key; use a real model
  // plugin (e.g. `genkit_google_genai`) in practice.
  ai.defineModel(
    name: 'echo',
    fn: (request, ctx) async => ModelResponse(
      finishReason: .stop,
      message: Message(
        role: .model,
        content: [TextPart(text: 'You said: ${request.messages.last.text}')],
      ),
    ),
  );

  final agent = ai.defineAgent(
    name: 'assistant',
    model: modelRef('echo'),
    // Snapshots of every turn are written to `genkit-sessions/...`, so a
    // conversation can resume on another server instance or after a restart.
    store: FirestoreSessionStore(collection: 'genkit-sessions'),
  );

  final chat = agent.chat();
  final first = await chat.send(text: 'Hello!');
  print('${first.text} (session ${first.sessionId})');

  // Later, possibly in another process: resume from the same session.
  final resumed = agent.chat(sessionId: first.sessionId);
  final second = await resumed.send(text: 'Still there?');
  print(second.text);
}
