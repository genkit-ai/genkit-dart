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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_otel/src/genai/gen_ai_message_mapping.dart';
import 'package:test/test.dart';

void main() {
  group('mapRole', () {
    test('remaps model to assistant', () {
      expect(mapRole(Role.model), 'assistant');
    });

    test('passes through other roles', () {
      expect(mapRole(Role.user), 'user');
      expect(mapRole(Role.tool), 'tool');
      expect(mapRole(Role.system), 'system');
    });
  });

  group('mapPart', () {
    test('maps text parts', () {
      expect(mapPart(TextPart(text: 'hi')), {'type': 'text', 'content': 'hi'});
    });

    test('maps tool request parts', () {
      final part = ToolRequestPart(
        toolRequest: ToolRequest(
          ref: 'call_1',
          name: 'weather',
          input: {'city': 'sf'},
        ),
      );
      expect(mapPart(part), {
        'type': 'tool_call',
        'id': 'call_1',
        'name': 'weather',
        'arguments': {'city': 'sf'},
      });
    });

    test('maps tool response parts', () {
      final part = ToolResponsePart(
        toolResponse: ToolResponse(
          ref: 'call_1',
          name: 'weather',
          output: {'temp': 20},
        ),
      );
      expect(mapPart(part), {
        'type': 'tool_call_response',
        'id': 'call_1',
        'response': {'temp': 20},
      });
    });
  });

  group('normalizeMessages', () {
    test('splits system instructions from conversation', () {
      final result = normalizeMessages([
        Message(
          role: Role.system,
          content: [TextPart(text: 'Be helpful')],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'Hi')],
        ),
        Message(
          role: Role.model,
          content: [TextPart(text: 'Hello')],
        ),
      ]);

      expect(result.systemInstructions, [
        {'type': 'text', 'content': 'Be helpful'},
      ]);
      expect(result.messages, [
        {
          'role': 'user',
          'parts': [
            {'type': 'text', 'content': 'Hi'},
          ],
        },
        {
          'role': 'assistant',
          'parts': [
            {'type': 'text', 'content': 'Hello'},
          ],
        },
      ]);
    });
  });

  group('mapOutputMessage', () {
    test('attaches the finish reason', () {
      final message = Message(
        role: Role.model,
        content: [TextPart(text: 'Done')],
      );
      final result = mapOutputMessage(message, 'stop');
      expect(result['role'], 'assistant');
      expect(result['finish_reason'], 'stop');
      expect(result['parts'], [
        {'type': 'text', 'content': 'Done'},
      ]);
    });
  });

  group('mapPart opaque fallback', () {
    test('serializes unknown parts as valid JSON', () {
      final part = Part.fromJson({
        'custom': {'foo': 'bar', 'n': 1},
      });
      final mapped = mapPart(part);
      expect(mapped['type'], 'text');
      final content = mapped['content'] as String;
      // Must be valid JSON (not Dart Map.toString()), round-tripping back.
      expect(jsonDecode(content), {
        'custom': {'foo': 'bar', 'n': 1},
      });
    });
  });

  group('resolveResponseMessage', () {
    test('prefers the top-level message', () {
      final response = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'top')],
        ),
      );
      final message = resolveResponseMessage(response);
      expect(message, isNotNull);
      expect(mapMessage(message!)['parts'], [
        {'type': 'text', 'content': 'top'},
      ]);
    });

    test('falls back to legacy candidates[0].message', () {
      final response = ModelResponse.fromJson({
        'finishReason': 'stop',
        'candidates': [
          {
            'index': 0,
            'finishReason': 'stop',
            'message': {
              'role': 'model',
              'content': [
                {'text': 'from candidate'},
              ],
            },
          },
        ],
      });
      expect(response.message, isNull);
      final message = resolveResponseMessage(response);
      expect(message, isNotNull);
      expect(mapMessage(message!)['parts'], [
        {'type': 'text', 'content': 'from candidate'},
      ]);
    });

    test('returns null when neither message nor candidates present', () {
      final response = ModelResponse.fromJson({'finishReason': 'stop'});
      expect(resolveResponseMessage(response), isNull);
    });
  });
}
