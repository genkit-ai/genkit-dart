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

import 'package:genkit/genkit.dart' hide FinishReason, Tool;
import 'package:genkit_openai/genkit_openai.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;
import 'package:test/test.dart';

ChatStreamEvent _textChunk(
  String text, {
  FinishReason? finishReason,
  Usage? usage,
  String? id,
  String? model,
}) {
  return ChatStreamEvent(
    id: id,
    model: model,
    usage: usage,
    choices: [
      ChatStreamChoice(
        index: 0,
        finishReason: finishReason,
        delta: ChatDelta(content: text),
      ),
    ],
  );
}

ChatStreamEvent _toolCallChunk({
  required int index,
  String? id,
  String? name,
  String? arguments,
  FinishReason? finishReason,
}) {
  return ChatStreamEvent(
    choices: [
      ChatStreamChoice(
        index: 0,
        finishReason: finishReason,
        delta: ChatDelta(
          toolCalls: [
            ToolCallDelta(
              index: index,
              id: id,
              function: FunctionCallDelta(name: name, arguments: arguments),
            ),
          ],
        ),
      ),
    ],
  );
}

ChatCompletion _aggregate(List<ChatStreamEvent> chunks) {
  final acc = ChatStreamAccumulator();
  for (final chunk in chunks) {
    acc.add(chunk);
  }
  return acc.toChatCompletion();
}

void main() {
  group('ChatStreamAccumulator', () {
    test('aggregates split text chunks', () {
      final chunks = [
        _textChunk('Hello', model: 'gpt-4o'),
        _textChunk(' World'),
      ];

      final response = _aggregate(chunks);
      expect(response.choices.length, 1);
      final message = response.choices.first.message;
      expect(message.content, 'Hello World');
    });

    test('preserves finish reason from last chunk', () {
      final chunks = [
        _textChunk('Hello', model: 'gpt-4o'),
        _textChunk('', finishReason: FinishReason.stop),
      ];

      final response = _aggregate(chunks);
      expect(response.choices.first.finishReason, FinishReason.stop);
    });

    test('preserves metadata from chunks', () {
      final chunks = [
        _textChunk('Hi', id: 'chatcmpl-123', model: 'gpt-4o'),
        _textChunk(
          '!',
          usage: Usage(promptTokens: 5, completionTokens: 2, totalTokens: 7),
        ),
      ];

      final response = _aggregate(chunks);
      expect(response.id, 'chatcmpl-123');
      expect(response.model, 'gpt-4o');
      expect(response.usage, isNotNull);
      expect(response.usage!.totalTokens, 7);
      expect(response.object, 'chat.completion');
    });

    test('aggregates tool call fragments', () {
      final chunks = [
        _toolCallChunk(
          index: 0,
          id: 'call_abc',
          name: 'getWeather',
          arguments: '{"loc',
        ),
        _toolCallChunk(index: 0, arguments: 'ation":'),
        _toolCallChunk(
          index: 0,
          arguments: '"Boston"}',
          finishReason: FinishReason.toolCalls,
        ),
      ];
      // Add a model chunk so toChatCompletion() doesn't throw.
      chunks.insert(0, _textChunk('', model: 'gpt-4o'));

      final response = _aggregate(chunks);
      final message = response.choices.first.message;
      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 1);

      final toolCall = message.toolCalls!.first;
      expect(toolCall.id, 'call_abc');
      expect(toolCall.function.name, 'getWeather');
      expect(toolCall.function.arguments, '{"location":"Boston"}');
      expect(response.choices.first.finishReason, FinishReason.toolCalls);
    });

    test('aggregates multiple parallel tool calls', () {
      final chunks = [
        _textChunk('', model: 'gpt-4o'),
        _toolCallChunk(
          index: 0,
          id: 'call_1',
          name: 'getWeather',
          arguments: '{"location"',
        ),
        _toolCallChunk(
          index: 1,
          id: 'call_2',
          name: 'getTime',
          arguments: '{"timezone"',
        ),
        _toolCallChunk(index: 0, arguments: ':"NYC"}'),
        _toolCallChunk(index: 1, arguments: ':"EST"}'),
      ];

      final response = _aggregate(chunks);
      final message = response.choices.first.message;
      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 2);

      expect(message.toolCalls![0].function.name, 'getWeather');
      expect(message.toolCalls![0].function.arguments, '{"location":"NYC"}');
      expect(message.toolCalls![1].function.name, 'getTime');
      expect(message.toolCalls![1].function.arguments, '{"timezone":"EST"}');
    });

    test('aggregates text with tool calls', () {
      final chunks = [
        _textChunk('Let me check that.', model: 'gpt-4o'),
        _toolCallChunk(
          index: 0,
          id: 'call_1',
          name: 'search',
          arguments: '{"q":"test"}',
        ),
      ];

      final response = _aggregate(chunks);
      final message = response.choices.first.message;
      expect(message.content, 'Let me check that.');
      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 1);
    });

    test('skips tool calls with incomplete id or name', () {
      final chunks = [
        _textChunk('', model: 'gpt-4o'),
        _toolCallChunk(index: 0, arguments: '{"partial": true}'),
      ];

      final response = _aggregate(chunks);
      final message = response.choices.first.message;
      expect(message.toolCalls, isNull);
    });

    test('throws StateError for empty chunks list', () {
      expect(() => _aggregate([]), throwsStateError);
    });

    test('handles chunks with no choices', () {
      final chunks = [
        ChatStreamEvent(
          model: 'gpt-4o',
          usage: Usage(promptTokens: 10, completionTokens: 5, totalTokens: 15),
        ),
      ];

      final response = _aggregate(chunks);
      expect(response.usage!.totalTokens, 15);
      final message = response.choices.first.message;
      expect(message.content, isNull);
    });

    test('aggregated JSON converts to valid genkit message', () {
      final jsonObj = {'name': 'John Doe', 'age': 30};
      final jsonStr = jsonEncode(jsonObj);
      final chunks = [
        _textChunk(jsonStr.substring(0, 15), model: 'gpt-4o'),
        _textChunk(jsonStr.substring(15), finishReason: FinishReason.stop),
      ];

      final response = _aggregate(chunks);
      final message = GenkitConverter.fromOpenAIAssistantMessage(
        response.choices.first.message,
      );

      expect(message.role, Role.model);
      expect(message.text, jsonStr);
      final parsed = jsonDecode(message.text) as Map<String, dynamic>;
      expect(parsed['name'], 'John Doe');
      expect(parsed['age'], 30);
    });
  });
}
