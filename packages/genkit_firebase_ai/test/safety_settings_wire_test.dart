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

final _throwsInvalidArgument = throwsA(
  isA<GenkitException>().having(
    (e) => e.status,
    'status',
    StatusCode.invalidArgument,
  ),
);

void main() {
  setUpAll(setUpFirebaseApp);

  test('safetySettings are sent on the wire', () async {
    final client = WireClient();

    await wireModel(client)(
      userRequest(
        'hello',
        config: {
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
            {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'OFF'},
          ],
        },
      ),
    );

    expect(client.requests.single.body['safetySettings'], [
      {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_ONLY_HIGH'},
      {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'OFF'},
    ]);
  });

  test('typed GeminiSafetySettings are sent on the wire', () async {
    final client = WireClient();

    await wireModel(client)(
      userRequest(
        'hello',
        config: GeminiOptions(
          safetySettings: [
            GeminiSafetySettings(
              category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
              threshold: 'BLOCK_LOW_AND_ABOVE',
            ),
          ],
        ).toJson(),
      ),
    );

    expect(client.requests.single.body['safetySettings'], [
      {
        'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
        'threshold': 'BLOCK_LOW_AND_ABOVE',
      },
    ]);
  });

  test('no safetySettings key is sent when none are set', () async {
    final client = WireClient();

    await wireModel(client)(userRequest('hello'));

    expect(client.requests.single.body, isNot(contains('safetySettings')));
  });

  test('Agent Platform sends an image category', () async {
    final client = WireClient();

    await wireModel(client, provider: FirebaseAiProvider.agentPlatform())(
      userRequest(
        'hello',
        config: {
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_IMAGE_HATE',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
          ],
        },
      ),
    );

    expect(client.requests.single.body['safetySettings'], [
      {'category': 'HARM_CATEGORY_IMAGE_HATE', 'threshold': 'BLOCK_ONLY_HIGH'},
    ]);
  });

  test('Agent Platform sends the method', () async {
    final client = WireClient();

    await wireModel(client, provider: FirebaseAiProvider.agentPlatform())(
      userRequest(
        'hello',
        config: {
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
              'method': 'SEVERITY',
            },
          ],
        },
      ),
    );

    expect(client.requests.single.body['safetySettings'], [
      {
        'category': 'HARM_CATEGORY_HATE_SPEECH',
        'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        'method': 'SEVERITY',
      },
    ]);
  });

  final invalid = {
    'a method on the Gemini Developer API': {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'BLOCK_ONLY_HIGH',
      'method': 'SEVERITY',
    },
    'an image category on the Gemini Developer API': {
      'category': 'HARM_CATEGORY_IMAGE_HATE',
      'threshold': 'BLOCK_ONLY_HIGH',
    },
    'an unknown category': {
      'category': 'HARM_CATEGORY_CIVIC_INTEGRITY',
      'threshold': 'BLOCK_ONLY_HIGH',
    },
    'an unknown threshold': {
      'category': 'HARM_CATEGORY_HATE_SPEECH',
      'threshold': 'block_only_high',
    },
    'a missing category': {'threshold': 'BLOCK_ONLY_HIGH'},
    'a missing threshold': {'category': 'HARM_CATEGORY_HATE_SPEECH'},
    'a non-string category': {'category': 3, 'threshold': 'BLOCK_ONLY_HIGH'},
  };
  for (final MapEntry(key: name, value: setting) in invalid.entries) {
    test('$name throws invalidArgument and sends nothing', () async {
      final client = WireClient();

      await expectLater(
        wireModel(client)(
          userRequest(
            'hello',
            config: {
              'safetySettings': [setting],
            },
          ),
        ),
        _throwsInvalidArgument,
      );
      expect(client.requests, isEmpty);
    });
  }
}
