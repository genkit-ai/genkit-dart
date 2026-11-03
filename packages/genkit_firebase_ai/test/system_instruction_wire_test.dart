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

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

import 'wire_harness.dart';

ModelRequest _systemAndUserRequest() => ModelRequest(
  messages: [
    Message(
      role: Role.system,
      content: [TextPart(text: 'Be terse.')],
    ),
    Message(
      role: Role.system,
      content: [TextPart(text: 'Answer in French.')],
    ),
    Message(
      role: Role.user,
      content: [TextPart(text: 'hello')],
    ),
  ],
);

void _expectSystemInstructionSplit(CapturedRequest request) {
  expect(request.body['systemInstruction'], {
    'role': 'system',
    'parts': [
      containsPair('text', 'Be terse.'),
      containsPair('text', 'Answer in French.'),
    ],
  });
  expect(request.body['contents'], [
    {
      'role': 'user',
      'parts': [containsPair('text', 'hello')],
    },
  ]);
}

void main() {
  setUpAll(setUpFirebaseApp);

  test('generate sends system messages as systemInstruction, not as '
      'contents', () async {
    final client = WireClient();

    await wireModel(client)(_systemAndUserRequest());

    _expectSystemInstructionSplit(client.requests.single);
  });

  test('generate without a system message sends no '
      'systemInstruction', () async {
    final client = WireClient();

    await wireModel(client)(userRequest('hello'));

    expect(client.requests.single.body, isNot(contains('systemInstruction')));
  });

  test('streaming generate sends system messages as systemInstruction, '
      'not as contents', () async {
    final client = WireClient();

    await wireModel(client)(_systemAndUserRequest(), onChunk: (_) {});

    final request = client.requests.single;
    expect(request.isStreaming, isTrue);
    _expectSystemInstructionSplit(request);
  });

  test('ai.generate with only a system prompt sends it as the user '
      'turn', () async {
    final client = WireClient();
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);

    await ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      system: 'Say hi',
    );

    final body = client.requests.single.body;
    expect(body, isNot(contains('systemInstruction')));
    expect(body['contents'], [
      {
        'role': 'user',
        'parts': [containsPair('text', 'Say hi')],
      },
    ]);
  });

  test('a system message with a non-text part throws invalidArgument and '
      'sends nothing', () async {
    final client = WireClient();

    await expectLater(
      wireModel(client)(
        ModelRequest(
          messages: [
            Message(
              role: Role.system,
              content: [
                TextPart(text: 'Describe this.'),
                MediaPart(
                  media: Media(url: 'gs://b/f.png', contentType: 'image/png'),
                ),
              ],
            ),
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        ),
      ),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.invalidArgument,
        ),
      ),
    );
    expect(client.requests, isEmpty);
  });

  test('generate lifts a mid-conversation system message into '
      'systemInstruction and keeps the other turns in order', () async {
    final client = WireClient();

    await wireModel(client)(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.system,
            content: [TextPart(text: 'Be terse.')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'how are you?')],
          ),
        ],
      ),
    );

    final body = client.requests.single.body;
    expect(body['systemInstruction'], {
      'role': 'system',
      'parts': [containsPair('text', 'Be terse.')],
    });
    expect(body['contents'], [
      {
        'role': 'user',
        'parts': [containsPair('text', 'hi')],
      },
      {
        'role': 'model',
        'parts': [containsPair('text', 'hello')],
      },
      {
        'role': 'user',
        'parts': [containsPair('text', 'how are you?')],
      },
    ]);
  });
}
