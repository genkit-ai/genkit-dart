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

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as sdk;
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:test/test.dart';

void main() {
  group('toAnthropicMessage', () {
    test('should map user TextPart correctly', () {
      final input = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello')],
      );
      final result = toAnthropicMessage(input);
      expect(result.role, sdk.MessageRole.user);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.TextInputBlock>());
      expect((blocks.first as sdk.TextInputBlock).text, 'Hello');
    });

    test('should map assistant message correctly', () {
      final input = Message(
        role: Role.model,
        content: [TextPart(text: 'Hi there')],
      );
      final result = toAnthropicMessage(input);
      expect(result.role, sdk.MessageRole.assistant);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.TextInputBlock>());
    });

    test('should map tool request correctly', () {
      final input = Message(
        role: Role.model,
        content: [
          ToolRequestPart(
            toolRequest: ToolRequest(
              ref: 'call_123',
              name: 'getWeather',
              input: {'location': 'Boston'},
            ),
          ),
        ],
      );
      final result = toAnthropicMessage(input);
      expect(result.role, sdk.MessageRole.assistant);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.ToolUseInputBlock>());
      final toolUse = blocks.first as sdk.ToolUseInputBlock;
      expect(toolUse.id, 'call_123');
      expect(toolUse.name, 'getWeather');
    });

    test('should map tool response correctly', () {
      final input = Message(
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
      final result = toAnthropicMessage(input);
      expect(result.role, sdk.MessageRole.user);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.ToolResultInputBlock>());
      final toolResult = blocks.first as sdk.ToolResultInputBlock;
      expect(toolResult.toolUseId, 'call_123');
    });

    test('should map media part with URL', () {
      final input = Message(
        role: Role.user,
        content: [
          MediaPart(
            media: Media(
              url: 'https://example.com/image.png',
              contentType: 'image/png',
            ),
          ),
        ],
      );
      final result = toAnthropicMessage(input);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.ImageInputBlock>());
    });

    test('should map media part with base64 data URI', () {
      final input = Message(
        role: Role.user,
        content: [
          MediaPart(
            media: Media(
              url: 'data:image/jpeg;base64,/9j/4AAQSkZJRg==',
              contentType: 'image/jpeg',
            ),
          ),
        ],
      );
      final result = toAnthropicMessage(input);
      final blocks = result.blocks;
      expect(blocks.length, 1);
      expect(blocks.first, isA<sdk.ImageInputBlock>());
    });

    test('should filter ReasoningPart from input', () {
      final input = Message(
        role: Role.user,
        content: [
          TextPart(text: 'Hello'),
          ReasoningPart(reasoning: 'thinking...'),
        ],
      );
      final result = toAnthropicMessage(input);
      expect(result.blocks.length, 1); // Should only have TextPart
    });
  });

  group('fromAnthropicMessage', () {
    test('should map TextBlock to TextPart', () {
      final input = sdk.Message(
        id: 'msg_123',
        role: sdk.MessageRole.assistant,
        content: [sdk.TextBlock(text: 'Hello')],
        model: 'claude-3-5-sonnet',
        usage: sdk.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 1);
      expect(result.text, 'Hello');
    });

    test('should map ToolUseBlock to ToolRequestPart', () {
      final input = sdk.Message(
        id: 'msg_123',
        role: sdk.MessageRole.assistant,
        content: [
          sdk.ToolUseBlock(
            id: 'call_123',
            name: 'getWeather',
            input: {'location': 'Boston'},
          ),
        ],
        model: 'claude-3-5-sonnet',
        usage: sdk.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 1);
      final part = result.content.first;
      expect(part.isToolRequest, true);
      expect(part.toolRequest!.name, 'getWeather');
      expect(part.toolRequest!.ref, 'call_123');
    });

    test('should map ThinkingBlock to ReasoningPart with signature', () {
      final input = sdk.Message(
        id: 'msg_123',
        role: sdk.MessageRole.assistant,
        content: [
          sdk.ThinkingBlock(thinking: 'Hmm', signature: 'sig_123'),
          sdk.TextBlock(text: 'Hello'),
        ],
        model: 'claude-3-5-sonnet',
        usage: sdk.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 2);

      // Use JSON check for ReasoningPart due to schemantic type erasure in generic lists
      final reasoningPart = result.content[0].toJson();
      expect(reasoningPart['reasoning'], 'Hmm');
      expect((reasoningPart['metadata'] as Map?)?['signature'], 'sig_123');

      final textPart = result.content[1].toJson();
      expect(textPart['text'], 'Hello');
    });

    test('should map return_output tool to TextPart with JSON', () {
      final input = sdk.Message(
        id: 'msg_123',
        role: sdk.MessageRole.assistant,
        content: [
          sdk.ToolUseBlock(
            id: 'call_123',
            name: 'return_output',
            input: {'name': 'John', 'age': 30},
          ),
        ],
        model: 'claude-3-5-sonnet',
        usage: sdk.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 1);
      final parsed = jsonDecode(result.text) as Map<String, dynamic>;
      expect(parsed['name'], 'John');
      expect(parsed['age'], 30);
    });

    test('should filter out empty/unknown blocks', () {
      final input = sdk.Message(
        id: 'msg_123',
        role: sdk.MessageRole.assistant,
        content: [
          sdk.TextBlock(text: ''),
          sdk.TextBlock(text: 'Hello'),
        ],
        model: 'claude-3-5-sonnet',
        usage: sdk.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 1);
      expect(result.text, 'Hello');
    });
  });

  group('toAnthropicTool', () {
    test('converts tool with full schema', () {
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
      final result = toAnthropicTool(tool);
      expect(result, isA<sdk.CustomToolDefinition>());
      final custom = result as sdk.CustomToolDefinition;
      expect(custom.tool.name, 'getWeather');
      expect(custom.tool.description, 'Get weather for a location');
    });

    test('adds type:object when missing', () {
      final tool = ToolDefinition(
        name: 'testTool',
        description: 'A test tool',
        inputSchema: {
          'properties': {
            'param': {'type': 'string'},
          },
        },
      );
      final result = toAnthropicTool(tool);
      final custom = result as sdk.CustomToolDefinition;
      final schema = custom.tool.inputSchema.toJson();
      expect(schema['type'], 'object');
    });

    test('handles null inputSchema', () {
      final tool = ToolDefinition(
        name: 'simpleTool',
        description: 'A simple tool',
      );
      final result = toAnthropicTool(tool);
      final custom = result as sdk.CustomToolDefinition;
      final schema = custom.tool.inputSchema.toJson();
      expect(schema['type'], 'object');
    });
  });

  group('convertSystemMessage', () {
    test('converts normal system message', () {
      final msg = Message(
        role: Role.system,
        content: [TextPart(text: 'You are helpful.')],
      );
      final result = convertSystemMessage(msg);
      expect(result, isNotNull);
      expect(result, isA<sdk.TextSystemPrompt>());
      expect((result! as sdk.TextSystemPrompt).text, 'You are helpful.');
    });

    test('returns null for empty system message', () {
      final msg = Message(role: Role.system, content: []);
      final result = convertSystemMessage(msg);
      expect(result, isNull);
    });
  });

  group('mapFinishReason', () {
    test('maps endTurn to stop', () {
      expect(mapFinishReason(sdk.StopReason.endTurn), FinishReason.stop);
    });

    test('maps maxTokens to length', () {
      expect(mapFinishReason(sdk.StopReason.maxTokens), FinishReason.length);
    });

    test('maps stopSequence to stop', () {
      expect(mapFinishReason(sdk.StopReason.stopSequence), FinishReason.stop);
    });

    test('maps toolUse to stop', () {
      expect(mapFinishReason(sdk.StopReason.toolUse), FinishReason.stop);
    });

    test('maps pauseTurn to stop', () {
      expect(mapFinishReason(sdk.StopReason.pauseTurn), FinishReason.stop);
    });

    test('maps compaction to stop', () {
      expect(mapFinishReason(sdk.StopReason.compaction), FinishReason.stop);
    });

    test('maps modelContextWindowExceeded to length', () {
      expect(
        mapFinishReason(sdk.StopReason.modelContextWindowExceeded),
        FinishReason.length,
      );
    });

    test('maps refusal to blocked', () {
      expect(mapFinishReason(sdk.StopReason.refusal), FinishReason.blocked);
    });

    test('maps null to unknown', () {
      expect(mapFinishReason(null), FinishReason.unknown);
    });
  });

  group('mapUsage', () {
    test('maps normal usage', () {
      final usage = sdk.Usage(inputTokens: 100, outputTokens: 50);
      final result = mapUsage(usage);
      expect(result.inputTokens, 100.0);
      expect(result.outputTokens, 50.0);
      expect(result.totalTokens, 150.0);
    });

    test('maps null usage to zeros', () {
      final result = mapUsage(null);
      expect(result.inputTokens, 0);
      expect(result.outputTokens, 0);
      expect(result.totalTokens, 0);
    });
  });
}
