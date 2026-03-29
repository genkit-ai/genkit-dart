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
import 'package:openai_dart/openai_dart.dart' as sdk;

/// Converter class for transforming between Genkit and OpenAI formats
abstract final class GenkitConverter {
  /// Convert Genkit messages to OpenAI format
  static List<sdk.ChatMessage> toOpenAIMessages(
    List<Message> messages,
    String? visualDetailLevel,
  ) {
    final result = <sdk.ChatMessage>[];
    for (final message in messages) {
      // Tool messages may contain multiple responses and need to be expanded
      if (message.role == Role.tool) {
        final toolResponses = message.content
            .where((p) => p.isToolResponse)
            .map((p) => p.toolResponse!)
            .toList();

        if (toolResponses.isEmpty) {
          throw ArgumentError(
            'Tool message must contain at least one ToolResponsePart',
          );
        }

        // Create a separate message for each tool response
        for (final toolResponse in toolResponses) {
          final ref = toolResponse.ref;
          if (ref == null || ref.isEmpty) {
            throw ArgumentError(
              'ToolResponse.ref must be a non-empty string for tool messages',
            );
          }
          result.add(
            sdk.ChatMessage.tool(
              toolCallId: ref,
              content: jsonEncode(toolResponse.output),
            ),
          );
        }
      } else {
        result.add(toOpenAIMessage(message, visualDetailLevel));
      }
    }
    return result;
  }

  /// Convert a single Genkit message to OpenAI format
  /// Note: Tool messages are handled separately in toOpenAIMessages()
  static sdk.ChatMessage toOpenAIMessage(
    Message msg,
    String? visualDetailLevel,
  ) {
    if (msg.role == Role.system) {
      return sdk.ChatMessage.system(msg.text);
    }
    if (msg.role == Role.user) {
      final parts = msg.content
          .map((p) => toOpenAIContentPart(p, visualDetailLevel))
          .toList();
      return sdk.ChatMessage.user(parts);
    }
    if (msg.role == Role.model) {
      final toolCalls = _extractToolCalls(msg.content);
      return sdk.ChatMessage.assistant(
        content: msg.text,
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      );
    }
    if (msg.role == Role.tool) {
      throw ArgumentError(
        'Tool messages should be handled by toOpenAIMessages(), not toOpenAIMessage()',
      );
    }
    throw UnimplementedError('Unsupported role: ${msg.role}');
  }

  /// Convert Genkit Part to OpenAI content part
  static sdk.ContentPart toOpenAIContentPart(
    Part part,
    String? visualDetailLevel,
  ) {
    if (part.isText) {
      return sdk.ContentPart.text(part.text!);
    }
    if (part.isMedia) {
      final media = part.mediaPart!.media;
      if (media.url.startsWith('data:')) {
        // Parse data URI: data:<mediaType>;base64,<data>
        final commaIdx = media.url.indexOf(',');
        final base64Data = media.url.substring(commaIdx + 1);
        final mimeType = media.contentType ?? 'image/png';
        return sdk.ContentPart.imageBase64(
          data: base64Data,
          mediaType: mimeType,
          detail: _mapVisualDetailLevel(visualDetailLevel),
        );
      }
      return sdk.ContentPart.imageUrl(
        media.url,
        detail: _mapVisualDetailLevel(visualDetailLevel),
      );
    }
    throw UnimplementedError('Unsupported part type: $part');
  }

  /// Map visual detail level string to enum
  static sdk.ImageDetail _mapVisualDetailLevel(String? level) {
    return switch (level) {
      'low' => sdk.ImageDetail.low,
      'high' => sdk.ImageDetail.high,
      _ => sdk.ImageDetail.auto,
    };
  }

  /// Extract tool calls from message content
  static List<sdk.ToolCall> _extractToolCalls(List<Part> content) {
    final toolCalls = <sdk.ToolCall>[];
    for (final part in content) {
      if (part.isToolRequest) {
        final toolRequest = part.toolRequest!;
        final ref = toolRequest.ref;
        if (ref == null || ref.isEmpty) {
          throw ArgumentError(
            'ToolRequest.ref must be a non-empty string when converting to OpenAI tool calls',
          );
        }
        toolCalls.add(
          sdk.ToolCall.functionCall(
            id: ref,
            call: sdk.FunctionCall(
              name: toolRequest.name,
              arguments: jsonEncode(toolRequest.input ?? {}),
            ),
          ),
        );
      }
    }
    return toolCalls;
  }

  /// Convert Genkit tool to OpenAI format
  static sdk.Tool toOpenAITool(ToolDefinition tool) {
    // OpenAI requires parameters to be a valid JSON Schema object
    // If no schema is provided, use an empty object schema
    var parameters = tool.inputSchema;

    if (parameters == null) {
      parameters = {'type': 'object', 'properties': {}};
    } else if (!parameters.containsKey('type')) {
      // Ensure the schema has a type field
      parameters = {'type': 'object', ...parameters};
    }

    return sdk.Tool.function(
      name: tool.name,
      description: tool.description,
      parameters: parameters,
    );
  }

  /// Convert OpenAI assistant message to Genkit format.
  ///
  /// This is used for converting response messages from the OpenAI API.
  /// For responses, we always get an [sdk.AssistantMessage] with
  /// optional text content, refusal, and/or tool calls.
  static Message fromOpenAIAssistantMessage(sdk.AssistantMessage msg) {
    final parts = <Part>[];

    // Handle refusal
    if (msg.refusal != null && msg.refusal!.isNotEmpty) {
      parts.add(TextPart(text: '[Refusal] ${msg.refusal}'));
    }

    // Handle text content (always a String? for assistant messages)
    if (msg.content != null && msg.content!.isNotEmpty) {
      parts.add(TextPart(text: msg.content!));
    }

    // Handle tool calls
    if (msg.toolCalls != null) {
      for (final toolCall in msg.toolCalls!) {
        parts.add(
          ToolRequestPart(
            toolRequest: ToolRequest(
              ref: toolCall.id,
              name: toolCall.function.name,
              input: toolCall.function.arguments.isNotEmpty
                  ? jsonDecode(toolCall.function.arguments)
                        as Map<String, dynamic>?
                  : null,
            ),
          ),
        );
      }
    }

    return Message(role: Role.model, content: parts);
  }

  /// Map OpenAI finish reason to Genkit FinishReason
  static FinishReason mapFinishReason(String? reason) {
    return switch (reason) {
      'stop' => FinishReason.stop,
      'length' => FinishReason.length,
      'content_filter' => FinishReason.blocked,
      'tool_calls' => FinishReason.stop,
      _ => FinishReason.unknown,
    };
  }
}
