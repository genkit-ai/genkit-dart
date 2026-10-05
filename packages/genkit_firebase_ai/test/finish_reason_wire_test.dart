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

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

const _expected = <String, FinishReason>{
  'UNKNOWN': FinishReason.unknown,
  'STOP': FinishReason.stop,
  'MAX_TOKENS': FinishReason.length,
  'SAFETY': FinishReason.blocked,
  'RECITATION': FinishReason.blocked,
  'LANGUAGE': FinishReason.blocked,
  'BLOCKLIST': FinishReason.blocked,
  'PROHIBITED_CONTENT': FinishReason.blocked,
  'SPII': FinishReason.blocked,
  'IMAGE_SAFETY': FinishReason.blocked,
  'IMAGE_PROHIBITED_CONTENT': FinishReason.blocked,
  'IMAGE_RECITATION': FinishReason.blocked,
  'MALFORMED_FUNCTION_CALL': FinishReason.other,
  'UNEXPECTED_TOOL_CALL': FinishReason.other,
  'TOO_MANY_TOOL_CALLS': FinishReason.other,
  'NO_IMAGE': FinishReason.other,
  'IMAGE_OTHER': FinishReason.other,
  'MALFORMED_RESPONSE': FinishReason.other,
  'MISSING_THOUGHT_SIGNATURE': FinishReason.other,
  'OTHER': FinishReason.other,
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('the table covers every upstream finish reason', () {
    expect(
      _expected.keys,
      unorderedEquals(fai.FinishReason.values.map((r) => r.toJson())),
    );
  });

  for (final MapEntry(key: wire, value: expected) in _expected.entries) {
    test('$wire maps to ${expected.value}', () async {
      final client = WireClient(
        response: textResponse('partial', finishReason: wire),
      );

      final response = await wireModel(client)(userRequest('hello'));

      expect(response.finishReason, expected);
      expect(response.finishMessage, isNull);
      expect(response.custom?['finishReason'], wire);
      expect(response.message?.text, 'partial');
    });
  }

  test('a missing finish reason maps to unknown', () async {
    final client = WireClient(
      response: textResponse('partial', finishReason: null),
    );

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.finishReason, FinishReason.unknown);
    expect(response.finishMessage, isNull);
    expect(response.custom, isNull);
  });

  test('an unrecognized wire value maps to unknown', () async {
    final client = WireClient(
      response: textResponse('partial', finishReason: 'SOMETHING_NEW'),
    );

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.finishReason, FinishReason.unknown);
    expect(response.finishMessage, isNull);
    expect(response.custom?['finishReason'], 'UNKNOWN');
  });

  test('finishMessage carries the candidate finishMessage', () async {
    final client = WireClient(
      response: {
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': 'partial'},
              ],
            },
            'finishReason': 'SAFETY',
            'finishMessage': 'Flagged for harassment.',
          },
        ],
      },
    );

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.finishReason, FinishReason.blocked);
    expect(response.finishMessage, 'Flagged for harassment.');
    expect(response.custom?['finishReason'], 'SAFETY');
  });

  test('streaming aggregation keeps the mapped finish reason', () async {
    final client = WireClient(
      streamChunks: [
        textResponse('Hello, ', finishReason: null),
        textResponse('wor', finishReason: 'MAX_TOKENS'),
      ],
    );
    final chunks = <ModelResponseChunk>[];

    final response = await wireModel(client)(
      userRequest('hello'),
      onChunk: chunks.add,
    );

    expect(chunks.map((c) => c.text), ['Hello, ', 'wor']);
    expect(response.message?.text, 'Hello, wor');
    expect(response.finishReason, FinishReason.length);
    expect(response.finishMessage, isNull);
    expect(response.custom?['finishReason'], 'MAX_TOKENS');
  });
}
