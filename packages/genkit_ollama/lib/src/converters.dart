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
import 'package:ollama_dart/ollama_dart.dart' as sdk;

import 'chat.dart';

/// Converts between Genkit and `ollama_dart` request/response shapes.
abstract final class GenkitConverter {
  /// Converts Genkit [messages] to Ollama chat messages.
  ///
  /// A single Genkit tool message may carry several tool responses; each is
  /// expanded into its own Ollama `tool` message.
  static List<sdk.ChatMessage> toOllamaMessages(List<Message> messages) {
    final result = <sdk.ChatMessage>[];
    for (final message in messages) {
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
        for (final toolResponse in toolResponses) {
          result.add(
            sdk.ChatMessage.tool(_encodeToolOutput(toolResponse.output)),
          );
        }
      } else {
        result.add(toOllamaMessage(message));
      }
    }
    return result;
  }

  /// Converts a single non-tool Genkit [msg] to an Ollama chat message.
  static sdk.ChatMessage toOllamaMessage(Message msg) {
    if (msg.role == Role.system) {
      return sdk.ChatMessage.system(msg.text);
    }
    if (msg.role == Role.user) {
      final images = <String>[];
      final textBuffer = StringBuffer();
      for (final part in msg.content) {
        if (part.isText) {
          textBuffer.write(part.text);
        } else if (part.isMedia) {
          images.add(_toOllamaImage(part.media!));
        } else {
          throw UnimplementedError(
            'Unsupported part type in user message: $part',
          );
        }
      }
      return sdk.ChatMessage.user(
        textBuffer.toString(),
        images: images.isNotEmpty ? images : null,
      );
    }
    if (msg.role == Role.model) {
      final toolCalls = _extractToolCalls(msg.content);
      final textBuffer = StringBuffer();
      for (final part in msg.content) {
        if (part.isText) textBuffer.write(part.text);
      }
      return sdk.ChatMessage.assistant(
        textBuffer.toString(),
        toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
      );
    }
    if (msg.role == Role.tool) {
      throw ArgumentError(
        'Tool messages must be handled by toOllamaMessages(), '
        'not toOllamaMessage()',
      );
    }
    throw UnimplementedError('Unsupported role: ${msg.role}');
  }

  /// Ollama accepts images as bare base64 strings; strip any data-URI prefix.
  static String _toOllamaImage(Media media) {
    final url = media.url;
    if (url.startsWith('data:')) {
      final commaIdx = url.indexOf(',');
      if (commaIdx != -1) return url.substring(commaIdx + 1);
    }
    return url;
  }

  static String _encodeToolOutput(Object? output) {
    return output is String ? output : jsonEncode(output);
  }

  static List<sdk.ToolCall> _extractToolCalls(List<Part> content) {
    final toolCalls = <sdk.ToolCall>[];
    for (final part in content) {
      if (part.isToolRequest) {
        final req = part.toolRequest!;
        toolCalls.add(
          sdk.ToolCall(
            function: sdk.ToolCallFunction(
              name: req.name,
              arguments: req.input ?? const {},
            ),
          ),
        );
      }
    }
    return toolCalls;
  }

  /// Converts a Genkit tool definition to Ollama's tool schema.
  static sdk.ToolDefinition toOllamaTool(ToolDefinition tool) {
    var parameters = tool.inputSchema;
    if (parameters == null) {
      parameters = {'type': 'object', 'properties': <String, dynamic>{}};
    } else if (!parameters.containsKey('type')) {
      parameters = {'type': 'object', ...parameters};
    }
    return sdk.ToolDefinition(
      function: sdk.ToolFunction(
        name: tool.name,
        description: tool.description,
        parameters: parameters,
      ),
    );
  }

  /// Converts an Ollama response message to a Genkit [Message].
  static Message fromOllamaMessage(sdk.ChatResponseMessage? msg) {
    final parts = <Part>[];
    if (msg != null) {
      final content = msg.content;
      if (content != null && content.isNotEmpty) {
        parts.add(TextPart(text: content));
      }
      final toolCalls = msg.toolCalls;
      if (toolCalls != null) {
        var index = 0;
        for (final call in toolCalls) {
          final fn = call.function;
          if (fn == null) continue;
          // Ollama does not return tool-call IDs. Synthesize a stable per-call
          // ref so that multiple same-named calls in one response don't collide
          // in Genkit's tool tracking (it otherwise falls back to the name).
          parts.add(
            ToolRequestPart(
              toolRequest: ToolRequest(
                ref: 'tool_call_$index',
                name: fn.name,
                input: fn.arguments,
              ),
            ),
          );
          index++;
        }
      }
    }
    return Message(role: Role.model, content: parts);
  }

  /// Maps an Ollama done reason to a Genkit [FinishReason].
  static FinishReason mapDoneReason(sdk.DoneReason? reason) {
    return switch (reason) {
      sdk.DoneReason.stop => FinishReason.stop,
      sdk.DoneReason.length => FinishReason.length,
      sdk.DoneReason.load || sdk.DoneReason.unload => FinishReason.other,
      null => FinishReason.stop,
    };
  }

  /// Builds Ollama [sdk.ModelOptions] from parsed chat options.
  ///
  /// Stop sequences are passed as a proper list (the JS plugin joins them with
  /// the empty string, which corrupts multi-sequence stops).
  static sdk.ModelOptions? buildModelOptions(ChatModelOptions options) {
    final stop = options.stop;
    final modelOptions = sdk.ModelOptions(
      temperature: options.temperature,
      topK: options.topK,
      topP: options.topP,
      seed: options.seed,
      numCtx: options.numCtx,
      numPredict: options.maxOutputTokens,
      stop: (stop != null && stop.isNotEmpty)
          ? sdk.StopSequence.list(stop)
          : null,
    );
    return modelOptions;
  }

  /// Builds an Ollama response format from a Genkit output config.
  ///
  /// Returns a schema-constrained format when a schema is present, a plain JSON
  /// format for `format: 'json'`, or null otherwise.
  static sdk.ResponseFormat? buildResponseFormat(OutputConfig? output) {
    if (output == null) return null;
    if (!isJsonStructuredOutput(output.format, output.contentType)) {
      return null;
    }
    final schema = output.schema;
    if (schema != null) {
      return sdk.ResponseFormat.schema(schema);
    }
    return const sdk.ResponseFormat.json();
  }

  /// Parses Ollama's `keep_alive` value, which may be a duration string
  /// (`'5m'`) or a number (`0`, `-1`).
  static sdk.KeepAlive? buildKeepAlive(String? keepAlive) {
    if (keepAlive == null) return null;
    final asNumber = num.tryParse(keepAlive);
    return asNumber != null
        ? sdk.KeepAlive.number(asNumber)
        : sdk.KeepAlive.duration(keepAlive);
  }

  /// Extracts the plain-text content of an embedder input document.
  static String documentText(DocumentData doc) {
    return doc.content.where((p) => p.isText).map((p) => p.text ?? '').join();
  }
}
