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
import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

import 'model.dart';

const _defaultMaxTokens = 4096;
const _defaultStructuredOutputToolName = 'return_output';
const _minimumThinkingBudgetTokens = 1024;

typedef AnthropicMediaConverter =
    List<sdk.InputContentBlock> Function(String url, String? contentType);

typedef AnthropicToolOutputFormatter = String Function(dynamic output);

/// Converts a Genkit model request to an Anthropic message request.
sdk.MessageCreateRequest toAnthropicCreateRequest(
  ModelRequest req,
  String modelName,
  AnthropicOptions options, {
  String structuredOutputToolName = _defaultStructuredOutputToolName,
  AnthropicMediaConverter mediaConverter = convertAnthropicMedia,
  AnthropicToolOutputFormatter toolOutputFormatter =
      defaultAnthropicToolOutputFormatter,
}) {
  final systemMessage = req.messages
      .where((message) => message.role == Role.system)
      .firstOrNull;

  final system = systemMessage != null
      ? convertSystemMessage(systemMessage)
      : null;

  final messages = req.messages
      .where((message) => message.role != Role.system)
      .map(
        (message) => toAnthropicMessage(
          message,
          mediaConverter: mediaConverter,
          toolOutputFormatter: toolOutputFormatter,
        ),
      )
      .toList();

  final tools =
      req.tools?.map(toAnthropicTool).toList() ?? <sdk.ToolDefinition>[];

  sdk.ToolChoice? toolChoice;

  if (req.output?.schema != null) {
    final schema = Map<String, dynamic>.from(req.output!.schema!);
    if (!schema.containsKey('type')) {
      schema['type'] = 'object';
    }
    tools.add(
      sdk.ToolDefinition.custom(
        sdk.Tool(
          name: structuredOutputToolName,
          description: 'Return the structured output.',
          inputSchema: sdk.InputSchema.fromJson(schema),
        ),
      ),
    );
    toolChoice = sdk.ToolChoice.tool(structuredOutputToolName);
  }

  if (req.toolChoice != null) {
    toolChoice = switch (req.toolChoice) {
      'auto' => sdk.ToolChoice.auto(),
      'any' => sdk.ToolChoice.any(),
      'none' => sdk.ToolChoice.none(),
      final name => sdk.ToolChoice.tool(name!),
    };
  }

  return sdk.MessageCreateRequest(
    model: modelName,
    messages: messages,
    system: system,
    maxTokens: options.maxTokens ?? _defaultMaxTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    stopSequences: options.stopSequences,
    tools: tools.isNotEmpty ? tools : null,
    toolChoice: toolChoice,
    thinking: mapThinkingConfig(options.thinking),
  );
}

/// Converts a Genkit system [Message] to an Anthropic [sdk.SystemPrompt].
sdk.SystemPrompt? convertSystemMessage(Message message) {
  final parts = <String>[];
  for (final part in message.content) {
    if (part.isText) {
      parts.add(part.text!);
    }
  }

  final text = parts.join('\n');
  if (text.isEmpty) {
    return null;
  }
  return sdk.SystemPrompt.text(text);
}

/// Converts a Genkit [Message] to an Anthropic [sdk.InputMessage].
sdk.InputMessage toAnthropicMessage(
  Message message, {
  AnthropicMediaConverter mediaConverter = convertAnthropicMedia,
  AnthropicToolOutputFormatter toolOutputFormatter =
      defaultAnthropicToolOutputFormatter,
}) {
  final isUser = message.role == Role.user || message.role == Role.tool;

  final blocks = message.content.expand<sdk.InputContentBlock>((part) {
    if (part.isText) {
      return [sdk.InputContentBlock.text(part.text!)];
    }
    if (part.isToolRequest) {
      final request = part.toolRequest!;
      return [
        sdk.InputContentBlock.toolUse(
          id: _requireToolRef(request.ref, 'ToolRequest.ref'),
          name: request.name,
          input: request.input ?? {},
        ),
      ];
    }
    if (part.isToolResponse) {
      final response = part.toolResponse!;
      return [
        sdk.InputContentBlock.toolResult(
          toolUseId: _requireToolRef(response.ref, 'ToolResponse.ref'),
          content: [
            sdk.ToolResultContent.text(toolOutputFormatter(response.output)),
          ],
        ),
      ];
    }
    if (part.isMedia) {
      final media = part.media!;
      return mediaConverter(media.url, media.contentType);
    }
    return <sdk.InputContentBlock>[];
  }).toList();

  return isUser
      ? sdk.InputMessage.userBlocks(blocks)
      : sdk.InputMessage.assistantBlocks(blocks);
}

String _requireToolRef(String? ref, String fieldName) {
  if (ref == null || ref.isEmpty) {
    throw GenkitException(
      '$fieldName must be a non-empty string when converting Anthropic tool '
      'messages.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return ref;
}

/// Converts Genkit media to Anthropic media blocks for the Anthropic API.
List<sdk.InputContentBlock> convertAnthropicMedia(
  String url,
  String? contentType,
) {
  if (url.startsWith('data:')) {
    final commaIndex = url.indexOf(',');
    final base64Data = url.substring(commaIndex + 1);
    final mimeType = contentType ?? 'image/png';
    return [
      sdk.InputContentBlock.image(
        sdk.ImageSource.base64(
          data: base64Data,
          mediaType: mapImageMediaType(mimeType),
        ),
      ),
    ];
  }

  return [sdk.InputContentBlock.image(sdk.ImageSource.url(url))];
}

/// Converts a Genkit tool response output to Anthropic text content.
String defaultAnthropicToolOutputFormatter(dynamic output) {
  return jsonEncode(output);
}

/// Maps a media MIME type to an Anthropic image media type.
sdk.ImageMediaType mapImageMediaType(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' || 'image/jpg' => sdk.ImageMediaType.jpeg,
    'image/gif' => sdk.ImageMediaType.gif,
    'image/webp' => sdk.ImageMediaType.webp,
    _ => sdk.ImageMediaType.png,
  };
}

/// Converts a Genkit [ToolDefinition] to an Anthropic [sdk.ToolDefinition].
sdk.ToolDefinition toAnthropicTool(ToolDefinition tool) {
  final rawSchema = Map<String, Object?>.from(tool.inputSchema ?? const {});
  final schema = Map<String, dynamic>.from(rawSchema.flatten());
  if (!schema.containsKey('type')) {
    schema['type'] = 'object';
  }

  return sdk.ToolDefinition.custom(
    sdk.Tool(
      name: tool.name,
      description: tool.description,
      inputSchema: sdk.InputSchema.fromJson(schema),
    ),
  );
}

/// Converts an Anthropic [sdk.Message] to a Genkit [Message].
Message fromAnthropicMessage(
  sdk.Message message, {
  String structuredOutputToolName = _defaultStructuredOutputToolName,
}) {
  final content = message.content
      .map(
        (block) => switch (block) {
          sdk.TextBlock(:final text) => TextPart(text: text),
          sdk.ToolUseBlock(:final id, :final name, :final input) =>
            name == structuredOutputToolName
                ? TextPart(text: jsonEncode(_extractOutput(input)))
                : ToolRequestPart(
                        toolRequest: ToolRequest(
                          ref: id,
                          name: name,
                          input: input,
                        ),
                      )
                      as Part,
          sdk.ThinkingBlock(:final thinking, :final signature) => ReasoningPart(
            reasoning: thinking,
            metadata: {'signature': signature},
          ),
          _ => TextPart(text: ''),
        },
      )
      .where((part) => part is! TextPart || part.text.isNotEmpty)
      .toList();

  return Message(role: Role.model, content: content);
}

Map<String, dynamic> _extractOutput(Map<String, dynamic> input) {
  if (input.keys.length == 1) {
    if (input.containsKey('output') && input['output'] is Map) {
      return input['output'] as Map<String, dynamic>;
    }
    if (input.containsKey('\$output') && input['\$output'] is Map) {
      return input['\$output'] as Map<String, dynamic>;
    }
  }

  return input;
}

/// Maps Anthropic thinking options to SDK thinking config.
sdk.ThinkingConfig? mapThinkingConfig(ThinkingConfig? config) {
  if (config == null) {
    return null;
  }

  return switch (config.type ?? 'enabled') {
    'disabled' => sdk.ThinkingConfig.disabled(),
    'adaptive' => sdk.ThinkingConfig.adaptive(),
    _ => sdk.ThinkingConfig.enabled(
      budgetTokens: config.budgetTokens ?? _minimumThinkingBudgetTokens,
    ),
  };
}

/// Emits streaming chunks for content deltas and throws on error events.
void handleAnthropicStreamEvent(
  sdk.MessageStreamEvent event,
  void Function(ModelResponseChunk chunk) sendChunk,
) {
  switch (event) {
    case sdk.ContentBlockDeltaEvent(:final index, :final delta):
      switch (delta) {
        case sdk.TextDelta(:final text):
          sendChunk(
            ModelResponseChunk(
              index: index,
              content: [TextPart(text: text)],
            ),
          );
        case sdk.ThinkingDelta(:final thinking):
          sendChunk(
            ModelResponseChunk(
              index: index,
              content: [ReasoningPart(reasoning: thinking)],
            ),
          );
        case sdk.InputJsonDelta():
        case sdk.SignatureDelta():
        case sdk.CitationsDelta():
        case sdk.CompactionDelta():
        case sdk.UnknownContentBlockDelta():
          break;
      }
    case sdk.ErrorEvent(:final message):
      throw GenkitException(
        'Anthropic stream error: $message',
        status: StatusCodes.INTERNAL,
      );
    default:
      break;
  }
}

/// Maps an Anthropic [sdk.StopReason] to a Genkit [FinishReason].
FinishReason mapFinishReason(sdk.StopReason? reason) {
  return switch (reason) {
    sdk.StopReason.endTurn => FinishReason.stop,
    sdk.StopReason.maxTokens => FinishReason.length,
    sdk.StopReason.stopSequence => FinishReason.stop,
    sdk.StopReason.toolUse => FinishReason.stop,
    sdk.StopReason.pauseTurn => FinishReason.stop,
    sdk.StopReason.compaction => FinishReason.stop,
    sdk.StopReason.modelContextWindowExceeded => FinishReason.length,
    sdk.StopReason.refusal => FinishReason.blocked,
    null => FinishReason.unknown,
  };
}

/// Maps Anthropic [sdk.Usage] to Genkit [GenerationUsage].
GenerationUsage mapUsage(sdk.Usage? usage) {
  if (usage == null) {
    return GenerationUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0);
  }

  return GenerationUsage(
    inputTokens: usage.inputTokens.toDouble(),
    outputTokens: usage.outputTokens.toDouble(),
    totalTokens: (usage.inputTokens + usage.outputTokens).toDouble(),
  );
}
