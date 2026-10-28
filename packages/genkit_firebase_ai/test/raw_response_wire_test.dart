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

const _safetyRatings = [
  {'category': 'HARM_CATEGORY_HARASSMENT', 'probability': 'NEGLIGIBLE'},
];

const _usage = {
  'promptTokenCount': 3,
  'candidatesTokenCount': 5,
  'totalTokenCount': 8,
};

// firebase_ai parses every part with `thought: false`, so it shows up in raw
// although the wire had no such key.
final _expectedRaw = {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': 'hi there', 'thought': false},
        ],
      },
      'finishReason': 'MAX_TOKENS',
      'safetyRatings': _safetyRatings,
    },
  ],
  'promptFeedback': {'safetyRatings': _safetyRatings},
  'usageMetadata': _usage,
};

Map<String, dynamic> _chunk(String text, {bool last = false}) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      },
      if (last) 'finishReason': 'MAX_TOKENS',
      if (last) 'safetyRatings': _safetyRatings,
    },
  ],
  if (last) 'promptFeedback': {'safetyRatings': _safetyRatings},
  if (last) 'usageMetadata': _usage,
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('raw carries the provider response', () async {
    final client = WireClient(response: _chunk('hi there', last: true));

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.raw, _expectedRaw);
  });

  test('streaming raw carries the aggregated provider response', () async {
    final client = WireClient(
      streamChunks: [_chunk('hi '), _chunk('there', last: true)],
    );

    final response = await wireModel(client)(
      userRequest('hello'),
      onChunk: (_) {},
    );

    expect(response.raw, _expectedRaw);
  });
  test('agentPlatform raw carries safety ratings in wire form', () async {
    const rating = {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'probability': 'LOW',
      'probabilityScore': 0.25,
      'blocked': false,
      'severity': 'HARM_SEVERITY_NEGLIGIBLE',
      'severityScore': 0.125,
    };
    final client = WireClient(
      response: {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'hi'},
              ],
            },
            'finishReason': 'STOP',
            'safetyRatings': [rating],
          },
        ],
        'promptFeedback': {
          'safetyRatings': [rating],
        },
      },
    );

    final response = await wireModel(
      client,
      provider: const FirebaseAiProvider.agentPlatform(),
    )(userRequest('hello'));

    expect(
      (response.raw!['candidates'] as List).single,
      containsPair('safetyRatings', [rating]),
    );
    expect(response.raw!['promptFeedback'], {
      'safetyRatings': [rating],
    });
  });

  test('agentPlatform streaming raw carries severity in wire form', () async {
    const rating = {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'probability': 'MEDIUM',
      'probabilityScore': 0.5,
      'severity': 'HARM_SEVERITY_HIGH',
      'severityScore': 0.75,
    };
    final client = WireClient(
      streamChunks: [
        _chunk('hi '),
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'there'},
                ],
              },
              'safetyRatings': [rating],
            },
          ],
        },
      ],
    );

    final response = await wireModel(
      client,
      provider: const FirebaseAiProvider.agentPlatform(),
    )(userRequest('hello'), onChunk: (_) {});

    expect(
      (response.raw!['candidates'] as List).single,
      containsPair('safetyRatings', [rating]),
    );
  });

  test('streaming raw keeps one safety rating per category', () async {
    const harassment = {
      'category': 'HARM_CATEGORY_HARASSMENT',
      'probability': 'LOW',
    };
    const hate = {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'probability': 'NEGLIGIBLE',
    };
    Map<String, dynamic> chunk(String text, List<Object> ratings) => {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': text},
            ],
          },
          'safetyRatings': ratings,
        },
      ],
    };
    final client = WireClient(
      streamChunks: [
        chunk('a', _safetyRatings),
        chunk('b', [..._safetyRatings, hate]),
        chunk('c', [harassment]),
      ],
    );

    final response = await wireModel(client)(
      userRequest('hello'),
      onChunk: (_) {},
    );

    final candidates = response.raw!['candidates'] as List;
    expect((candidates.single as Map)['safetyRatings'], [harassment, hate]);
  });

  test('streaming raw keeps candidates separate', () async {
    Map<String, dynamic> candidate(String text) => {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      },
    };
    final client = WireClient(
      streamChunks: [
        {
          'candidates': [candidate('one '), candidate('two ')],
        },
        {
          'candidates': [candidate('a'), candidate('b')],
        },
      ],
    );

    final response = await wireModel(client)(
      userRequest('hello'),
      onChunk: (_) {},
    );

    expect(response.raw!['candidates'], [
      containsPair('content', {
        'role': 'model',
        'parts': [containsPair('text', 'one a')],
      }),
      containsPair('content', {
        'role': 'model',
        'parts': [containsPair('text', 'two b')],
      }),
    ]);
  });

  test('streaming with candidateCount > 1 throws invalidArgument and sends '
      'nothing', () async {
    final client = WireClient();

    await expectLater(
      wireModel(client)(
        userRequest('hello', config: {'candidateCount': 2}),
        onChunk: (_) {},
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

  test('generate with candidateCount > 1 is still sent', () async {
    final client = WireClient();

    await wireModel(client)(
      userRequest('hello', config: {'candidateCount': 2}),
    );

    expect(
      client.requests.single.body['generationConfig'],
      containsPair('candidateCount', 2),
    );
  });

  test('streaming raw keeps an unknown finish reason', () async {
    const wire = {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              {'text': 'hi'},
            ],
          },
          'finishReason': 'SOMETHING_NEW',
        },
      ],
    };

    final generated = await wireModel(WireClient(response: wire))(
      userRequest('hello'),
    );
    final streamed = await wireModel(WireClient(streamChunks: [wire]))(
      userRequest('hello'),
      onChunk: (_) {},
    );

    expect(
      (generated.raw!['candidates'] as List).single,
      containsPair('finishReason', 'UNKNOWN'),
    );
    expect(streamed.raw, generated.raw);
  });

  test('raw leaves out content the wire did not send', () async {
    const wire = {
      'candidates': [
        {'finishReason': 'SAFETY'},
      ],
    };

    final generated = await wireModel(WireClient(response: wire))(
      userRequest('hello'),
    );
    final streamed = await wireModel(WireClient(streamChunks: [wire]))(
      userRequest('hello'),
      onChunk: (_) {},
    );

    expect(generated.raw, {
      'candidates': [
        {'finishReason': 'SAFETY'},
      ],
    });
    expect(streamed.raw, generated.raw);
  });
}
