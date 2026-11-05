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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

Message _system(List<Part> parts) => Message(role: Role.system, content: parts);

Future<Map<String, dynamic>> _bodyFor(List<Message> messages) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = WirePlugin(captured);
  final action = plugin.resolve(.model, 'gemini-flash-latest') as Model;
  await action(ModelRequest(messages: messages));
  return captured.single;
}

Message _user() => Message(
  role: Role.user,
  content: [TextPart(text: 'hi')],
);

List<String?> _texts(Map<String, dynamic> body) =>
    ((body['systemInstruction'] as Map)['parts'] as List)
        .map((p) => (p as Map)['text'] as String?)
        .toList();

void main() {
  group('system messages on the wire', () {
    test('sends a single system message as systemInstruction', () async {
      final body = await _bodyFor([
        _system([TextPart(text: 'be terse')]),
        _user(),
      ]);

      expect((body['systemInstruction'] as Map)['role'], 'system');
      expect(_texts(body), ['be terse']);
    });

    test('merges the parts of every system message, in order', () async {
      final body = await _bodyFor([
        _system([TextPart(text: 'one'), TextPart(text: 'two')]),
        _user(),
        _system([TextPart(text: 'three')]),
      ]);

      expect(_texts(body), ['one', 'two', 'three']);
      // The system messages are not also sent as conversation turns.
      final contents = body['contents'] as List;
      expect(contents, hasLength(1));
      expect((contents.single as Map)['role'], 'user');
    });

    test('omits systemInstruction when there is no system message', () async {
      final body = await _bodyFor([_user()]);

      expect(body, isNot(contains('systemInstruction')));
    });

    test('rejects a non-text part in a system message', () async {
      final captured = <Map<String, dynamic>>[];
      final plugin = WirePlugin(captured);
      final action = plugin.resolve(.model, 'gemini-flash-latest') as Model;

      await expectLater(
        action(
          ModelRequest(
            messages: [
              _system([
                TextPart(text: 'be terse'),
                MediaPart(
                  media: Media(
                    url: 'data:image/png;base64,AAAA',
                    contentType: 'image/png',
                  ),
                ),
              ]),
              _user(),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.invalidArgument)
              .having((e) => e.message, 'message', contains('text')),
        ),
      );
      expect(captured, isEmpty);
    });
  });
}
