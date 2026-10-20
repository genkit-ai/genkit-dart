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

import 'package:firebase_ai/firebase_ai.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:genkit_firebase_ai/src/aggregation.dart';

void main() {
  group('aggregateResponses', () {
    test('aggregates text parts correctly', () {
      final chunk1 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [m.TextPart('Hello')]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final chunk2 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [m.TextPart(' World')]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final result = aggregateResponses([chunk1, chunk2]);

      expect(result.candidates, hasLength(1));
      final candidate = result.candidates.first;
      expect(candidate.content.parts, hasLength(1));

      final textPart = candidate.content.parts.first as m.TextPart;
      expect(textPart.text, 'Hello World');
    });

    test('keeps parallel FunctionCall parts to the same function', () {
      final result = aggregateResponses([
        _chunk([
          // Gemini only signs the first of a set of parallel calls.
          m.FunctionCall.forTest('getWeather', {
            'location': 'Paris',
          }, thoughtSignature: 'sig'),
        ]),
        _chunk([
          m.FunctionCall.forTest('getWeather', {'location': 'London'}),
        ]),
      ]);

      final parts = result.candidates.single.content.parts;
      expect(parts, hasLength(2));
      expect((parts[0] as m.FunctionCall).args, {'location': 'Paris'});
      expect(_signature(parts[0]), 'sig');
      expect((parts[1] as m.FunctionCall).args, {'location': 'London'});
    });

    test('keeps FunctionCall parts without ids', () {
      final result = aggregateResponses([
        _chunk([m.FunctionCall.forTest('getWeather', {})]),
        _chunk([m.FunctionCall.forTest('getTime', {})]),
      ]);

      final parts = result.candidates.single.content.parts;
      expect(parts.map((p) => (p as m.FunctionCall).name), [
        'getWeather',
        'getTime',
      ]);
    });

    test('replaces FunctionCall parts with identical id', () {
      final chunk1 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [
            m.FunctionCall.forTest('getWeather', {}, id: 'call_123'),
          ]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final chunk2 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [
            m.FunctionCall.forTest('getWeather', {
              'location': 'Paris',
            }, id: 'call_123'),
          ]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final result = aggregateResponses([chunk1, chunk2]);

      expect(result.candidates, hasLength(1));
      final candidate = result.candidates.first;
      expect(candidate.content.parts, hasLength(1));

      final functionCall = candidate.content.parts.first as m.FunctionCall;
      expect(functionCall.name, 'getWeather');
      expect(functionCall.args, {'location': 'Paris'});
      expect(functionCall.id, 'call_123');
    });

    test('appends FunctionCall parts with different name and id', () {
      final chunk1 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [
            m.FunctionCall.forTest('getWeather', {
              'location': 'London',
            }, id: 'call_123'),
          ]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final chunk2 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [
            m.FunctionCall.forTest('getTime', {
              'timezone': 'UTC',
            }, id: 'call_456'),
          ]),
          null,
          null,
          null,
          null,
        ),
      ], null);

      final result = aggregateResponses([chunk1, chunk2]);

      expect(result.candidates, hasLength(1));
      final candidate = result.candidates.first;
      expect(candidate.content.parts, hasLength(2));

      final call1 = candidate.content.parts[0] as m.FunctionCall;
      expect(call1.name, 'getWeather');
      expect(call1.id, 'call_123');

      final call2 = candidate.content.parts[1] as m.FunctionCall;
      expect(call2.name, 'getTime');
      expect(call2.id, 'call_456');
    });

    test('keeps the thought signature when merging text', () {
      final result = aggregateResponses([
        _chunk([m.TextPart('Hello')]),
        _chunk([m.TextPart(' World')]),
        // Gemini often sends the signature on a final, empty text part.
        _chunk([m.TextPart.forTest('', thoughtSignature: 'sig')]),
      ]);

      final part = result.candidates.single.content.parts.single as m.TextPart;
      expect(part.text, 'Hello World');
      expect(_signature(part), 'sig');
    });

    test('keeps thoughts and answer text in separate parts', () {
      final result = aggregateResponses([
        _chunk([m.TextPart('Let me ', isThought: true)]),
        _chunk([m.TextPart('think.', isThought: true)]),
        _chunk([m.TextPart('The answer')]),
        _chunk([m.TextPart(' is 42.')]),
      ]);

      final parts = result.candidates.single.content.parts.cast<m.TextPart>();
      expect(parts.map((p) => p.text), ['Let me think.', 'The answer is 42.']);
      expect(parts.map((p) => p.isThought ?? false), [true, false]);
    });

    test('does not merge text parts that each carry a signature', () {
      final result = aggregateResponses([
        _chunk([m.TextPart.forTest('First', thoughtSignature: 'sig-1')]),
        _chunk([m.TextPart.forTest('Second', thoughtSignature: 'sig-2')]),
      ]);

      final parts = result.candidates.single.content.parts;
      expect(parts.map((p) => (p as m.TextPart).text), ['First', 'Second']);
      expect(parts.map(_signature), ['sig-1', 'sig-2']);
    });

    test('keeps appending text after a signature on the first chunk', () {
      final result = aggregateResponses([
        _chunk([m.TextPart.forTest('The', thoughtSignature: 'sig')]),
        _chunk([m.TextPart(' answer')]),
      ]);

      final part = result.candidates.single.content.parts.single as m.TextPart;
      expect(part.text, 'The answer');
      expect(_signature(part), 'sig');
    });

    test('keeps the signature when a FunctionCall is resent without it', () {
      final result = aggregateResponses([
        _chunk([
          m.FunctionCall.forTest(
            'getWeather',
            {'location': 'Paris'},
            id: 'call_1',
            thoughtSignature: 'sig',
          ),
        ]),
        _chunk([
          m.FunctionCall.forTest('getWeather', {
            'location': 'Paris',
          }, id: 'call_1'),
        ]),
      ]);

      final part = result.candidates.single.content.parts.single;
      expect((part as m.FunctionCall).id, 'call_1');
      expect(_signature(part), 'sig');
    });

    test('streamed signatures reach the Genkit message metadata', () {
      final result = aggregateResponses([
        _chunk([m.TextPart('Checking the weather.', isThought: true)]),
        _chunk([
          m.FunctionCall.forTest('getWeather', {
            'location': 'Paris',
          }, thoughtSignature: 'sig'),
        ]),
      ]);

      final (message, _) = fromGeminiCandidate(result.candidates.single);

      expect(message.content, hasLength(2));
      expect(message.content[0].isReasoning, isTrue);
      expect(message.content[1].isToolRequest, isTrue);
      expect(message.content[1].metadata?['thoughtSignature'], 'sig');
    });
  });
}

m.GenerateContentResponse _chunk(List<m.Part> parts) =>
    m.GenerateContentResponse([
      m.Candidate(m.Content('model', parts), null, null, null, null),
    ], null);

String? _signature(m.Part part) =>
    (part.toJson() as Map<String, dynamic>)['thoughtSignature'] as String?;
