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

import 'wire_harness.dart';

final _blocked = {
  'promptFeedback': {
    'blockReason': 'SAFETY',
    'blockReasonMessage': 'The prompt was blocked for safety.',
    'safetyRatings': <Object>[],
  },
};

final _isBlockedException = isA<GenkitException>()
    .having((e) => e.status, 'status', StatusCode.invalidArgument)
    .having((e) => e.message, 'message', contains('SAFETY'))
    .having(
      (e) => e.message,
      'message',
      contains('The prompt was blocked for safety.'),
    );

void main() {
  setUpAll(setUpFirebaseApp);

  test('generate throws the block reason when the prompt is blocked', () async {
    final model = wireModel(WireClient(response: _blocked));

    await expectLater(
      model(userRequest('hello')),
      throwsA(_isBlockedException),
    );
  });

  test('streaming generate throws the block reason when the prompt is '
      'blocked', () async {
    final model = wireModel(WireClient(streamChunks: [_blocked]));

    await expectLater(
      model(userRequest('hello'), onChunk: (_) {}),
      throwsA(_isBlockedException),
    );
  });

  test('a response with candidates is returned even when promptFeedback '
      'carries a block reason', () async {
    final client = WireClient(response: {...textResponse('hi'), ..._blocked});

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.message?.text, 'hi');
    expect(response.finishReason, FinishReason.stop);
  });
}
