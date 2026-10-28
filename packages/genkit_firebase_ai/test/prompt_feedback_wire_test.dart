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

final _blocked = {
  'promptFeedback': {
    'blockReason': 'SAFETY',
    'blockReasonMessage': 'The prompt was blocked for safety.',
    'safetyRatings': <Object>[],
  },
};

final _isBlockedException = isA<GenkitException>()
    .having((e) => e.status, 'status', StatusCode.failedPrecondition)
    .having((e) => e.message, 'message', contains('SAFETY'))
    .having(
      (e) => e.message,
      'message',
      contains('The prompt was blocked for safety.'),
    );

final _blockedWithoutRatings = {
  'promptFeedback': {'blockReason': 'PROHIBITED_CONTENT'},
};

final _isBlockedWithoutRatingsException = isA<GenkitException>()
    .having((e) => e.status, 'status', StatusCode.failedPrecondition)
    .having(
      (e) => e.message,
      'message',
      'Prompt was blocked (PROHIBITED_CONTENT).',
    );

/// A part firebase_ai still cannot parse (firebase/flutterfire#18881).
final _unparseable = {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {
            'codeExecutionResult': {'outcome': 'OUTCOME_OK'},
          },
        ],
      },
    },
  ],
};

void main() {
  setUpAll(setUpFirebaseApp);

  test(
    'generate fails with the block reason when the prompt is blocked',
    () async {
      final model = wireModel(WireClient(response: _blocked));

      await expectLater(
        model(userRequest('hello')),
        throwsA(_isBlockedException),
      );
    },
  );

  test('streaming generate fails with the block reason when the prompt is '
      'blocked', () async {
    final model = wireModel(WireClient(streamChunks: [_blocked]));

    await expectLater(
      model(userRequest('hello'), onChunk: (_) {}),
      throwsA(_isBlockedException),
    );
  });

  test('ai.generate fails with the block reason when the prompt is '
      'blocked', () async {
    final client = WireClient(streamChunks: [_blocked]);
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);

    final response = await ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      prompt: 'hello',
      onChunk: (_) {},
    );

    expect(response.finishReason, FinishReason.failed);
    expect(response.error?.status, StatusCode.failedPrecondition.wireName);
    expect(response.error?.message, contains('SAFETY'));
  });

  test('an empty blockReasonMessage leaves no trailing separator', () async {
    final model = wireModel(
      WireClient(
        response: {
          'promptFeedback': {
            'blockReason': 'SAFETY',
            'blockReasonMessage': '',
            'safetyRatings': <Object>[],
          },
        },
      ),
    );

    await expectLater(
      model(userRequest('hello')),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.message,
          'message',
          'Prompt was blocked (SAFETY).',
        ),
      ),
    );
  });

  test('generate reports a block reason that comes without '
      'safetyRatings', () async {
    final model = wireModel(WireClient(response: _blockedWithoutRatings));

    await expectLater(
      model(userRequest('hello')),
      throwsA(_isBlockedWithoutRatingsException),
    );
  });

  test('streaming generate reports a block reason that comes without '
      'safetyRatings', () async {
    final model = wireModel(WireClient(streamChunks: [_blockedWithoutRatings]));

    await expectLater(
      model(userRequest('hello'), onChunk: (_) {}),
      throwsA(_isBlockedWithoutRatingsException),
    );
  });

  test('a response firebase_ai cannot parse is not retried', () async {
    final client = WireClient(response: _unparseable);
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);

    final result = await ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      prompt: 'hello',
      use: [
        retry(maxRetries: 2, initialDelay: const Duration(milliseconds: 1)),
      ],
    );

    expect(result.finishReason, FinishReason.failed);
    expect(client.requests, hasLength(1));
  });

  test('a response with candidates is returned even when promptFeedback '
      'carries a block reason', () async {
    final client = WireClient(response: {...textResponse('hi'), ..._blocked});

    final response = await wireModel(client)(userRequest('hello'));

    // The finish reason is left unpinned: #578 asks for `blocked` here, which
    // is a follow-up.
    expect(response.message?.text, 'hi');
  });
}
