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
import 'package:genkit_openai/src/aggregation.dart';
import 'package:genkit_openai/src/converters.dart';
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:openai_dart/openai_dart.dart' hide Model;
import 'package:test/test.dart';

JsonSchemaObject _jsonSchema(ResponseFormat format) {
  return (format as ResponseFormatJsonSchema).jsonSchema;
}

CreateChatCompletionStreamResponse _jsonChunk(
  String jsonText, {
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
        delta: ChatCompletionStreamResponseDelta(content: jsonText),
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

Map<String, dynamic> _createPersonSchema() {
  return {
    r'$defs': {
      'Person': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
        'required': ['name', 'age'],
      },
    },
    'type': 'object',
    r'$ref': '#/\$defs/Person',
  };
}

void main() {
  group('buildOpenAIResponseFormat', () {
    test('builds ResponseFormat from schema with \$defs', () {
      final result = buildOpenAIResponseFormat(_createPersonSchema());
      expect(result, isNotNull);
      final js = _jsonSchema(result!);
      expect(js.name, 'output');
      expect(js.schema['type'], 'object');
      expect(js.schema['additionalProperties'], false);
      expect(js.schema['properties'], isNotNull);
    });

    test('returns null only for null schema', () {
      expect(buildOpenAIResponseFormat(null), isNull);
    });

    test('builds ResponseFormat from schema without \$defs', () {
      final result = buildOpenAIResponseFormat({'type': 'object'});
      expect(result, isNotNull);
      final js = _jsonSchema(result!);
      expect(js.name, 'output');
      expect(js.schema['type'], 'object');
      expect(js.schema['additionalProperties'], false);
    });
  });

  group('isJsonStructuredOutput', () {
    test('true when format or contentType is json', () {
      expect(isJsonStructuredOutput('json', null), isTrue);
      expect(isJsonStructuredOutput(null, 'application/json'), isTrue);
    });
    test('false when neither set', () {
      expect(isJsonStructuredOutput(null, null), isFalse);
      expect(isJsonStructuredOutput('text', null), isFalse);
    });
  });

  group('aggregateStreamResponses', () {
    test('concatenates content chunks', () {
      final jsonStr = '{"name": "Jane", "age": 25}';
      final mid = jsonStr.length ~/ 2;
      final chunks = [
        _jsonChunk(jsonStr.substring(0, mid)),
        _jsonChunk(
          jsonStr.substring(mid),
          finishReason: ChatCompletionFinishReason.stop,
        ),
      ];
      final response = aggregateStreamResponses(chunks);
      expect(response.choices.first.message.content, jsonStr);
    });

    test('aggregates content and tool calls', () {
      final chunks = [
        _jsonChunk('{"name": "Test"'),
        _toolCallChunk(
          index: 0,
          id: 'call_1',
          name: 'getWeather',
          arguments: '{"location": "Boston"}',
          finishReason: ChatCompletionFinishReason.toolCalls,
        ),
      ];
      final response = aggregateStreamResponses(chunks);
      expect(response.choices.first.message.content, '{"name": "Test"');
      expect(response.choices.first.message.toolCalls!.length, 1);
      expect(response.choices.first.message.toolCalls!.first.function.name, 'getWeather');
    });
  });

  group('GenkitConverter', () {
    test('fromOpenAIAssistantMessage converts JSON content', () {
      final message = ChatCompletionMessage.assistant(content: '{"name": "Test", "age": 25}')
          as ChatCompletionAssistantMessage;
      final genkitMessage = GenkitConverter.fromOpenAIAssistantMessage(message);
      expect(genkitMessage.role, Role.model);
      expect(genkitMessage.text, '{"name": "Test", "age": 25}');
    });

    test('fromOpenAIAssistantMessage converts message with tool calls', () {
      final message = ChatCompletionMessage.assistant(
        content: '{"result": "ok"}',
        toolCalls: [
          ChatCompletionMessageToolCall(
            id: 'call_123',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'getWeather',
              arguments: '{"location": "NYC"}',
            ),
          ),
        ],
      ) as ChatCompletionAssistantMessage;
      final genkitMessage = GenkitConverter.fromOpenAIAssistantMessage(message);
      expect(genkitMessage.text, '{"result": "ok"}');
      final toolParts = genkitMessage.content.where((p) => p.isToolRequest).toList();
      expect(toolParts.length, 1);
      expect(toolParts.first.toolRequest!.name, 'getWeather');
    });
  });

  group('Round-trip', () {
    test('stream aggregation then conversion preserves JSON', () {
      final originalJson = {
        'name': 'John Doe',
        'age': 30,
        'address': {'city': 'New York', 'zip': '10001'},
      };
      final jsonStr = jsonEncode(originalJson);
      final split = jsonStr.length ~/ 2;
      final chunks = [
        _jsonChunk(jsonStr.substring(0, split)),
        _jsonChunk(
          jsonStr.substring(split),
          finishReason: ChatCompletionFinishReason.stop,
        ),
      ];
      final aggregated = aggregateStreamResponses(chunks);
      final message = GenkitConverter.fromOpenAIAssistantMessage(
        aggregated.choices.first.message,
      );
      final parsed = jsonDecode(message.text) as Map<String, dynamic>;
      expect(parsed['name'], 'John Doe');
      expect(parsed['age'], 30);
      // ignore: avoid_dynamic_calls
      expect(parsed['address']['city'], 'New York');
    });
  });
}
