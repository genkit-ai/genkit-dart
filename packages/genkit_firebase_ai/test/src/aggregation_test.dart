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

    test('replaces FunctionCall parts with identical name', () {
      final chunk1 = m.GenerateContentResponse([
        m.Candidate(
          m.Content('model', [
            m.FunctionCall.forTest('getWeather', {'location': ''}),
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
            m.FunctionCall.forTest('getWeather', {'location': 'London'}),
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
      expect(functionCall.args, {'location': 'London'});
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
  });
}
