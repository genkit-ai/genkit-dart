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
import 'package:genkit_a2ui/client.dart';
import 'package:test/test.dart';

A2uiClientAction makeAction({Map<String, dynamic>? context}) {
  return A2uiClientAction(
    name: 'submit',
    surfaceId: 'surface-1',
    sourceComponentId: 'btn',
    timestamp: '2026-01-01T00:00:00.000Z',
    context: context ?? const {},
  );
}

void main() {
  group('actionToMessage', () {
    test('builds a user message summarizing the action', () {
      final message = actionToMessage(makeAction());
      expect(message.role, Role.user);
      final summary = message.content[0].text ?? '';
      expect(summary, contains('submit'));
      expect(summary, contains('surface-1'));
    });

    test('attaches the full action as an a2ui data part', () {
      final action = makeAction();
      final message = actionToMessage(action);
      final dataPart = message.content[1];
      expect(isA2uiPart(dataPart), isTrue);
      expect(dataPart.metadata?['mimeType'], a2uiMimeType);
      expect(dataPart.data, {
        'envelopes': [
          {'action': action.toJson()},
        ],
      });
    });

    test('includes the context in the summary when present', () {
      final message = actionToMessage(makeAction(context: {'city': 'Tokyo'}));
      final summary = message.content[0].text ?? '';
      expect(summary, contains('context'));
      expect(summary, contains('Tokyo'));
    });

    test('omits the context clause when context is empty', () {
      final message = actionToMessage(makeAction());
      final summary = message.content[0].text ?? '';
      expect(summary, isNot(contains('context')));
    });
  });
}
