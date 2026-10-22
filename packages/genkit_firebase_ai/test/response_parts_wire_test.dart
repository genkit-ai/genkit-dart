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

import 'package:firebase_ai/firebase_ai.dart' show FirebaseAISdkException;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

Map<String, dynamic> partsResponse(List<Map<String, dynamic>> parts) => {
  'candidates': [
    {
      'content': {'role': 'model', 'parts': parts},
      'finishReason': 'STOP',
    },
  ],
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('codeExecution config sends a codeExecution tool and maps code '
      'execution parts to custom parts', () async {
    final client = WireClient(
      response: partsResponse([
        {'text': 'Let me compute that.'},
        {
          'executableCode': {'language': 'PYTHON', 'code': 'print(1 + 1)'},
        },
        {
          'codeExecutionResult': {'outcome': 'OUTCOME_OK', 'output': '2\n'},
        },
      ]),
    );
    final model = wireModel(client);

    final response = await model(
      userRequest('what is 1 + 1?', config: {'codeExecution': true}),
    );

    expect(client.requests.single.body['tools'], [
      {'codeExecution': <String, dynamic>{}},
    ]);
    final content = response.message!.content;
    expect(content, hasLength(3));
    expect(content[0].text, 'Let me compute that.');
    expect(content[1].custom, {
      'executableCode': {'language': 'PYTHON', 'code': 'print(1 + 1)'},
    });
    expect(content[2].custom, {
      'codeExecutionResult': {'outcome': 'OUTCOME_OK', 'output': '2\n'},
    });
  });

  test('file_data part becomes a MediaPart', () async {
    final client = WireClient(
      response: partsResponse([
        {
          'file_data': {
            'file_uri': 'gs://bucket/cat.png',
            'mime_type': 'image/png',
          },
        },
      ]),
    );
    final model = wireModel(client);

    final response = await model(userRequest('show me'));

    final media = response.message!.content.single.media!;
    expect(media.url, 'gs://bucket/cat.png');
    expect(media.contentType, 'image/png');
  });

  test('unrecognised part becomes a custom part carrying the raw '
      'payload', () async {
    final client = WireClient(
      response: partsResponse([
        {
          'futurePart': {'value': 42},
        },
      ]),
    );
    final model = wireModel(client);

    final response = await model(userRequest('hello'));

    final part = response.message!.content.single;
    expect(
      part.custom,
      equals({
        'futurePart': {'value': 42},
      }),
    );
  });

  test('camelCase fileData part becomes a custom part (pins upstream '
      'firebase_ai limitation: only snake_case file_data is parsed)', () async {
    final client = WireClient(
      response: partsResponse([
        {
          'fileData': {'fileUri': 'gs://b/f.png', 'mimeType': 'image/png'},
        },
      ]),
    );
    final model = wireModel(client);

    final response = await model(userRequest('show me'));

    final part = response.message!.content.single;
    expect(part.media, isNull);
    expect(part.custom, {
      'fileData': {'fileUri': 'gs://b/f.png', 'mimeType': 'image/png'},
    });
  });

  test('codeExecutionResult without output fails in firebase_ai parsing '
      '(pins upstream firebase_ai limitation: output is required)', () async {
    final model = wireModel(
      WireClient(
        response: partsResponse([
          {
            'codeExecutionResult': {'outcome': 'OUTCOME_OK'},
          },
        ]),
      ),
    );

    await expectLater(
      model(userRequest('run it', config: {'codeExecution': true})),
      throwsA(
        isA<FirebaseAISdkException>().having(
          (e) => e.message,
          'message',
          contains('Unhandled format for codeExecutionResult'),
        ),
      ),
    );
  });

  test('code execution parts survive streaming aggregation', () async {
    final client = WireClient(
      streamChunks: [
        partsResponse([
          {
            'executableCode': {'language': 'PYTHON', 'code': 'print(2)'},
          },
        ]),
        partsResponse([
          {
            'codeExecutionResult': {'outcome': 'OUTCOME_OK', 'output': '2\n'},
          },
        ]),
      ],
    );
    final model = wireModel(client);
    final chunks = <ModelResponseChunk>[];

    final response = await model(
      userRequest('run it', config: {'codeExecution': true}),
      onChunk: chunks.add,
    );

    expect(chunks, hasLength(2));
    expect(response.message!.content.map((p) => p.custom!.keys), [
      ['executableCode'],
      ['codeExecutionResult'],
    ]);
  });

  test('code execution parts round-trip when the response is sent back '
      'as history', () async {
    final firstTurnParts = [
      {
        'executableCode': {'language': 'PYTHON', 'code': 'print(1 + 1)'},
        'thoughtSignature': 'sig-code',
      },
      {
        'codeExecutionResult': {'outcome': 'OUTCOME_OK', 'output': '2\n'},
      },
    ];
    final client = WireClient(response: partsResponse(firstTurnParts));
    final model = wireModel(client);
    final config = {'codeExecution': true};

    final first = await model(userRequest('what is 1 + 1?', config: config));
    await model(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'what is 1 + 1?')],
          ),
          first.message!,
          Message(
            role: Role.user,
            content: [TextPart(text: 'and 2 + 2?')],
          ),
        ],
        config: config,
      ),
    );

    final history = client.requests.last.body['contents'] as List;
    expect(history[1], {
      'role': 'model',
      'parts': [
        {
          'thought': false,
          'executableCode': {'language': 'PYTHON', 'code': 'print(1 + 1)'},
          'thoughtSignature': 'sig-code',
        },
        {
          'thought': false,
          'codeExecutionResult': {'outcome': 'OUTCOME_OK', 'output': '2\n'},
        },
      ],
    });
  });

  test('unrecognised thought part carries thought and thoughtSignature in '
      'metadata, not in the custom payload', () async {
    final client = WireClient(
      response: partsResponse([
        {
          'futurePart': {'value': 42},
          'thought': true,
          'thoughtSignature': 'sig-future',
        },
      ]),
    );
    final model = wireModel(client);

    final response = await model(userRequest('hello'));

    final part = response.message!.content.single;
    expect(part.custom, {
      'futurePart': {'value': 42},
    });
    expect(part.metadata, {
      'rawGeminiPart': true,
      'isThought': true,
      'thoughtSignature': 'sig-future',
    });
  });

  test('unrecognised part round-trips with its raw payload when the '
      'response is sent back as history', () async {
    final client = WireClient(
      response: partsResponse([
        {
          'futurePart': {'value': 42},
          'thought': true,
          'thoughtSignature': 'sig-future',
        },
      ]),
    );
    final model = wireModel(client);

    final first = await model(userRequest('hello'));
    await model(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          first.message!,
          Message(
            role: Role.user,
            content: [TextPart(text: 'again')],
          ),
        ],
      ),
    );

    final history = client.requests.last.body['contents'] as List;
    expect(history[1], {
      'role': 'model',
      'parts': [
        {
          'thought': true,
          'futurePart': {'value': 42},
          'thoughtSignature': 'sig-future',
        },
      ],
    });
  });

  test('user-authored custom part is not sent to the API', () async {
    final model = wireModel(WireClient(response: partsResponse([])));

    await expectLater(
      model(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [
                CustomPart(
                  custom: {
                    'futurePart': {'value': 42},
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
