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

/// Passing custom context to an in-process agent.
///
/// When you drive an agent in-process (via `agent.chat()`), you can pass an
/// ambient request context to each turn. The agent handler observes it through
/// `AgentFnOptions.context`. This mirrors the context a server would derive
/// from an incoming HTTP request (auth, headers, etc.), but here you supply it
/// directly - handy for CLIs, tests, and background jobs.
///
/// Note: the custom context is only honored by the *in-process* transport. A
/// `remoteAgent(...)` over HTTP ignores it, because a remote agent derives its
/// context server-side from the request.
///
/// Run with: `dart run bin/context_example.dart`
library;

import 'package:genkit/genkit.dart';

void main() async {
  final ai = Genkit(promptDir: null);

  // A custom agent that greets the caller by name, reading the name from the
  // ambient request context rather than from the message.
  final agent = ai.defineCustomAgent(
    name: 'greeter',
    fn: (sess, options) async {
      final auth = (options.context?['auth'] as Map?)?.cast<String, dynamic>();
      final user = (auth?['name'] as String?) ?? 'stranger';
      await sess.run((input, ctx) async {
        sess.addMessages([
          Message(
            role: Role.model,
            content: [TextPart(text: 'Hello, $user!')],
          ),
        ]);
        return TurnResult(finishReason: AgentFinishReason.stop);
      });
      final msgs = sess.getMessages();
      return AgentResult(
        message: msgs.isNotEmpty ? msgs.last : null,
        finishReason: sess.lastTurnFinishReason,
      );
    },
  );

  final chat = agent.chat();

  // Pass a custom context for this turn. The handler reads it via
  // `options.context`.
  final res = await chat.sendText(
    'hi',
    context: {
      'auth': {'name': 'Ada'},
    },
  );
  print(res.text); // -> Hello, Ada!

  // Without a context, the handler falls back to its default.
  final res2 = await chat.sendText('hi again');
  print(res2.text); // -> Hello, stranger!

  await ai.shutdown();
}
