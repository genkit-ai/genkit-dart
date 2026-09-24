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
import 'package:genkit_google_genai/src/common_plugin.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
    as gcl;
import 'package:test/test.dart';

import 'test_harness.dart';

gcl.Candidate _candidate(String? finishReason) => gcl.Candidate(
  index: 0,
  finishReason: finishReason,
  content: gcl.Content(
    role: 'model',
    parts: [gcl.Part(text: 'hi')],
  ),
);

/// A content-less candidate, the shape Gemini uses for blocked turns.
Map<String, dynamic> _blockedResponse(String finishReason) => {
  'candidates': [
    {
      'index': 0,
      'finishReason': finishReason,
      'finishMessage': 'blocked by policy',
    },
  ],
};

void main() {
  group('fromGeminiCandidate finish reason mapping', () {
    // Union of the Gemini discovery doc, the Gemini and Vertex protos, the
    // Gen AI SDKs and the Firebase SDKs; no single list is complete.
    final cases = <String, FinishReason>{
      '': FinishReason.unknown,
      'FINISH_REASON_UNSPECIFIED': FinishReason.unknown,
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
      'MODEL_ARMOR': FinishReason.blocked,
      'ESCALATION': FinishReason.blocked,
      'PUP_LIMITED_DISABLED': FinishReason.blocked,
      'MALFORMED_FUNCTION_CALL': FinishReason.other,
      'UNEXPECTED_TOOL_CALL': FinishReason.other,
      'TOO_MANY_TOOL_CALLS': FinishReason.other,
      'NO_IMAGE': FinishReason.other,
      'IMAGE_OTHER': FinishReason.other,
      'MALFORMED_RESPONSE': FinishReason.other,
      'MISSING_THOUGHT_SIGNATURE': FinishReason.other,
      'OTHER': FinishReason.other,
      // Unrecognized reasons are abnormal so output parsing is skipped.
      'SOME_FUTURE_REASON': FinishReason.other,
    };

    cases.forEach((raw, expected) {
      test('$raw -> ${expected.value}', () {
        final (_, reason) = fromGeminiCandidate(_candidate(raw));
        expect(reason.value, expected.value);
      });
    });

    test('absent finish reason maps to unknown (never "unspecified")', () {
      final (_, reason) = fromGeminiCandidate(_candidate(null));
      expect(reason.value, FinishReason.unknown.value);
      expect(reason.value, isNot('unspecified'));
    });

    test(
      'content-less candidate does not throw and defaults role to model',
      () {
        final (message, reason) = fromGeminiCandidate(
          gcl.Candidate(index: 0, finishReason: 'STOP'),
        );
        expect(message.role, Role.model);
        expect(message.content, isEmpty);
        expect(reason.value, FinishReason.stop.value);
      },
    );
  });

  group('model action', () {
    test(
      'surfaces finishMessage on a content-less blocked candidate',
      () async {
        final plugin = WirePlugin([], response: _blockedResponse('SAFETY'));
        final model = plugin.resolve(.model, 'gemini-flash-latest') as Model;
        final response = await model(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
          ),
        );
        expect(response.finishReason, FinishReason.blocked);
        expect(response.finishMessage, 'blocked by policy');
        expect(response.message?.content, isEmpty);
      },
    );

    test('JSON output on a blocked turn skips parsing instead of reporting a '
        'schema error', () async {
      final ai = Genkit(
        plugins: [WirePlugin([], response: _blockedResponse('ESCALATION'))],
        promptDir: null,
        isDevEnv: false,
      );
      addTearDown(ai.shutdown);
      final response = await ai.generate(
        model: modelRef('googleai/gemini-flash-latest'),
        prompt: 'give me json',
        outputSchema: .string(),
      );
      expect(response.finishReason, FinishReason.blocked);
      expect(response.finishMessage, 'blocked by policy');
      expect(response.error, isNull);
    });
  });
}
