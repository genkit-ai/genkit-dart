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

import 'package:genkit/genkit.dart' hide Tool;
import 'package:genkit_openai/genkit_openai.dart';
import 'package:openai_dart/openai_dart.dart'
    show
        AssistantMessage,
        ChatMessage,
        ContentPart,
        FunctionCall,
        SystemMessage,
        ToolCall,
        ToolMessage,
        UserMessage;
import 'package:test/test.dart';

void main() {
  group('GenkitConverter.toOpenAIMessage', () {
    test('converts system message', () {
      final msg = Message(
        role: Role.system,
        content: [TextPart(text: 'You are helpful.')],
      );
      final result = GenkitConverter.toOpenAIMessage(msg, null);
      expect(result, isA<SystemMessage>());
      expect((result as SystemMessage).content, 'You are helpful.');
    });

    test('converts user message with text', () {
      final msg = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello!')],
      );
      final result = GenkitConverter.toOpenAIMessage(msg, null);
      expect(result, isA<UserMessage>());
    });

    test('converts model message with tool calls', () {
      final msg = Message(
        role: Role.model,
        content: [
          TextPart(text: 'I will call a tool.'),
          ToolRequestPart(
            toolRequest: ToolRequest(
              ref: 'call_123',
              name: 'getWeather',
              input: {'location': 'Boston'},
            ),
          ),
        ],
      );
      final result = GenkitConverter.toOpenAIMessage(msg, null);
      expect(result, isA<AssistantMessage>());
      final assistantMsg = result as AssistantMessage;
      expect(assistantMsg.toolCalls, isNotNull);
      expect(assistantMsg.toolCalls!.length, 1);
    });

    test('converts tool message', () {
      final msg = Message(
        role: Role.tool,
        content: [
          ToolResponsePart(
            toolResponse: ToolResponse(
              ref: 'call_123',
              name: 'getWeather',
              output: {'temperature': 72},
            ),
          ),
        ],
      );
      final results = GenkitConverter.toOpenAIMessages([msg], null);
      expect(results.length, 1);
      expect(results[0], isA<ToolMessage>());
      final toolMsg = results[0] as ToolMessage;
      expect(toolMsg.toolCallId, 'call_123');
    });

    test('converts tool message with multiple responses', () {
      final msg = Message(
        role: Role.tool,
        content: [
          ToolResponsePart(
            toolResponse: ToolResponse(
              ref: 'call_123',
              name: 'getWeather',
              output: {'temperature': 72},
            ),
          ),
          ToolResponsePart(
            toolResponse: ToolResponse(
              ref: 'call_456',
              name: 'calculate',
              output: {'result': 42},
            ),
          ),
        ],
      );
      final results = GenkitConverter.toOpenAIMessages([msg], null);
      expect(results.length, 2);
      expect(results[0], isA<ToolMessage>());
      expect(results[1], isA<ToolMessage>());
      final toolMsg1 = results[0] as ToolMessage;
      final toolMsg2 = results[1] as ToolMessage;
      expect(toolMsg1.toolCallId, 'call_123');
      expect(toolMsg2.toolCallId, 'call_456');
    });

    test('throws on tool message with missing ref', () {
      final msg = Message(
        role: Role.tool,
        content: [
          ToolResponsePart(
            toolResponse: ToolResponse(
              name: 'getWeather',
              output: {'temperature': 72},
            ),
          ),
        ],
      );
      expect(
        () => GenkitConverter.toOpenAIMessages([msg], null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('GenkitConverter.toOpenAIContentPart', () {
    test('converts text part', () {
      final part = TextPart(text: 'Hello');
      final result = GenkitConverter.toOpenAIContentPart(part, null);
      expect(result, isA<ContentPart>());
    });

    test('converts media part with URL', () {
      final part = MediaPart(
        media: Media(
          url: 'https://example.com/image.png',
          contentType: 'image/png',
        ),
      );
      final result = GenkitConverter.toOpenAIContentPart(part, 'high');
      expect(result, isA<ContentPart>());
    });

    test('converts media part with base64 data URI', () {
      final part = MediaPart(
        media: Media(
          url: 'data:image/png;base64,iVBORw0KGgoAAAANS',
          contentType: 'image/png',
        ),
      );
      final result = GenkitConverter.toOpenAIContentPart(part, null);
      expect(result, isA<ContentPart>());
    });

    test('converts deserialized Part with media data', () {
      final part = Part.fromJson({
        'media': {
          'url': 'https://example.com/document.pdf',
          'contentType': 'application/pdf',
        },
      });

      final result = GenkitConverter.toOpenAIContentPart(part, null);
      expect(result.toJson(), {
        'type': 'image_url',
        'image_url': {
          'url': 'https://example.com/document.pdf',
          'detail': 'auto',
        },
      });
    });
  });

  group('GenkitConverter.toOpenAITool', () {
    test('converts tool definition', () {
      final tool = ToolDefinition(
        name: 'getWeather',
        description: 'Get weather for a location',
        inputSchema: {
          'type': 'object',
          'properties': {
            'location': {'type': 'string'},
          },
        },
      );
      final result = GenkitConverter.toOpenAITool(tool);
      expect(result.function.name, 'getWeather');
      expect(result.function.description, 'Get weather for a location');
    });
  });

  group('GenkitConverter.fromOpenAIAssistantMessage', () {
    test('handles refusal', () {
      final msg = AssistantMessage(refusal: 'I cannot do that.');
      final result = GenkitConverter.fromOpenAIAssistantMessage(msg);
      expect(result.content.length, 1);
      expect(result.text, '[Refusal] I cannot do that.');
    });

    test('converts JSON content', () {
      final message =
          ChatMessage.assistant(content: '{"name": "Test", "age": 25}')
              as AssistantMessage;
      final genkitMessage = GenkitConverter.fromOpenAIAssistantMessage(message);
      expect(genkitMessage.role, Role.model);
      expect(genkitMessage.text, '{"name": "Test", "age": 25}');
    });

    test('converts message with tool calls', () {
      final message =
          ChatMessage.assistant(
                content: '{"result": "ok"}',
                toolCalls: [
                  ToolCall.functionCall(
                    id: 'call_123',
                    call: FunctionCall(
                      name: 'getWeather',
                      arguments: '{"location": "NYC"}',
                    ),
                  ),
                ],
              )
              as AssistantMessage;
      final genkitMessage = GenkitConverter.fromOpenAIAssistantMessage(message);
      expect(genkitMessage.text, '{"result": "ok"}');
      final toolParts = genkitMessage.content
          .where((p) => p.isToolRequest)
          .toList();
      expect(toolParts.length, 1);
      expect(toolParts.first.toolRequest!.name, 'getWeather');
    });
  });

  group('GenkitConverter.mapFinishReason', () {
    test('maps stop', () {
      expect(GenkitConverter.mapFinishReason('stop'), FinishReason.stop);
    });

    test('maps length', () {
      expect(GenkitConverter.mapFinishReason('length'), FinishReason.length);
    });

    test('maps content_filter', () {
      expect(
        GenkitConverter.mapFinishReason('content_filter'),
        FinishReason.blocked,
      );
    });

    test('maps tool_calls', () {
      expect(GenkitConverter.mapFinishReason('tool_calls'), FinishReason.stop);
    });

    test('maps unknown', () {
      expect(GenkitConverter.mapFinishReason('unknown'), FinishReason.unknown);
      expect(GenkitConverter.mapFinishReason(null), FinishReason.unknown);
    });
  });
}
