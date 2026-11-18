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
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
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
      expect(aggregated.candidates!.length, 1);
      expect(aggregated.candidates![0].content!.parts!.length, 1);
      expect(aggregated.candidates![0].content!.parts![0].text, 'Hello World');
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
              finishReason: 'STOP',
              content: gcl.Content(role: 'model', parts: []),
            ),
          ],
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates![0].finishReason, 'STOP');
      expect(aggregated.candidates![0].content!.parts![0].text, 'A');
    });

    test('preserves finish message from last chunk', () {
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
              finishReason: 'SAFETY',
              finishMessage: 'blocked by policy',
            ),
          ],
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates![0].finishReason, 'SAFETY');
      expect(aggregated.candidates![0].finishMessage, 'blocked by policy');
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
      expect(aggregated.candidates![0].content!.parts!.length, 1);
      expect(aggregated.candidates![0].content!.parts![0].text, 'Image: [REF]');
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
          usageMetadata: gcl.UsageMetadata(totalTokenCount: 10),
        ),
      ];

      final aggregated = aggregateResponses(responses);
      expect(aggregated.candidates![0].content!.parts![0].text, 'AB');
      expect(aggregated.candidates![0].groundingMetadata, isNotNull);
      expect(
        aggregated.candidates![0].groundingMetadata!.webSearchQueries,
        contains('query2'),
      );
      expect(aggregated.usageMetadata, isNotNull);
      expect(aggregated.usageMetadata!.totalTokenCount, 10);
    });
  });

  group('aggregateResponses keeps thoughts apart from text', () {
    /// One chunk per part list, as the API streams them.
    List<gcl.GenerateContentResponse> chunks(
      List<List<Map<String, dynamic>>> partsPerChunk,
    ) => [
      for (final parts in partsPerChunk)
        gcl.GenerateContentResponse.fromJson({
          'candidates': [
            {
              'content': {'role': 'model', 'parts': parts},
            },
          ],
        }),
    ];

    List<Map<String, dynamic>> partsOf(gcl.GenerateContentResponse r) =>
        r.candidates!.single.content!.parts!.map((p) => p.toJson()).toList();

    test('joins thoughts with thoughts and text with text, keeping the '
        'flag and the signature', () {
      // The shape of a streamed includeThoughts response (thinking flow).
      final aggregated = aggregateResponses(
        chunks([
          [
            {'text': '**Considering**\n', 'thought': true},
          ],
          [
            {'text': 'more thinking', 'thought': true},
          ],
          [
            {'text': 'They both weigh', 'thoughtSignature': 'sig'},
          ],
          [
            {'text': ' one kilo.'},
          ],
        ]),
      );
      expect(partsOf(aggregated), [
        {'text': '**Considering**\nmore thinking', 'thought': true},
        {'text': 'They both weigh one kilo.', 'thoughtSignature': 'sig'},
      ]);
    });

    test('a signature on a later piece moves to the joined part', () {
      final aggregated = aggregateResponses(
        chunks([
          [
            {'text': 'a'},
          ],
          [
            {'text': 'b', 'thoughtSignature': 'sig'},
          ],
        ]),
      );
      expect(partsOf(aggregated), [
        {'text': 'ab', 'thoughtSignature': 'sig'},
      ]);
    });

    test('two signed pieces stay apart', () {
      final aggregated = aggregateResponses(
        chunks([
          [
            {'text': 'a', 'thoughtSignature': 'sig1'},
          ],
          [
            {'text': 'b', 'thoughtSignature': 'sig2'},
          ],
        ]),
      );
      expect(partsOf(aggregated), [
        {'text': 'a', 'thoughtSignature': 'sig1'},
        {'text': 'b', 'thoughtSignature': 'sig2'},
      ]);
    });

    test('non-text parts are copied whole and end a text run', () {
      final call = {
        'functionCall': {
          'name': 'getWeather',
          'args': {'city': 'Paris'},
        },
        'thoughtSignature': 'sig',
      };
      final aggregated = aggregateResponses(
        chunks([
          [
            {'text': 'Let me check. '},
          ],
          [call],
          [
            {'text': 'Done'},
          ],
        ]),
      );
      expect(partsOf(aggregated), [
        {'text': 'Let me check. '},
        call,
        {'text': 'Done'},
      ]);
    });

    test('an empty part becomes an empty text part (as in JS)', () {
      final aggregated = aggregateResponses(
        chunks([
          [<String, dynamic>{}],
        ]),
      );
      expect(partsOf(aggregated), [
        {'text': ''},
      ]);
    });

    test('merges citation and grounding metadata as JS does', () {
      final aggregated = aggregateResponses([
        gcl.GenerateContentResponse.fromJson({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Hello'},
                ],
              },
              'citationMetadata': {
                'citationSources': [
                  {'uri': 'https://example.com/1'},
                ],
              },
              'groundingMetadata': {
                'groundingChunks': [
                  {
                    'web': {'uri': 'https://example.com/a'},
                  },
                ],
                'webSearchQueries': ['query1'],
              },
            },
          ],
        }),
        gcl.GenerateContentResponse.fromJson({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': ' World'},
                ],
              },
              'citationMetadata': {
                'citationSources': [
                  {'uri': 'https://example.com/2'},
                ],
              },
              'groundingMetadata': {
                'groundingChunks': [
                  {
                    'web': {'uri': 'https://example.com/b'},
                  },
                ],
                'webSearchQueries': ['query2'],
              },
            },
          ],
        }),
      ]);
      final candidate = aggregated.candidates!.single;
      expect(candidate.citationMetadata!.toJson()['citationSources'], [
        {'uri': 'https://example.com/1'},
        {'uri': 'https://example.com/2'},
      ]);
      expect(candidate.groundingMetadata!.toJson()['groundingChunks'], [
        {
          'web': {'uri': 'https://example.com/a'},
        },
        {
          'web': {'uri': 'https://example.com/b'},
        },
      ]);
      expect(candidate.groundingMetadata!.webSearchQueries, [
        'query1',
        'query2',
      ]);
    });

    test('leaves the chunks as received', () {
      final streamed = chunks([
        [
          {'text': 'a'},
        ],
        [
          {'text': 'b'},
        ],
      ]);
      aggregateResponses(streamed);
      expect(partsOf(streamed.first), [
        {'text': 'a'},
      ]);
    });
  });
}
