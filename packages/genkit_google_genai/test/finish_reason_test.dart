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

import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/src/common_plugin.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
    as gcl;
import 'package:test/test.dart';

gcl.Candidate _candidate(String? finishReason) => gcl.Candidate(
  index: 0,
  finishReason: finishReason,
  content: gcl.Content(
    role: 'model',
    parts: [gcl.Part(text: 'hi')],
  ),
);

void main() {
  group('fromGeminiCandidate finish reason mapping', () {
    // Mirrors the Go plugin's translateCandidate switch.
    final cases = <String, FinishReason>{
      'STOP': FinishReason.stop,
      'MAX_TOKENS': FinishReason.length,
      'SAFETY': FinishReason.blocked,
      'RECITATION': FinishReason.blocked,
      'PROHIBITED_CONTENT': FinishReason.blocked,
      'IMAGE_SAFETY': FinishReason.blocked,
      'OTHER': FinishReason.other,
      'MALFORMED_FUNCTION_CALL': FinishReason.other,
      'UNEXPECTED_TOOL_CALL': FinishReason.other,
      'MISSING_THOUGHT_SIGNATURE': FinishReason.other,
      'FINISH_REASON_UNSPECIFIED': FinishReason.unknown,
      'SOME_FUTURE_REASON': FinishReason.unknown,
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
}
