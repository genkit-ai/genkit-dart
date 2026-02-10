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
import 'package:openai_dart/openai_dart.dart' hide Model;

import '../genkit_openai_compat.dart';

/// Internal tool call accumulator for streaming responses
class _ToolCallAccumulator {
  final String id;
  final String name;
  final StringBuffer arguments = StringBuffer();

  _ToolCallAccumulator(this.id, this.name);
}

/// Core plugin implementation
class OpenAICompatPlugin extends GenkitPlugin {
  @override
  String get name => 'openai_compat';

  final String? apiKey;
  final String? baseURL;
  final List<CustomModelDefinition> customModels;
  final Map<String, String>? headers;

  OpenAICompatPlugin({
    this.apiKey,
    this.baseURL,
    this.customModels = const [],
    this.headers,
  });

  @override
  Future<List<Action>> init() async {
    final actions = <Action>[];

    // Register default OpenAI models if using default baseURL
    if (baseURL == null) {
      actions.addAll([
        _createModel('gpt-4o', defaultModelInfo('gpt-4o')),
        _createModel('gpt-4o-mini', defaultModelInfo('gpt-4o-mini')),
        _createModel('gpt-4-turbo', defaultModelInfo('gpt-4-turbo')),
        _createModel('gpt-3.5-turbo', defaultModelInfo('gpt-3.5-turbo')),
        _createModel('o1', o1ModelInfo()),
        _createModel('o1-mini', o1ModelInfo()),
        _createModel('o3-mini', o1ModelInfo()),
      ]);
    }

    // Register custom models
    for (final model in customModels) {
      actions.add(_createModel(model.name, model.info));
    }

    return actions;
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType == 'model') {
      return _createModel(name, null);
    }
    return null;
  }

  Model _createModel(String modelName, ModelInfo? info) {
    return Model(
      name: 'openai_compat/$modelName',
      customOptions: OpenAIOptionsSchema.$schema,
      metadata: {
        'model': (info ?? defaultModelInfo(modelName)).toJson(),
      },
      fn: (req, ctx) async {
        final options = req!.config != null
            ? OpenAIOptionsSchema.$schema.parse(req.config!)
            : OpenAIOptionsSchema();

        if (apiKey == null) {
          throw GenkitException(
            'API key is required. Provide it via the plugin constructor.',
          );
        }

        final client = OpenAIClient(
          apiKey: apiKey!,
          baseUrl: baseURL,
          headers: headers,
        );

        try {
          final request = CreateChatCompletionRequest(
            model: ChatCompletionModel.modelId(options.version ?? modelName),
            messages: toOpenAIMessages(req.messages, options.visualDetailLevel),
            tools: req.tools?.map(toOpenAITool).toList(),
            temperature: options.temperature,
            topP: options.topP,
            maxTokens: options.maxTokens,
            stop: options.stop != null
                ? ChatCompletionStop.listString(options.stop!)
                : null,
            presencePenalty: options.presencePenalty,
            frequencyPenalty: options.frequencyPenalty,
            seed: options.seed,
            user: options.user,
            responseFormat: options.jsonMode == true
                ? const ResponseFormat.jsonObject()
                : null,
          );

          if (ctx.streamingRequested) {
            return await _handleStreaming(client, request, ctx);
          } else {
            return await _handleNonStreaming(client, request);
          }
        } catch (e, stackTrace) {
          if (e is GenkitException) {
            rethrow;
          }

          StatusCodes? status;
          String? details;

          if (e is OpenAIClientException) {
            status = e.code != null ? StatusCodes.fromHttpStatus(e.code!) : null;
            details = e.body?.toString();
          }

          throw GenkitException(
            'OpenAI API error: $e',
            status: status,
            details: details ?? e.toString(),
            underlyingException: e,
            stackTrace: stackTrace,
          );
        } finally {
          client.endSession();
        }
      },
    );
  }

  /// Handle streaming response
  Future<ModelResponse> _handleStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
    ({
      bool streamingRequested,
      void Function(ModelResponseChunk) sendChunk,
      Map<String, dynamic>? context,
      Stream<ModelRequest>? inputStream,
      void init,
    }) ctx,
  ) async {
    final stream = client.createChatCompletionStream(request: request);

    final contentBuffer = StringBuffer();
    final toolCalls = <String, _ToolCallAccumulator>{};
    String? finishReason;

    try {
      await for (final chunk in stream) {
        final delta = chunk.choices.firstOrNull?.delta;
        if (delta == null) continue;

        final parts = <Part>[];

        // Handle text content
        if (delta.content != null) {
          contentBuffer.write(delta.content);
          parts.add(TextPart(text: delta.content!));
        }

        // Handle tool calls (accumulated across chunks)
        if (delta.toolCalls != null) {
          for (final tc in delta.toolCalls!) {
            final index = tc.index.toString();
            final acc = toolCalls.putIfAbsent(
              index,
              () => _ToolCallAccumulator(
                tc.id ?? '',
                tc.function?.name ?? '',
              ),
            );
            if (tc.function?.arguments != null) {
              acc.arguments.write(tc.function!.arguments);
            }
          }
        }

        if (parts.isNotEmpty) {
          ctx.sendChunk(ModelResponseChunk(index: 0, content: parts));
        }

        finishReason = chunk.choices.firstOrNull?.finishReason?.name;
      }
    } catch (e) {
      if (e is GenkitException) rethrow;
      throw GenkitException(
        'Error in streaming: $e',
        underlyingException: e,
      );
    }

    // Build final message
    final finalParts = <Part>[];
    if (contentBuffer.isNotEmpty) {
      finalParts.add(TextPart(text: contentBuffer.toString()));
    }
    for (final tc in toolCalls.values) {
      final argumentsJson = tc.arguments.toString();
      final input = argumentsJson.isNotEmpty
          ? jsonDecode(argumentsJson) as Map<String, dynamic>?
          : null;
      finalParts.add(
        ToolRequestPart(
          toolRequest: ToolRequest(
            ref: tc.id,
            name: tc.name,
            input: input,
          ),
        ),
      );
    }

    return ModelResponse(
      finishReason: mapFinishReason(finishReason),
      message: Message(role: Role.model, content: finalParts),
    );
  }

  /// Handle non-streaming response
  Future<ModelResponse> _handleNonStreaming(
    OpenAIClient client,
    CreateChatCompletionRequest request,
  ) async {
    final response = await client.createChatCompletion(request: request);

    if (response.choices.isEmpty) {
      throw GenkitException('Model returned no choices.');
    }

    final choice = response.choices.first;
    final message = fromOpenAIAssistantMessage(choice.message);

    return ModelResponse(
      finishReason: mapFinishReason(choice.finishReason?.name),
      message: message,
      raw: response.toJson(),
    );
  }
}
