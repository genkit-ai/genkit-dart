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
import 'package:genkit/src/ai/formatters/formatters.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/exception.dart';

/// Defines the utility 'generate' action.
Action<GenerateActionOptions, ModelResponse, ModelResponseChunk>
defineGenerateAction(Registry registry) {
  return Action(
    actionType: 'util',
    name: 'generate',
    inputType: GenerateActionOptionsType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
    fn: (options, ctx) async {
      final response = await runGenerateAction(registry, options, ctx);
      return response.modelResponse;
    },
  );
}

ToolDefinition toToolDefinition(Tool tool) {
  return ToolDefinition.from(
    name: tool.name,
    description: tool.description!,
    inputSchema: tool.inputType?.jsonSchema != null
        ? tool.inputType?.jsonSchema as Map<String, dynamic>
        : null,
    outputSchema: tool.outputType?.jsonSchema != null
        ? tool.outputType?.jsonSchema as Map<String, dynamic>
        : null,
  );
}

/// Base class for model-specific configuration.
///
/// Model providers can extend this class to provide their own configuration
/// options.
abstract class GenerateConfig {}

/// Represents the output format for a generate request.
class GenerateOutput {
  /// The JSON schema for the output.
  JsonExtensionType? schema;

  /// The output format.
  String? format;

  /// The content type of the output.
  String? contentType;

  GenerateOutput({this.schema, this.format, this.contentType});
}

/// A response from a generate action.
class GenerateResponse<O> {
  final ModelResponse _response;
  final MessageParser<O>? _parser;

  GenerateResponse(this._response, this._parser);

  /// The generated message.
  Message? get message => _response.message;

  /// The reason the generation finished.
  FinishReason get finishReason => _response.finishReason;

  /// The message explaining why the generation finished.
  String? get finishMessage => _response.finishMessage;

  /// The latency of the generation in milliseconds.
  double? get latencyMs => _response.latencyMs;

  /// The usage statistics for the generation.
  GenerationUsage? get usage => _response.usage;

  /// Custom data returned by the model.
  Map<String, dynamic>? get custom => _response.custom;

  /// Raw response data from the model.
  Map<String, dynamic>? get raw => _response.raw;

  /// The request that triggered this generation.
  GenerateRequest? get request => _response.request;

  /// The operation associated with this generation.
  Operation? get operation => _response.operation;

  ModelResponse get modelResponse => _response;

  Map<String, dynamic> toJson() => _response.toJson();

  /// The text content of the response.
  String get text => _response.text;

  /// The media content of the response.
  Media? get media => _response.media;

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests => _response.toolRequests;

  O? get output {
    if (_parser != null && _response.message != null) {
      return _parser(_response.message!);
    }
    return null;
  }
}

Future<GenerateResponse> runGenerateAction(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk> ctx,
) async {
  if (options.model == null) {
    throw GenkitException('Model must be provided', statusCode: 400);
  }

  final model = await registry.lookupAction('model', options.model!) as Model?;
  if (model == null) {
    throw GenkitException('Model ${options.model} not found', statusCode: 404);
  }

  // Resolve and apply format
  final format = resolveFormat(registry, options.output);
  final requestOptions = applyFormat(options, format);

  var toolDefs = <ToolDefinition>[];
  if (requestOptions.tools != null) {
    for (var toolName in requestOptions.tools!) {
      final tool = await registry.lookupAction('tool', toolName) as Tool?;
      if (tool != null) {
        toolDefs.add(toToolDefinition(tool));
      }
    }
  }

  final request = ModelRequest.from(
    messages: requestOptions.messages,
    config: requestOptions.config,
    tools: toolDefs,
    toolChoice: requestOptions.toolChoice,
    output: requestOptions.output == null
        ? null
        : OutputConfig.from(
            format: requestOptions.output!.format,
            contentType: requestOptions.output!.contentType,
            schema: requestOptions.output!.jsonSchema,
          ),
  );
  var currentRequest = request;
  var turns = 0;
  while (turns < (requestOptions.maxTurns ?? 5)) {
    var response = await model(
      currentRequest,
      onChunk: ctx.streamingRequested ? ctx.sendChunk : null,
    );

    final parser =
        format?.handler(requestOptions.output?.jsonSchema).parseMessage;

    if (requestOptions.returnToolRequests ?? false) {
      return GenerateResponse(response, parser);
    }

    final toolRequests = response.message?.content
        .where((c) => c.toJson().containsKey('toolRequest'))
        .map((c) => c as ToolRequestPart)
        .toList();
    if (toolRequests == null || toolRequests.isEmpty) {
      return GenerateResponse(response, parser);
    }

    final toolResponses = <Part>[];
    for (final toolRequest in toolRequests) {
      final tool =
          await registry.lookupAction('tool', toolRequest.toolRequest.name)
              as Tool?;
      if (tool == null) {
        throw GenkitException(
          'Tool ${toolRequest.toolRequest.name} not found',
          statusCode: 404,
        );
      }
      final output = await tool(toolRequest.toolRequest.input);
      toolResponses.add(
        ToolResponsePart.from(
          toolResponse: ToolResponse.from(
            ref: toolRequest.toolRequest.ref,
            name: toolRequest.toolRequest.name,
            output: output,
          ),
        ),
      );
    }

    final newMessages = List<Message>.from(currentRequest.messages)
      ..add(response.message!)
      ..add(Message.from(role: Role.tool, content: toolResponses));

    currentRequest = ModelRequest.from(
      messages: newMessages,
      config: currentRequest.config,
      tools: currentRequest.tools,
      toolChoice: currentRequest.toolChoice,
      output: currentRequest.output,
    );
    turns++;
  }
  throw GenkitException(
    'Reached max turns of ${requestOptions.maxTurns ?? 5}',
    statusCode: 400,
  );
}

Future<GenerateResponse> generateHelper<C>(
  Registry registry, {
  String? prompt,
  List<Message>? messages,
  required ModelRef<C> model,
  C? config,
  List<String>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateOutput? output,
  Map<String, dynamic>? context,
  StreamingCallback<ModelResponseChunk>? onChunk,
}) async {
  if (messages == null && prompt == null) {
    throw ArgumentError('prompt or messages must be provided');
  }

  final resolvedMessages =
      messages ??
      [
        Message.from(
          role: Role.user,
          content: [TextPart.from(text: prompt!)],
        ),
      ];

  final modelName = model.name;

  return await runGenerateAction(
    registry,
    GenerateActionOptions.from(
      model: modelName,
      messages: resolvedMessages,
      config: config is Map ? config : (config as dynamic)?.toJson(),
      tools: tools,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: output == null
          ? null
          : GenerateActionOutputConfig.from(
              format: output.format,
              contentType: output.contentType,
              jsonSchema: output.schema?.jsonSchema as Map<String, dynamic>?,
            ),
    ),
    (
      streamingRequested: onChunk != null,
      sendChunk: onChunk ?? (_) {},
      context: context,
    ),
  );
}
