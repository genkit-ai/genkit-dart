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
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/aggregation.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;
import 'package:test/test.dart';

CreateChatCompletionStreamResponse _textChunk(
  String text, {
  ChatCompletionFinishReason? finishReason,
  CompletionUsage? usage,
  String? id,
  String? model,
}) {
  return CreateChatCompletionStreamResponse(
    id: id,
    model: model,
    usage: usage,
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        finishReason: finishReason,
        delta: ChatCompletionStreamResponseDelta(content: text),
      ),
    ],
  );
}

CreateChatCompletionStreamResponse _toolCallChunk({
  required int index,
  String? id,
  String? name,
  String? arguments,
  ChatCompletionFinishReason? finishReason,
}) {
  return CreateChatCompletionStreamResponse(
    choices: [
      ChatCompletionStreamResponseChoice(
        index: 0,
        finishReason: finishReason,
        delta: ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: index,
              id: id,
              function: ChatCompletionStreamMessageFunctionCall(
                name: name,
                arguments: arguments,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

void main() {
  group('aggregateStreamResponses', () {
    test('aggregates split text chunks', () {
      final chunks = [
        _textChunk('Hello'),
        _textChunk(' World'),
      ];

      final response = aggregateStreamResponses(chunks);
      expect(response.choices.length, 1);
      final message = response.choices.first.message;
      expect(message.content, 'Hello World');
    });

    test('preserves finish reason from last chunk', () {
      final chunks = [
        _textChunk('Hello'),
        _textChunk('', finishReason: ChatCompletionFinishReason.stop),
      ];

      final response = aggregateStreamResponses(chunks);
      expect(
        response.choices.first.finishReason,
        ChatCompletionFinishReason.stop,
      );
    });

    test('preserves metadata from chunks', () {
      final chunks = [
        _textChunk('Hi', id: 'chatcmpl-123', model: 'gpt-4o'),
        _textChunk(
          '!',
          usage: CompletionUsage(
            promptTokens: 5,
            completionTokens: 2,
            totalTokens: 7,
          ),
        ),
      ];

      final response = aggregateStreamResponses(chunks);
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
        _toolCallChunk(
          index: 0,
          arguments: 'ation":',
        ),
        _toolCallChunk(
          index: 0,
          arguments: '"Boston"}',
          finishReason: ChatCompletionFinishReason.toolCalls,
        ),
      ];

      final response = aggregateStreamResponses(chunks);
      final message = response.choices.first.message;
      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 1);

      final toolCall = message.toolCalls!.first;
      expect(toolCall.id, 'call_abc');
      expect(toolCall.function.name, 'getWeather');
      expect(toolCall.function.arguments, '{"location":"Boston"}');
      expect(
        response.choices.first.finishReason,
        ChatCompletionFinishReason.toolCalls,
      );
    });

    test('aggregates multiple parallel tool calls', () {
      final chunks = [
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

      final response = aggregateStreamResponses(chunks);
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
        _textChunk('Let me check that.'),
        _toolCallChunk(
          index: 0,
          id: 'call_1',
          name: 'search',
          arguments: '{"q":"test"}',
        ),
      ];

      final response = aggregateStreamResponses(chunks);
      final message = response.choices.first.message;
      expect(message.content, 'Let me check that.');
      expect(message.toolCalls, isNotNull);
      expect(message.toolCalls!.length, 1);
    });

    test('skips tool calls with incomplete id or name', () {
      final chunks = [
        _toolCallChunk(index: 0, arguments: '{"partial": true}'),
      ];

      final response = aggregateStreamResponses(chunks);
      final message = response.choices.first.message;
      expect(message.toolCalls, isNull);
    });

    test('handles empty chunks list', () {
      final response = aggregateStreamResponses([]);
      expect(response.choices.length, 1);
      final message = response.choices.first.message;
      expect(message.content, isNull);
      expect(message.toolCalls, isNull);
    });

    test('handles chunks with no choices', () {
      final chunks = [
        CreateChatCompletionStreamResponse(
          usage: CompletionUsage(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
          ),
        ),
      ];

      final response = aggregateStreamResponses(chunks);
      expect(response.usage!.totalTokens, 15);
      final message = response.choices.first.message;
      expect(message.content, isNull);
    });

    test('aggregated JSON converts to valid genkit message', () {
      final jsonObj = {'name': 'John Doe', 'age': 30};
      final jsonStr = jsonEncode(jsonObj);
      final chunks = [
        _textChunk(jsonStr.substring(0, 15)),
        _textChunk(
          jsonStr.substring(15),
          finishReason: ChatCompletionFinishReason.stop,
        ),
      ];

      final response = aggregateStreamResponses(chunks);
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
