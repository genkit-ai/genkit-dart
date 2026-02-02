// Copyright 2025 Google LLC
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

import 'package:genkit_google_genai/src/aggregation.dart';
import 'package:google_cloud_ai_generativelanguage_v1beta/generativelanguage.dart'
    as gcl;
import 'package:test/test.dart';

void main() {
  group('aggregateResponses', () {
    test('aggregates split text chunks', () {
      final responses = [
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              content: gcl.Content(
                role: 'model',
                parts: [gcl.Part(text: 'Hello')],
              ),
            ),
          ],
        ),
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              content: gcl.Content(
                role: 'model',
                parts: [gcl.Part(text: ' World')],
              ),
            ),
          ],
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates.length, 1);
      expect(aggregated.candidates[0].content!.parts.length, 1);
      expect(aggregated.candidates[0].content!.parts[0].text, 'Hello World');
    });

    test('preserves finish reason from last chunk', () {
      final responses = [
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              content: gcl.Content(
                role: 'model',
                parts: [gcl.Part(text: 'A')],
              ),
            ),
          ],
        ),
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              finishReason: gcl.Candidate_FinishReason.stop,
              content: gcl.Content(role: 'model', parts: []),
            ),
          ],
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(
        aggregated.candidates[0].finishReason,
        gcl.Candidate_FinishReason.stop,
      );
      expect(aggregated.candidates[0].content!.parts[0].text, 'A');
    });

    test('handles multiple parts', () {
      final responses = [
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              // index 0
              content: gcl.Content(
                role: 'model',
                parts: [gcl.Part(text: 'Image:')],
              ),
            ),
          ],
        ),
        // Suppose we get a file data part? (Usually input, but model might return weird stuff?)
        // Or just another text part.
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              content: gcl.Content(
                role: 'model',
                parts: [gcl.Part(text: ' [REF]')],
              ),
            ),
          ],
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates[0].content!.parts.length, 1);
      expect(aggregated.candidates[0].content!.parts[0].text, 'Image: [REF]');
    });

    test('aggregates usage and grounding metadata', () {
      final responses = [
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              content: gcl.Content(parts: [gcl.Part(text: 'A')]),
              groundingMetadata: gcl.GroundingMetadata(
                webSearchQueries: ['query1'],
              ),
            ),
          ],
        ),
        gcl.GenerateContentResponse(
          candidates: [
            gcl.Candidate(
              index: 0,
              content: gcl.Content(parts: [gcl.Part(text: 'B')]),
              groundingMetadata: gcl.GroundingMetadata(
                webSearchQueries: ['query2'],
              ),
            ),
          ],
          usageMetadata: gcl.GenerateContentResponse_UsageMetadata(
            totalTokenCount: 10,
          ),
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates[0].content!.parts[0].text, 'AB');
      expect(aggregated.candidates[0].groundingMetadata, isNotNull);
      expect(
        aggregated.candidates[0].groundingMetadata!.webSearchQueries,
        contains('query2'),
      );
      expect(aggregated.usageMetadata, isNotNull);
      expect(aggregated.usageMetadata!.totalTokenCount, 10);
    });
  });
}
