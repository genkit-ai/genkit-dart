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

import 'package:openai_dart/openai_dart.dart';

/// Aggregates a list of streaming response chunks into a single
/// [CreateChatCompletionResponse].
///
/// This mirrors the pattern used by the Google GenAI plugin's
/// `aggregateResponses`, keeping aggregation in vendor-type space
/// before conversion to Genkit types.
CreateChatCompletionResponse aggregateStreamResponses(
  List<CreateChatCompletionStreamResponse> chunks,
) {
  final contentBuffer = StringBuffer();
  final toolCalls = <int, _ToolCallAccumulator>{};
  ChatCompletionFinishReason? finishReason;
  CompletionUsage? usage;
  String? id;
  var created = 0;
  var model = '';
  String? systemFingerprint;
  ServiceTier? serviceTier;

  for (final chunk in chunks) {
    if (chunk.id != null) id = chunk.id;
    if (chunk.created != null) created = chunk.created!;
    if (chunk.model != null) model = chunk.model!;
    if (chunk.systemFingerprint != null) {
      systemFingerprint = chunk.systemFingerprint;
    }
    if (chunk.serviceTier != null) serviceTier = chunk.serviceTier;
    if (chunk.usage != null) usage = chunk.usage;

    final choices = chunk.choices;
    if (choices == null || choices.isEmpty) continue;

    final choice = choices.first;
    final delta = choice.delta;

    if (delta != null) {
      if (delta.content != null) {
        contentBuffer.write(delta.content);
      }

      if (delta.toolCalls != null) {
        for (final tc in delta.toolCalls!) {
          final index = tc.index ?? 0;
          final acc = toolCalls.putIfAbsent(index, _ToolCallAccumulator.new);
          acc.merge(tc);
        }
      }
    }

    if (choice.finishReason != null) {
      finishReason = choice.finishReason;
    }
  }

  final aggregatedToolCalls = toolCalls.entries
      .map((e) => e.value.toToolCall())
      .whereType<ChatCompletionMessageToolCall>()
      .toList();

  final message =
      ChatCompletionMessage.assistant(
            content: contentBuffer.isNotEmpty ? contentBuffer.toString() : null,
            toolCalls: aggregatedToolCalls.isNotEmpty
                ? aggregatedToolCalls
                : null,
          )
          as ChatCompletionAssistantMessage;

  return CreateChatCompletionResponse(
    id: id,
    choices: [
      ChatCompletionResponseChoice(
        finishReason: finishReason,
        index: 0,
        message: message,
        logprobs: null,
      ),
    ],
    created: created,
    model: model,
    systemFingerprint: systemFingerprint,
    serviceTier: serviceTier,
    object: 'chat.completion',
    usage: usage,
  );
}

class _ToolCallAccumulator {
  String _id = '';
  String _name = '';
  final StringBuffer _arguments = StringBuffer();

  void merge(ChatCompletionStreamMessageToolCallChunk chunk) {
    if (chunk.id != null && chunk.id!.isNotEmpty) {
      _id = chunk.id!;
    }
    if (chunk.function?.name != null && chunk.function!.name!.isNotEmpty) {
      _name = chunk.function!.name!;
    }
    if (chunk.function?.arguments != null) {
      _arguments.write(chunk.function!.arguments);
    }
  }

  ChatCompletionMessageToolCall? toToolCall() {
    if (_id.isEmpty || _name.isEmpty) return null;

    return ChatCompletionMessageToolCall(
      id: _id,
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: _name,
        arguments: _arguments.toString(),
      ),
    );
  }
}
