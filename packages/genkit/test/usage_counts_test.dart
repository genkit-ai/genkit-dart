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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('integer counts', () {
    test('GenerationUsage counts are ints', () {
      final usage = GenerationUsage(inputTokens: 12, outputTokens: 30);
      final int total = usage.inputTokens! + usage.outputTokens!;
      expect(total, 42);
      expect('${usage.inputTokens}', '12');
    });

    test('whole-number doubles on the wire still parse', () {
      // Python and some JS paths encode counts as floats.
      final usage = GenerationUsage.fromJson(
        jsonDecode('{"inputTokens": 12.0, "totalTokens": 40}')
            as Map<String, dynamic>,
      );
      expect(usage.inputTokens, 12);
      expect(usage.inputTokens, isA<int>());
      expect(usage.totalTokens, 40);
      expect(usage.outputTokens, isNull);
    });

    test('ints serialize as JSON integers', () {
      final usage = GenerationUsage(inputTokens: 7);
      expect(jsonEncode(usage.toJson()), '{"inputTokens":7}');
    });

    test('Candidate.index, GenerateRequest.candidates, sampleIndex', () {
      final candidate = Candidate.fromJson({
        'index': 0.0,
        'finishReason': 'stop',
        'message': {'role': 'model', 'content': <Object>[]},
      });
      expect(candidate.index, 0);
      expect(
        GenerateRequest.fromJson({
          'messages': <Object>[],
          'candidates': 2,
        }).candidates,
        2,
      );
      expect(
        EvalFnResponse.fromJson({
          'testCaseId': 't',
          'sampleIndex': 3.0,
        }).sampleIndex,
        3,
      );
    });

    test('latencyMs stays a double', () {
      final res = ModelResponse.fromJson({
        'finishReason': 'stop',
        'latencyMs': 12,
      });
      expect(res.latencyMs, isA<double>());
    });
  });
}
