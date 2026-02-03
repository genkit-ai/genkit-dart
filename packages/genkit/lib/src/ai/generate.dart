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

import 'package:logging/logging.dart';

import '../core/action.dart';
import '../core/registry.dart';
import '../exception.dart';
import '../extract.dart';
import '../schema.dart';
import '../schema_extensions.dart';
import '../types.dart';
import 'formatters/formatters.dart';
import 'generate_middleware.dart';
import 'interrupt.dart';
import 'model.dart';
import 'tool.dart';

final _logger = Logger('genkit');

const _defaultMaxTurns = 5;

/// Defines the utility 'generate' action.
Action<GenerateActionOptions, ModelResponse, ModelResponseChunk, void>
defineGenerateAction(Registry registry) {
  return Action(
    actionType: 'util',
    name: 'generate',
    inputSchema: GenerateActionOptions.$schema,
    outputSchema: ModelResponse.$schema,
    streamSchema: ModelResponseChunk.$schema,
    fn: (options, ctx) async {
      if (options == null) {
        throw GenkitException(
          'Generate action called with null options',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      final response = await runGenerateAction(registry, options, ctx);
      return response.modelResponse;
    },
  );
}

ToolDefinition toToolDefinition(Tool tool) {
  return ToolDefinition(
    name: tool.name,
    description: tool.description!,
    inputSchema: tool.inputSchema?.jsonSchema != null
        ? toJsonSchema(type: tool.inputSchema)
        : null,
    outputSchema: tool.outputSchema?.jsonSchema != null
        ? toJsonSchema(type: tool.outputSchema)
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
  int? get index => _chunk.index;
  Role? get role => _chunk.role;
  List<Part> get content => _chunk.content;
  Map<String, dynamic>? get custom => _chunk.custom;

  // Derived properties
  String get text => content.where((p) => p.isText).map((p) => p.text!).join('');

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

/// A response to an interrupted tool request.
class InterruptResponse {
  final ToolRequestPart _part;
  final dynamic output;

  InterruptResponse(this._part, this.output);

  Map<String, dynamic> toJson() => {
    'name': _part.toolRequest.name,
    'ref': _part.toolRequest.ref,
    'output': output,
  };
}

/// A response from a generate action.
class GenerateResponseHelper<O> extends GenerateResponse {
  final ModelResponse _response;
  final ModelRequest? _request;
  final O? output;

  GenerateResponseHelper(this._response, {ModelRequest? request, this.output})
    : _request = request,
      super(
        message: _response.message,
        finishReason: _response.finishReason,
        finishMessage: _response.finishMessage,
        latencyMs: _response.latencyMs,
        usage: _response.usage,
        custom: _response.custom,
        raw: _response.raw,
        request: _response.request, // This uses ModelResponse.request
        operation: _response.operation,
        candidates: [
          Candidate(
            index: 0,
            message: _response.message!,
            finishReason: _response.finishReason,
            finishMessage: _response.finishMessage,
            usage: _response.usage,
            custom: _response.custom,
          ),
        ],
      );

  /// The full history of the conversation, including the request messages and
  /// the final model response.
  ///
  /// This is useful for continuing the conversation in multi-turn scenarios.
  List<Message> get messages => [
    ...(_request?.messages ?? _response.request?.messages ?? []),
    _response.message!,
  ];

  ModelResponse get modelResponse => _response;

  /// The text content of the response.
  String get text => _response.text;

  /// The media content of the response.
  Media? get media => _response.media;

  /// The tool requests in the response.
  List<ToolRequest> get toolRequests => _response.toolRequests;

  /// The list of tool requests that triggered an interrupt.
  ///
  /// These parts contain metadata with the interrupt payload.
  List<ToolRequestPart> get interrupts {
    return _response.message?.content
            .where(
              (p) =>
                  p.isToolRequest &&
                  (p.metadata?.containsKey('interrupt') ?? false),
            )
            .map((p) => p.toolRequestPart!)
            .toList() ??
        [];
  }

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

Future<GenerateResponseHelper> _runGenerateLoop(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx, {
  List<GenerateMiddleware>? middlewares,
}) async {
  if (options.model == null) {
    throw GenkitException(
      'Model must be provided',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final model = await registry.lookupAction('model', options.model!) as Model?;
  if (model == null) {
    throw GenkitException(
      'Model ${options.model} not found',
      status: StatusCodes.NOT_FOUND,
    );
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

  final request = ModelRequest(
    messages: requestOptions.messages,
    config: requestOptions.config,
    tools: toolDefs,
    toolChoice: requestOptions.toolChoice,
    output: requestOptions.output == null
        ? null
        : OutputConfig(
            format: requestOptions.output!.format,
            contentType: requestOptions.output!.contentType,
            schema: requestOptions.output!.jsonSchema,
            constrained: requestOptions.output!.constrained,
          ),
  );
  var currentRequest = request;
  var turns = 0;

  // Prepare model middleware chain
  Future<ModelResponse> coreModel(
    ModelRequest req,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> c,
  ) {
    return model(
      req,
      onChunk: c.streamingRequested ? c.sendChunk : null,
      context: c.context,
    );
  }

  final composedModel =
      middlewares?.reversed.fold(
        coreModel,
        (next, mw) =>
            (r, c) => mw.model(r, c, next),
      ) ??
      coreModel;

  // Check for resume
  if (requestOptions.resume != null) {
    currentRequest = _resolveResume(currentRequest, requestOptions.resume!);
  }

  var messageIndex = 0;
  while (turns < (requestOptions.maxTurns ?? _defaultMaxTurns)) {
    // Execute model with middleware
    var response = await composedModel(currentRequest, (
      streamingRequested: ctx.streamingRequested,
      sendChunk: (chunk) {
        ctx.sendChunk(
          ModelResponseChunk(
            index: messageIndex,
            content: chunk.content,
            role: chunk.role,
            custom: chunk.custom,
            aggregated: chunk.aggregated,
          ),
        );
      },
      context: ctx.context,
      inputStream: null,
      init: null,
    ));
    messageIndex++;

    final parser = format
        ?.handler(requestOptions.output?.jsonSchema)
        .parseMessage;

    if (requestOptions.returnToolRequests ?? false) {
      return GenerateResponseHelper(
        response,
        request: currentRequest,
        output: null,
      );
    }

    final toolRequests = response.message?.content
        .map((c) => c.toolRequestPart)
        .nonNulls
        .toList();
    if (toolRequests == null || toolRequests.isEmpty) {
      return GenerateResponseHelper(
        response,
        request: currentRequest,
        output: _parseOutput(response.message, parser),
      );
    }

    final execution = await _executeTools(
      registry,
      toolRequests,
      ctx.context,
      middlewares: middlewares,
    );
    final toolResponses = execution.toolResponses;
    final toolStatus = execution.toolStatus;
    final interrupted = execution.interrupted;

    if (interrupted) {
      final newContent = <Part>[];
      for (final part in response.message!.content) {
        if (part.isToolRequest) {
          final req = part.toolRequestPart!.toolRequest;
          final ref = req.ref ?? req.name;
          final status = toolStatus[ref];
          final meta = Map<String, dynamic>.from(part.metadata ?? {});

          if (status is ToolInterruptException) {
            meta['interrupt'] = status.interrupt;
          } else if (status != null) {
            meta['pendingOutput'] = status;
          }
          newContent.add(
            ToolRequestPart(
              toolRequest: req,
              custom: part.custom,
              data: part.data,
              metadata: meta,
            ),
          );
        } else {
          newContent.add(part);
        }
      }

      final newMessage = Message(
        role: response.message!.role,
        content: newContent,
        metadata: response.message!.metadata,
      );

      final newResponse = ModelResponse(
        message: newMessage,
        finishReason: FinishReason.interrupted,
        finishMessage: response.finishMessage,
        latencyMs: response.latencyMs,
        usage: response.usage,
        custom: response.custom,
        raw: response.raw,
        request: response.request,
        operation: response.operation,
      );

      return GenerateResponseHelper(
        newResponse,
        request: currentRequest,
        output: null,
      );
    }

    final newMessages = List<Message>.from(currentRequest.messages)
      ..add(response.message!)
      ..add(Message(role: Role.tool, content: toolResponses));

    currentRequest = ModelRequest(
      messages: newMessages,
      config: currentRequest.config,
      tools: currentRequest.tools,
      toolChoice: currentRequest.toolChoice,
      output: currentRequest.output,
    );
    turns++;
  }
  throw GenkitException(
    'Reached max turns of ${requestOptions.maxTurns ?? _defaultMaxTurns}. Adjust maxTurns option to increase the max number of turns.',
    status: StatusCodes.ABORTED,
  );
}

Future<GenerateResponseHelper> runGenerateAction(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx, {
  List<GenerateMiddleware>? middlewares,
}) async {
  Future<GenerateResponseHelper> coreGenerate(
    GenerateActionOptions opts,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> c,
  ) {
    return _runGenerateLoop(registry, opts, c, middlewares: middlewares);
  }

  final composedGenerate =
      middlewares?.reversed.fold(
        coreGenerate,
        (next, mw) =>
            (o, c) => mw.generate(o, c, next),
      ) ??
      coreGenerate;

  return composedGenerate(options, ctx);
}

Future<GenerateResponseHelper> generateHelper<C>(
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
  List<GenerateMiddleware>? middlewares,

  /// List of interrupt responses to resolve interrupts.
  List<InterruptResponse>? resume,
}) async {
  if (messages == null && prompt == null) {
    throw ArgumentError('prompt or messages must be provided');
  }

  Map<String, dynamic>? resolvedResume;
  if (resume != null) {
    resolvedResume = {'respond': resume.map((r) => r.toJson()).toList()};
  }

  final resolvedMessages = messages ?? [];
  if (prompt != null) {
    resolvedMessages.add(
      Message(
        role: Role.user,
        content: [TextPart(text: prompt)],
      ),
    );
  }
  final modelName = model.name;

  final format = resolveFormat(registry, output);
  final chunkParser = format?.handler(output?.jsonSchema).parseChunk;
  final previousChunks = <ModelResponseChunk>[];

  return await runGenerateAction(
    registry,
    GenerateActionOptions(
      model: modelName,
      messages: resolvedMessages,
      config: config is Map ? config : (config as dynamic)?.toJson(),
      tools: tools,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: output,
      resume: resolvedResume,
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
    middlewares: middlewares,
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
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: promptOrMessages)],
            ),
          ],
        ),
      );
    } else if (promptOrMessages is List<Part>) {
      _session.send(
        ModelRequest(
          messages: [Message(role: Role.user, content: promptOrMessages)],
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
    throw GenkitException(
      'Bidi Model $modelName not found',
      status: StatusCodes.NOT_FOUND,
    );
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

  final initRequest = ModelRequest(
    messages: [
      if (system != null)
        Message(
          role: Role.system,
          content: [TextPart(text: system)],
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
            .map((p) => ToolRequestPart.fromJson(p.toJson()))
            .toList();

        if (toolRequests.isNotEmpty) {
          _logger.fine('Processing ${toolRequests.length} tool requests');
          final toolResponses = <Part>[];
          for (final toolRequest in toolRequests) {
            final tool = toolActions.firstWhere(
              (t) => t.name == toolRequest.toolRequest.name,
              orElse: () => throw GenkitException(
                'Tool ${toolRequest.toolRequest.name} not found',
                status: StatusCodes.NOT_FOUND,
              ),
            );

            try {
              final output = await tool.runRaw(toolRequest.toolRequest.input);
              toolResponses.add(
                ToolResponsePart(
                  toolResponse: ToolResponse(
                    ref: toolRequest.toolRequest.ref,
                    name: toolRequest.toolRequest.name,
                    output: output.result,
                  ),
                ),
              );
            } catch (e) {
              toolResponses.add(
                ToolResponsePart(
                  toolResponse: ToolResponse(
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
            ModelRequest(
              messages: [Message(role: Role.tool, content: toolResponses)],
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

dynamic _parseOutput<O>(Message? message, MessageParser? parser) {
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
  // final dataPart =
  //     chunk.content.where((p) => p.isData).firstOrNull?.dataPart;
  // if (dataPart != null && dataPart.data != null) {
  //   return dataPart.data as O?;
  // }
  return null;
}

ModelRequest _resolveResume(ModelRequest request, Map<String, dynamic> resume) {
  final lastMessage = request.messages.lastOrNull;
  if (lastMessage?.role != Role.model ||
      !(lastMessage?.content.any((p) => p.isToolRequest) ?? false)) {
    return request;
  }

  final toolResponses = <Part>[];
  final resumeRespond =
      (resume['respond'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  final newContent = <Part>[];
  for (final part in lastMessage!.content) {
    if (part.isToolRequest) {
      final req = part.toolRequestPart!.toolRequest;
      final meta = part.metadata ?? {};
      dynamic output;

      if (meta.containsKey('pendingOutput')) {
        output = meta['pendingOutput'];
      } else {
        final match = resumeRespond.firstWhere(
          (r) => r['ref'] == req.ref && r['name'] == req.name,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          output = match['output'];
        }
      }

      if (output != null) {
        toolResponses.add(
          ToolResponsePart(
            toolResponse: ToolResponse(
              ref: req.ref,
              name: req.name,
              output: output,
            ),
          ),
        );
        final newMeta = Map<String, dynamic>.from(meta);
        if (newMeta.containsKey('interrupt')) {
          newMeta['resolvedInterrupt'] = true;
          newMeta.remove('interrupt');
        }
        newContent.add(
          ToolRequestPart(
            toolRequest: req,
            custom: part.custom,
            data: part.data,
            metadata: newMeta,
          ),
        );
      } else {
        throw GenkitException(
          'Unresolved tool request ${req.name}. You must supply replies for all interrupted tool requests.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
    } else {
      newContent.add(part);
    }
  }

  final newMessages = List<Message>.from(request.messages);
  newMessages.removeLast();
  newMessages.add(
    Message(
      role: lastMessage.role,
      content: newContent,
      metadata: lastMessage.metadata,
    ),
  );
  newMessages.add(Message(role: Role.tool, content: toolResponses));

  return ModelRequest(
    messages: newMessages,
    config: request.config,
    tools: request.tools,
    toolChoice: request.toolChoice,
    output: request.output,
  );
}

Future<
  ({
    List<Part> toolResponses,
    bool interrupted,
    Map<String, dynamic> toolStatus,
  })
>
_executeTools(
  Registry registry,
  List<ToolRequestPart> toolRequests,
  Map<String, dynamic>? context, {
  List<GenerateMiddleware>? middlewares,
}) async {
  final toolResponses = <Part>[];
  final toolStatus = <String, dynamic>{};
  var interrupted = false;

  for (final toolRequest in toolRequests) {
    final tool =
        await registry.lookupAction('tool', toolRequest.toolRequest.name)
            as Tool?;
    if (tool == null) {
      throw GenkitException(
        'Tool ${toolRequest.toolRequest.name} not found',
        status: StatusCodes.NOT_FOUND,
      );
    }

    Future<ToolResponse> coreTool(
      ToolRequest req,
      ActionFnArg<void, dynamic, void> c,
    ) async {
      final out = await tool.runRaw(req.input, context: c.context);
      return ToolResponse(ref: req.ref, name: req.name, output: out.result);
    }

    final composedTool =
        middlewares?.reversed.fold(
          coreTool,
          (next, mw) =>
              (r, c) => mw.tool(r, c, next),
        ) ??
        coreTool;

    try {
      final toolResponse = await composedTool(toolRequest.toolRequest, (
        streamingRequested: false,
        sendChunk: (_) {},
        context: context,
        inputStream: null,
        init: null,
      ));
      toolResponses.add(ToolResponsePart(toolResponse: toolResponse));
      toolStatus[toolRequest.toolRequest.ref ?? toolRequest.toolRequest.name] =
          toolResponse.output;
    } on ToolInterruptException catch (e) {
      interrupted = true;
      toolStatus[toolRequest.toolRequest.ref ?? toolRequest.toolRequest.name] =
          e;
    } catch (e) {
      toolResponses.add(
        ToolResponsePart(
          toolResponse: ToolResponse(
            ref: toolRequest.toolRequest.ref,
            name: toolRequest.toolRequest.name,
            output: 'Error: $e',
          ),
        ),
      );
    }
  }
  return (
    toolResponses: toolResponses,
    interrupted: interrupted,
    toolStatus: toolStatus,
  );
}
