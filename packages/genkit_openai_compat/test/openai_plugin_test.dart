// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:genkit/genkit.dart';
import 'package:genkit_openai_compat/genkit_openai_compat.dart';
import 'package:openai_dart/openai_dart.dart'
    show
        ChatCompletionAssistantMessage,
        ChatCompletionMessageContentPart,
        ChatCompletionSystemMessage,
        ChatCompletionToolMessage,
        ChatCompletionUserMessage;
import 'package:test/test.dart';

void main() {
  group('OpenAIOptionsSchema', () {
    test('parses temperature', () {
      final options = OpenAIOptionsSchema.$schema.parse({'temperature': 0.7});
      expect(options.temperature, 0.7);
    });

    test('parses maxTokens', () {
      final options = OpenAIOptionsSchema.$schema.parse({'maxTokens': 100});
      expect(options.maxTokens, 100);
    });

    test('parses jsonMode', () {
      final options = OpenAIOptionsSchema.$schema.parse({'jsonMode': true});
      expect(options.jsonMode, true);
    });

    test('parses stop sequences', () {
      final options = OpenAIOptionsSchema.$schema.parse({'stop': ['stop1', 'stop2']});
      expect(options.stop, ['stop1', 'stop2']);
    });

    test('creates default options', () {
      final options = OpenAIOptionsSchema();
      expect(options.temperature, isNull);
      expect(options.maxTokens, isNull);
    });
  });

  group('toOpenAIMessage', () {
    test('converts system message', () {
      final msg = Message(
        role: Role.system,
        content: [TextPart(text: 'You are helpful.')],
      );
      final result = toOpenAIMessage(msg, null);
      expect(result, isA<ChatCompletionSystemMessage>());
      expect((result as ChatCompletionSystemMessage).content, 'You are helpful.');
    });

    test('converts user message with text', () {
      final msg = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello!')],
      );
      final result = toOpenAIMessage(msg, null);
      expect(result, isA<ChatCompletionUserMessage>());
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
      final result = toOpenAIMessage(msg, null);
      expect(result, isA<ChatCompletionAssistantMessage>());
      final assistantMsg = result as ChatCompletionAssistantMessage;
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
      final results = toOpenAIMessages([msg], null);
      expect(results.length, 1);
      expect(results[0], isA<ChatCompletionToolMessage>());
      final toolMsg = results[0] as ChatCompletionToolMessage;
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
      final results = toOpenAIMessages([msg], null);
      expect(results.length, 2);
      expect(results[0], isA<ChatCompletionToolMessage>());
      expect(results[1], isA<ChatCompletionToolMessage>());
      final toolMsg1 = results[0] as ChatCompletionToolMessage;
      final toolMsg2 = results[1] as ChatCompletionToolMessage;
      expect(toolMsg1.toolCallId, 'call_123');
      expect(toolMsg2.toolCallId, 'call_456');
    });
  });

  group('toOpenAIContentPart', () {
    test('converts text part', () {
      final part = TextPart(text: 'Hello');
      final result = toOpenAIContentPart(part, null);
      expect(result, isA<ChatCompletionMessageContentPart>());
    });

    test('converts media part', () {
      final part = MediaPart(
        media: Media(
          url: 'https://example.com/image.png',
          contentType: 'image/png',
        ),
      );
      final result = toOpenAIContentPart(part, 'high');
      expect(result, isA<ChatCompletionMessageContentPart>());
    });
  });

  group('toOpenAITool', () {
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
      final result = toOpenAITool(tool);
      expect(result.function.name, 'getWeather');
      expect(result.function.description, 'Get weather for a location');
    });
  });

  group('mapFinishReason', () {
    test('maps stop', () {
      expect(mapFinishReason('stop'), FinishReason.stop);
    });

    test('maps length', () {
      expect(mapFinishReason('length'), FinishReason.length);
    });

    test('maps content_filter', () {
      expect(mapFinishReason('content_filter'), FinishReason.blocked);
    });

    test('maps tool_calls', () {
      expect(mapFinishReason('tool_calls'), FinishReason.stop);
    });

    test('maps unknown', () {
      expect(mapFinishReason('unknown'), FinishReason.unknown);
      expect(mapFinishReason(null), FinishReason.unknown);
    });
  });

  group('Model Info Helpers', () {
    test('defaultModelInfo sets correct supports', () {
      final info = defaultModelInfo('gpt-4o');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], true);
      expect(info.supports?['systemRole'], true);
      expect(info.supports?['media'], true);
    });

    test('o1ModelInfo sets correct supports', () {
      final info = o1ModelInfo();
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], false);
      expect(info.supports?['systemRole'], false);
      expect(info.supports?['media'], false);
    });

    test('supportsVision identifies vision models', () {
      expect(supportsVision('gpt-4o'), true);
      expect(supportsVision('gpt-4-turbo'), true);
      expect(supportsVision('gpt-4-vision'), true);
      expect(supportsVision('gpt-3.5-turbo'), false);
    });
  });

  group('Plugin Handle', () {
    test('creates plugin instance', () {
      final plugin = openAI(apiKey: 'test-key');
      expect(plugin, isNotNull);
    });

    test('creates model reference', () {
      final ref = openAI.model('gpt-4o');
      expect(ref.name, 'openai_compat/gpt-4o');
    });

    test('pre-defined model getters work', () {
      expect(openAI.gpt4o.name, 'openai_compat/gpt-4o');
      expect(openAI.gpt4oMini.name, 'openai_compat/gpt-4o-mini');
      expect(openAI.gpt4Turbo.name, 'openai_compat/gpt-4-turbo');
      expect(openAI.gpt35Turbo.name, 'openai_compat/gpt-3.5-turbo');
    });
  });

  group('CustomModelDefinition', () {
    test('creates with name and info', () {
      final def = CustomModelDefinition(
        name: 'custom-model',
        info: ModelInfo(
          label: 'Custom Model',
          supports: {'multiturn': true},
        ),
      );
      expect(def.name, 'custom-model');
      expect(def.info?.label, 'Custom Model');
    });
  });
}
