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
  final result = <ChatCompletionMessage>[];
  for (final message in messages) {
    // Tool messages may contain multiple responses and need to be expanded
    if (message.role == Role.tool) {
      final toolResponses = message.content
          .where((p) => p.isToolResponse)
          .map((p) => p.toolResponse!)
          .toList();
      
      if (toolResponses.isEmpty) {
        throw ArgumentError('Tool message must contain at least one ToolResponsePart');
      }
      
      // Create a separate message for each tool response
      for (final toolResponse in toolResponses) {
        result.add(
          ChatCompletionMessage.tool(
            toolCallId: toolResponse.ref ?? '',
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
    throw ArgumentError(
      'Tool messages should be handled by toOpenAIMessages(), not toOpenAIMessage()',
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
  // OpenAI requires parameters to be a valid JSON Schema object
  // If no schema is provided, use an empty object schema
  var parameters = tool.inputSchema;
  
  if (parameters == null) {
    parameters = {
      'type': 'object',
      'properties': {},
    };
  } else if (!parameters.containsKey('type')) {
    // Ensure the schema has a type field
    parameters = {
      'type': 'object',
      ...parameters,
    };
  }
  
  return ChatCompletionTool(
    type: ChatCompletionToolType.function,
    function: FunctionObject(
      name: tool.name,
      description: tool.description,
      parameters: parameters,
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

  return Message(
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
