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

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

part 'stateful_interactions.g.dart';

@Schematic()
abstract class $StatefulChatInput {
  String get sessionId;
  String get message;
}

// A simple in-memory store for conversation history.
// In a real app, you would use a database like Firestore or Redis.
final _historyStore = <String, List<Message>>{};

Future<List<Message>> _loadHistory(String sessionId) async {
  return _historyStore[sessionId] ?? [];
}

Future<void> _saveHistory(String sessionId, List<Message> history) async {
  _historyStore[sessionId] = history;
}

Flow<StatefulChatInput, String, void, void> defineStatefulChatFlow(
  Genkit ai,
  ModelRef geminiFlash,
) {
  return ai.defineFlow(
    name: 'statefulChatFlow',
    inputSchema: StatefulChatInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      // 1. Load history
      final history = await _loadHistory(input.sessionId);

      // 2. Append new message
      history.add(
          Message(role: Role.user, content: [TextPart(text: input.message)]));

      // 3. Generate response with history
      final response = await ai.generate(
        model: geminiFlash,
        messages: history,
      );

      // 4. Save updated history
      // Note: response.messages includes the history + new response
      await _saveHistory(input.sessionId, response.messages);

      return response.text;
    },
  );
}
