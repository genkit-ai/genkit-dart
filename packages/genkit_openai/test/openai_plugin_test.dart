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

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/converters.dart';
import 'package:genkit_openai/src/models.dart';
import 'package:openai_dart/openai_dart.dart'
    show
        ChatCompletionAssistantMessage,
        ChatCompletionMessageContentPart,
        ChatCompletionSystemMessage,
        ChatCompletionToolMessage,
        ChatCompletionUserMessage;
import 'package:test/test.dart';

void main() {
  group('OpenAIOptions', () {
    test('parses temperature', () {
      final options = OpenAIOptions.$schema.parse({'temperature': 0.7});
      expect(options.temperature, 0.7);
    });

    test('parses maxTokens', () {
      final options = OpenAIOptions.$schema.parse({'maxTokens': 100});
      expect(options.maxTokens, 100);
    });

    test('parses jsonMode', () {
      final options = OpenAIOptions.$schema.parse({'jsonMode': true});
      expect(options.jsonMode, true);
    });

    test('parses stop sequences', () {
      final options = OpenAIOptions.$schema.parse({
        'stop': ['stop1', 'stop2'],
      });
      expect(options.stop, ['stop1', 'stop2']);
    });

    test('creates default options', () {
      final options = OpenAIOptions();
      expect(options.temperature, isNull);
      expect(options.maxTokens, isNull);
    });
  });

  group('GenkitConverter.toOpenAIMessage', () {
    test('converts system message', () {
      final msg = Message(
        role: Role.system,
        content: [TextPart(text: 'You are helpful.')],
      );
      final result = GenkitConverter.toOpenAIMessage(msg, null);
      expect(result, isA<ChatCompletionSystemMessage>());
      expect(
        (result as ChatCompletionSystemMessage).content,
        'You are helpful.',
      );
    });

    test('converts user message with text', () {
      final msg = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello!')],
      );
      final result = GenkitConverter.toOpenAIMessage(msg, null);
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
      final result = GenkitConverter.toOpenAIMessage(msg, null);
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
      final results = GenkitConverter.toOpenAIMessages([msg], null);
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
      final results = GenkitConverter.toOpenAIMessages([msg], null);
      expect(results.length, 2);
      expect(results[0], isA<ChatCompletionToolMessage>());
      expect(results[1], isA<ChatCompletionToolMessage>());
      final toolMsg1 = results[0] as ChatCompletionToolMessage;
      final toolMsg2 = results[1] as ChatCompletionToolMessage;
      expect(toolMsg1.toolCallId, 'call_123');
      expect(toolMsg2.toolCallId, 'call_456');
    });
  });

  group('GenkitConverter.toOpenAIContentPart', () {
    test('converts text part', () {
      final part = TextPart(text: 'Hello');
      final result = GenkitConverter.toOpenAIContentPart(part, null);
      expect(result, isA<ChatCompletionMessageContentPart>());
    });

    test('converts media part', () {
      final part = MediaPart(
        media: Media(
          url: 'https://example.com/image.png',
          contentType: 'image/png',
        ),
      );
      final result = GenkitConverter.toOpenAIContentPart(part, 'high');
      expect(result, isA<ChatCompletionMessageContentPart>());
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

  group('Model Info Helpers', () {
    test('defaultModelInfo sets correct supports', () {
      final info = defaultModelInfo('gpt-4o');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], true);
      expect(info.supports?['systemRole'], true);
      expect(info.supports?['media'], true);
    });

    test('oSeriesModelInfo sets correct supports', () {
      final info = oSeriesModelInfo('o1');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], false);
      expect(info.supports?['systemRole'], false);
      expect(info.supports?['media'], true); // O-series models support vision
    });

    test('supportsVision identifies vision models', () {
      // GPT-4o variants
      expect(supportsVision('gpt-4o'), true);
      expect(supportsVision('gpt-4o-mini'), true);
      expect(supportsVision('gpt-4o-2024-05-13'), true);

      // GPT-4 Turbo variants
      expect(supportsVision('gpt-4-turbo'), true);
      expect(supportsVision('gpt-4-1106-preview'), true);
      expect(supportsVision('gpt-4-0125-preview'), true);

      // Explicit vision models
      expect(supportsVision('gpt-4-vision'), true);
      expect(supportsVision('gpt-4-vision-preview'), true);

      // O-series reasoning models
      expect(supportsVision('o1'), true);
      expect(supportsVision('o1-preview'), true);
      expect(supportsVision('o3'), true);
      expect(supportsVision('o3-mini'), true);

      // Future GPT models with "o" suffix
      expect(supportsVision('gpt-5o'), true);
      expect(supportsVision('gpt-5.1o'), true);
      expect(supportsVision('gpt-6o-mini'), true);

      // ChatGPT models
      expect(supportsVision('chatgpt-4o-latest'), true);

      // Non-vision models
      expect(supportsVision('gpt-3.5-turbo'), false);
      expect(supportsVision('gpt-4'), false);
      expect(supportsVision('text-embedding-3-small'), false);
    });

    test('supportsTools identifies models with function calling support', () {
      // Standard GPT models that support tools
      expect(supportsTools('gpt-4'), true);
      expect(supportsTools('gpt-4o'), true);
      expect(supportsTools('gpt-4o-mini'), true);
      expect(supportsTools('gpt-4-turbo'), true);
      expect(supportsTools('gpt-3.5-turbo'), true);
      expect(supportsTools('gpt-5'), true);
      expect(supportsTools('gpt-5.1'), true);

      // ChatGPT-branded models don't support tools
      expect(supportsTools('chatgpt-4o-latest'), false);
      expect(supportsTools('chatgpt-5-latest'), false);

      // Legacy completion models don't support tools
      expect(supportsTools('gpt-3.5-turbo-instruct'), false);
      expect(supportsTools('davinci-002'), false);
      expect(supportsTools('babbage-002'), false);

      // Specialized models don't support tools
      expect(supportsTools('text-embedding-3-small'), false);
      expect(supportsTools('text-embedding-3-large'), false);
      expect(supportsTools('tts-1'), false);
      expect(supportsTools('tts-1-hd'), false);
      expect(supportsTools('whisper-1'), false);
      expect(supportsTools('dall-e-3'), false);
      expect(supportsTools('dall-e-2'), false);
      expect(supportsTools('omni-moderation-latest'), false);
      expect(supportsTools('sora-2'), false);
    });
  });

  group('Plugin Handle', () {
    test('creates plugin instance', () {
      final plugin = openAI(apiKey: 'test-key');
      expect(plugin, isNotNull);
    });

    test('creates model reference', () {
      final ref = openAI.model('gpt-4o');
      expect(ref.name, 'openai/gpt-4o');
    });
  });

  group('CustomModelDefinition', () {
    test('creates with name and info', () {
      final def = CustomModelDefinition(
        name: 'custom-model',
        info: ModelInfo(label: 'Custom Model', supports: {'multiturn': true}),
      );
      expect(def.name, 'custom-model');
      expect(def.info?.label, 'Custom Model');
    });
  });

  group('DeepSeek Model Info', () {
    test('deepSeekModelInfo sets correct supports for chat models', () {
      final info = deepSeekModelInfo('deepseek-chat');
      expect(info.label, 'deepseek-chat');
      expect(info.supports?['multiturn'], true);
      expect(info.supports?['tools'], true);
      expect(info.supports?['systemRole'], true);
      expect(info.supports?['media'], false);
      expect(info.supports?['output'], ['text', 'json']);
    });

    test('deepSeekModelInfo disables tools and systemRole for reasoner', () {
      final info = deepSeekModelInfo('deepseek-reasoner');
      expect(info.label, 'deepseek-reasoner');
      expect(info.supports?['tools'], false);
      expect(info.supports?['systemRole'], false);
    });

    test('deepSeekModelInfo handles future reasoner variants', () {
      final info = deepSeekModelInfo('deepseek-reasoner-v2');
      expect(info.supports?['tools'], false);
      expect(info.supports?['systemRole'], false);
    });
  });

  group('DeepSeek Plugin Handle', () {
    test('creates plugin instance', () {
      final plugin = deepSeek(apiKey: 'test-key');
      expect(plugin, isNotNull);
    });

    test('creates model reference with deepseek prefix', () {
      final ref = deepSeek.model('deepseek-chat');
      expect(ref.name, 'deepseek/deepseek-chat');
    });

    test('creates model reference for deepseek-reasoner', () {
      final ref = deepSeek.model('deepseek-reasoner');
      expect(ref.name, 'deepseek/deepseek-reasoner');
    });

    test('creates model reference for arbitrary model names', () {
      final ref = deepSeek.model('deepseek-v3');
      expect(ref.name, 'deepseek/deepseek-v3');
    });

    test('plugin has correct name and uses modelInfoResolver', () {
      final plugin = deepSeek(apiKey: 'test-key');
      expect(plugin.name, 'deepseek');
    });
  });
}
