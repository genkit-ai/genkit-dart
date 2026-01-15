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

import 'dart:async';
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/formatters/formatters.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/extract.dart';
import 'package:genkit/src/schema.dart';
import 'package:logging/logging.dart';

final _logger = Logger('genkit');

/// Defines the utility 'generate' action.
Action<GenerateActionOptions, ModelResponse, ModelResponseChunk, void>
defineGenerateAction(Registry registry) {
  return Action(
    actionType: 'util',
    name: 'generate',
    inputType: GenerateActionOptionsType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
    fn: (options, ctx) async {
      if (options == null) {
        throw Exception('Generate action called with null options');
      }
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
        ? toJsonSchema(type: tool.inputType)
        : null,
    outputSchema: tool.outputType?.jsonSchema != null
        ? toJsonSchema(type: tool.outputType)
        : null,
  );
}

/// Base class for model-specific configuration.
///
/// Model providers can extend this class to provide their own configuration
/// options.
abstract class GenerateConfig {}

/// A chunk of a response from a generate action.
class GenerateResponseChunk<O> {
  final ModelResponseChunk _chunk;
  final List<ModelResponseChunk> previousChunks;
  final O? output;

  GenerateResponseChunk(
    this._chunk, {
    this.previousChunks = const [],
    this.output,
  });

  // Delegate properties to _chunk
  double? get index => _chunk.index;
  Role? get role => _chunk.role;
  List<Part> get content => _chunk.content;
  Map<String, dynamic>? get custom => _chunk.custom;

  // Derived properties
  String get text =>
      content.where((p) => p.isText).map((p) => p.text!).join('');

  String get accumulatedText {
    final prev = previousChunks.map((c) => c.text).join('');
    return prev + text;
  }

  /// Tries to parse the output as JSON.
  ///
  /// This will be populated if the output format is JSON, or if the output is
  /// arbitrarily parsed as JSON.
  O? get jsonOutput {
    if (output != null) return output;
    return extractJson(accumulatedText) as O?;
  }

  Map<String, dynamic> toJson() => _chunk.toJson();

  ModelResponseChunk get rawChunk => _chunk;
}

/// A response from a generate action.
class GenerateResponse<O> {
  final ModelResponse _response;
  final O? output;

  GenerateResponse(this._response, {this.output});

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

  /// Tries to parse the output as JSON.
  ///
  /// This will be populated if the output format is JSON, or if the output is
  /// arbitrarily parsed as JSON.
  O? get jsonOutput {
    if (output != null) return output;
    return extractJson(text) as O?;
  }

  ModelResponse get rawResponse => _response;
}

Future<GenerateResponse<O>> runGenerateAction<O>(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
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
            constrained: requestOptions.output!.constrained,
          ),
  );
  var currentRequest = request;
  var turns = 0;
  while (turns < (requestOptions.maxTurns ?? 5)) {
    var response = await model(
      currentRequest,
      onChunk: ctx.streamingRequested ? ctx.sendChunk : null,
    );

    final parser = format
        ?.handler(requestOptions.output?.jsonSchema)
        .parseMessage;

    if (requestOptions.returnToolRequests ?? false) {
      return GenerateResponse<O>(response, output: null);
    }

    final toolRequests = response.message?.content
        .where((c) => c.isToolRequest)
        .map((c) => c as ToolRequestPart)
        .toList();
    if (toolRequests == null || toolRequests.isEmpty) {
      return GenerateResponse<O>(
        response,
        output: _parseOutput(response.message, parser),
      );
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

Future<GenerateResponse<O>> generateHelper<C, O>(
  Registry registry, {
  String? prompt,
  List<Message>? messages,
  required ModelRef<C> model,
  C? config,
  List<String>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateActionOutputConfig? output,
  Map<String, dynamic>? context,
  StreamingCallback<GenerateResponseChunk>? onChunk,
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

  final format = resolveFormat(registry, output);
  final chunkParser = format?.handler(output?.jsonSchema).parseChunk;
  final previousChunks = <ModelResponseChunk>[];

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
      output: output,
    ),
    (
      streamingRequested: onChunk != null,
      sendChunk: (chunk) {
        if (onChunk != null) {
          final wrapped = GenerateResponseChunk(
            chunk,
            previousChunks: previousChunks,
            output: _parseChunkOutput(chunk, previousChunks, chunkParser),
          );
          previousChunks.add(chunk);
          onChunk(wrapped);
        }
      },
      context: context,
      inputStream: null,
      init: null,
    ),
  );
}

class GenerateBidiSession {
  final BidiActionStream<ModelResponseChunk, ModelResponse, ModelRequest>
  _session;
  final Stream<GenerateResponseChunk> stream;

  GenerateBidiSession._(this._session, this.stream);

  void send(dynamic promptOrMessages) {
    if (promptOrMessages is String) {
      _session.send(
        ModelRequest.from(
          messages: [
            Message.from(
              role: Role.user,
              content: [TextPart.from(text: promptOrMessages)],
            ),
          ],
        ),
      );
    } else if (promptOrMessages is List<Part>) {
      _session.send(
        ModelRequest.from(
          messages: [Message.from(role: Role.user, content: promptOrMessages)],
        ),
      );
    } else if (promptOrMessages is ModelRequest) {
      _session.send(promptOrMessages);
    } else {
      throw ArgumentError(
        'Invalid argument type. Expected String, List<Part>, or ModelRequest.',
      );
    }
  }

  Future<void> close() => _session.close();
}

Future<GenerateBidiSession> runGenerateBidi(
  Registry registry, {
  required String modelName,
  dynamic config,
  List<String>? tools,
  String? system,
}) async {
  final model =
      await registry.lookupAction('bidi-model', modelName) as BidiModel?;
  if (model == null) {
    throw GenkitException('Bidi Model $modelName not found', statusCode: 404);
  }

  var toolDefs = <ToolDefinition>[];
  var toolActions = <Tool>[];
  if (tools != null) {
    for (var toolName in tools) {
      final tool = await registry.lookupAction('tool', toolName) as Tool?;
      if (tool != null) {
        toolActions.add(tool);
        toolDefs.add(toToolDefinition(tool));
      }
    }
  }

  final initRequest = ModelRequest.from(
    messages: [
      if (system != null)
        Message.from(
          role: Role.system,
          content: [TextPart.from(text: system)],
        ),
    ],
    config: config is Map
        ? config as Map<String, dynamic>
        : (config as dynamic)?.toJson(),
    tools: toolDefs,
  );

  final session = model.streamBidi(init: initRequest);

  // ignore: close_sinks
  final outputController = StreamController<GenerateResponseChunk>();
  final previousChunks = <ModelResponseChunk>[];

  void handleStream() async {
    try {
      await for (final chunk in session) {
        final wrapped = GenerateResponseChunk(
          chunk,
          previousChunks: previousChunks,
          output: _parseChunkOutput(chunk, previousChunks, null),
        );
        previousChunks.add(chunk);
        if (!outputController.isClosed) {
          outputController.add(wrapped);
        }

        final toolRequests = chunk.content
            .where((p) => p.isToolRequest)
            .map((p) => p as ToolRequestPart)
            .toList();

        if (toolRequests.isNotEmpty) {
          _logger.fine('Processing ${toolRequests.length} tool requests');
          final toolResponses = <Part>[];
          for (final toolRequest in toolRequests) {
            final tool = toolActions.firstWhere(
              (t) => t.name == toolRequest.toolRequest.name,
              orElse: () => throw GenkitException(
                'Tool ${toolRequest.toolRequest.name} not found',
                statusCode: 404,
              ),
            );

            try {
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
            } catch (e) {
              toolResponses.add(
                ToolResponsePart.from(
                  toolResponse: ToolResponse.from(
                    ref: toolRequest.toolRequest.ref,
                    name: toolRequest.toolRequest.name,
                    output: 'Error: $e',
                  ),
                ),
              );
            }
          }
          _logger.fine('toolResponses: $toolResponses');
          session.send(
            ModelRequest.from(
              messages: [Message.from(role: Role.tool, content: toolResponses)],
            ),
          );
        }
      }
      if (!outputController.isClosed) outputController.close();
    } catch (e, st) {
      if (!outputController.isClosed) {
        outputController.addError(e, st);
        outputController.close();
      }
    }
  }

  handleStream();

  return GenerateBidiSession._(session, outputController.stream);
}

O? _parseOutput<O>(Message? message, MessageParser? parser) {
  if (parser != null && message != null) {
    return parser(message);
  }
  return null;
}

O? _parseChunkOutput<O>(
  ModelResponseChunk chunk,
  List<ModelResponseChunk> previousChunks,
  ChunkParser<O>? parser,
) {
  if (parser != null) {
    final temp = GenerateResponseChunk<O>(
      chunk,
      previousChunks: previousChunks,
      output: null,
    );
    return parser(temp);
  }
  final dataPart =
      chunk.content.where((p) => p.isData).firstOrNull as DataPart?;
  if (dataPart != null && dataPart.data != null) {
    return dataPart.data as O?;
  }
  return null;
}
