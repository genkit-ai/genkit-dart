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
import 'package:openai_dart/openai_dart.dart';

/// Convert Genkit messages to OpenAI format
List<ChatCompletionMessage> toOpenAIMessages(
  List<Message> messages,
  String? visualDetailLevel,
) {
  return messages.map((m) => toOpenAIMessage(m, visualDetailLevel)).toList();
}

/// Convert a single Genkit message to OpenAI format
ChatCompletionMessage toOpenAIMessage(Message msg, String? visualDetailLevel) {
  if (msg.role == Role.system) {
    return ChatCompletionMessage.system(content: msg.text);
  }
  if (msg.role == Role.user) {
    final parts =
        msg.content.map((p) => toOpenAIContentPart(p, visualDetailLevel)).toList();
    return ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.parts(parts),
    );
  }
  if (msg.role == Role.model) {
    final toolCalls = _extractToolCalls(msg.content);
    return ChatCompletionMessage.assistant(
      content: msg.text,
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
    );
  }
  if (msg.role == Role.tool) {
    final toolResponse = msg.content
        .where((p) => p.isToolResponse)
        .map((p) => p.toolResponse!)
        .firstOrNull;
    if (toolResponse == null) {
      throw ArgumentError('Tool message must contain a ToolResponsePart');
    }
    return ChatCompletionMessage.tool(
      toolCallId: toolResponse.ref ?? '',
      content: jsonEncode(toolResponse.output),
    );
  }
  throw UnimplementedError('Unsupported role: ${msg.role}');
}

/// Convert Genkit Part to OpenAI content part
ChatCompletionMessageContentPart toOpenAIContentPart(
  Part part,
  String? visualDetailLevel,
) {
  if (part.isText) {
    return ChatCompletionMessageContentPart.text(text: part.text!);
  }
  if (part.isMedia) {
    final media = (part as MediaPart).media;
    return ChatCompletionMessageContentPart.image(
      imageUrl: ChatCompletionMessageImageUrl(
        url: media.url,
        detail: _mapVisualDetailLevel(visualDetailLevel),
      ),
    );
  }
  throw UnimplementedError('Unsupported part type: $part');
}

/// Map visual detail level string to enum
ChatCompletionMessageImageDetail _mapVisualDetailLevel(String? level) {
  return switch (level) {
    'low' => ChatCompletionMessageImageDetail.low,
    'high' => ChatCompletionMessageImageDetail.high,
    _ => ChatCompletionMessageImageDetail.auto,
  };
}

/// Extract tool calls from message content
List<ChatCompletionMessageToolCall> _extractToolCalls(List<Part> content) {
  final toolCalls = <ChatCompletionMessageToolCall>[];
  for (final part in content) {
    if (part.isToolRequest) {
      final toolRequest = part.toolRequest!;
      toolCalls.add(
        ChatCompletionMessageToolCall(
          id: toolRequest.ref ?? '',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
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
ChatCompletionTool toOpenAITool(ToolDefinition tool) {
  return ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: tool.name,
      description: tool.description,
      parameters: tool.inputSchema,
    ),
  );
}

/// Convert OpenAI assistant message to Genkit format.
///
/// This is used for converting response messages from the OpenAI API.
/// For responses, we always get a ChatCompletionAssistantMessage with
/// optional text content and/or tool calls.
Message fromOpenAIAssistantMessage(ChatCompletionAssistantMessage msg) {
  final parts = <Part>[];

  // Handle text content (always a String? for assistant messages)
  if (msg.content != null && msg.content!.isNotEmpty) {
    parts.add(TextPart.from(text: msg.content!));
  }

  // Handle tool calls
  if (msg.toolCalls != null) {
    for (final toolCall in msg.toolCalls!) {
      parts.add(
        ToolRequestPart.from(
          toolRequest: ToolRequest.from(
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

  return Message.from(
    role: Role.model,
    content: parts,
  );
}

/// Map OpenAI finish reason to Genkit FinishReason
FinishReason mapFinishReason(String? reason) {
  return switch (reason) {
    'stop' => FinishReason.stop,
    'length' => FinishReason.length,
    'content_filter' => FinishReason.blocked,
    'tool_calls' => FinishReason.stop,
    _ => FinishReason.unknown,
  };
}
