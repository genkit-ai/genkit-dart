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
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

void main() {
  test('GeminiOptions schema does not declare logprobs options', () {
    final properties =
        GeminiOptions.$schema.jsonSchema()['properties']!
            as Map<String, Object?>;

    expect(properties, isNot(contains('responseLogprobs')));
    expect(properties, isNot(contains('logprobs')));
  });

  test('sampling options say how Gemini 3 treats them', () {
    String? description(Map<String, Object?> schema, String field) =>
        ((schema['properties']! as Map<String, Object?>)[field]!
                as Map<String, Object?>)['description']
            as String?;
    final options = GeminiOptions.$schema.jsonSchema();
    final live = LiveGenerationConfig.$schema.jsonSchema();

    for (final schema in [options, live]) {
      for (final field in ['temperature', 'topP', 'topK']) {
        expect(description(schema, field), contains('ignore'), reason: field);
      }
      for (final field in ['presencePenalty', 'frequencyPenalty']) {
        expect(description(schema, field), contains('400'), reason: field);
      }
    }
    expect(description(options, 'candidateCount'), contains('ignore'));
  });
}
