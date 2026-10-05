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

import 'wire_harness.dart';

const _safetyRatings = [
  {'category': 'HARM_CATEGORY_HARASSMENT', 'probability': 'NEGLIGIBLE'},
];

const _usage = {
  'promptTokenCount': 3,
  'candidatesTokenCount': 5,
  'totalTokenCount': 8,
};

// firebase_ai serializes a parsed part with `thought: false` but a text part
// rebuilt by stream aggregation without it, so only the text is pinned.
final _expectedRaw = {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [containsPair('text', 'hi there')],
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
}
