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

import '../core/action.dart';
import '../core/dynamic_action_provider.dart';
import '../core/registry.dart';
import '../exception.dart';
import '../o11y/instrumentation.dart';
import '../schema.dart';
import '../schema_extensions.dart';
import '../types.dart';
import 'formatters/formatters.dart';
import 'generate_middleware.dart';
import 'generate_types.dart';
import 'interrupt.dart';
import 'model.dart';
import 'tool.dart';

const _defaultMaxTurns = 5;

typedef _ToolStatus = ({Object? output, ToolInterruptException? interrupt});

typedef GenerateAction =
    Action<GenerateActionOptions, ModelResponse, ModelResponseChunk, void>;

/// Defines the utility 'generate' action.
GenerateAction defineGenerateAction(Registry registry) {
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
      // TODO: resolve middleware from `options.use`.
      final response = await runGenerateAction(
        registry,
        options,
        ctx,
        skipTelemetry: true,
      );
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

({List<GenerateMiddleware> middleware, Registry registry}) _resolveMiddleware(
  Registry registry,
  List<GenerateMiddlewareOneof>? middleware,
) {
  final resolvedMiddleware = <GenerateMiddleware>[];
  if (middleware != null) {
    for (final mw in middleware) {
      if (mw.middlewareInstance != null) {
        resolvedMiddleware.add(mw.middlewareInstance!);
      } else if (mw.middlewareRef != null) {
        final def = registry.lookupValue<GenerateMiddlewareDef>(
          'middleware',
          mw.middlewareRef!.name,
        );
        if (def == null) {
          throw GenkitException(
            'Middleware ${mw.middlewareRef!.name} not found',
            status: StatusCodes.NOT_FOUND,
          );
        }
        resolvedMiddleware.add(def.create(mw.middlewareRef!.config));
      } else {
        throw GenkitException(
          'Invalid middleware type: ${mw.runtimeType}. Expected GenerateMiddleware or GenerateMiddlewareRef.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
    }
  }

  final middlewareTools = resolvedMiddleware
      .expand((m) => m.tools ?? <Tool>[])
      .toList();
  if (middlewareTools.isNotEmpty) {
    registry = Registry.childOf(registry);
    for (final tool in middlewareTools) {
      registry.register(tool);
    }
  }

  return (middleware: resolvedMiddleware, registry: registry);
}

Future<
  ({
    Registry registry,
    List<ToolDefinition> toolDefs,
    Set<String> activeToolNames,
  })
>
_resolveTools(
  Registry registry,
  List<String>? requestedTools,
  List<GenerateMiddleware> resolvedMiddleware,
) async {
  var toolDefs = <ToolDefinition>[];
  final activeToolNames = <String>{};
  var currentRegistry = registry;

  if (requestedTools != null) {
    if (requestedTools.any((t) => t.contains(':'))) {
      currentRegistry = Registry.childOf(registry);
    }
    for (var toolName in requestedTools) {
      final colonIdx = toolName.indexOf(':');
      if (colonIdx != -1) {
        final dapName = toolName.substring(0, colonIdx);
        var actionMatcher = toolName.substring(colonIdx + 1);
        if (actionMatcher.startsWith('tool/')) {
          actionMatcher = actionMatcher.substring('tool/'.length);
        }
        final dap =
            await currentRegistry.lookupAction(
                  'dynamic-action-provider',
                  dapName,
                )
                as DynamicActionProvider?;

        if (dap != null) {
          if (actionMatcher.endsWith('*')) {
            final prefix = actionMatcher.substring(0, actionMatcher.length - 1);
            final actions = await dap.listActions();
            for (final action in actions) {
              if (action.actionType == 'tool' &&
                  (prefix.isEmpty || action.name.startsWith(prefix))) {
                final fullAction = await dap.getAction(action.name);
                if (fullAction != null && fullAction is Tool) {
                  currentRegistry.register(fullAction);
                  activeToolNames.add(fullAction.name);
                  toolDefs.add(toToolDefinition(fullAction));
                }
              }
            }
          } else {
            final fullAction = await dap.getAction(actionMatcher);
            if (fullAction != null && fullAction is Tool) {
              currentRegistry.register(fullAction);
              activeToolNames.add(fullAction.name);
              toolDefs.add(toToolDefinition(fullAction));
            }
          }
          continue;
        }
      }

      activeToolNames.add(toolName);
      final tool =
          await currentRegistry.lookupAction('tool', toolName) as Tool?;
      if (tool != null) {
        toolDefs.add(toToolDefinition(tool));
      }
    }
  }

  final middlewareTools = resolvedMiddleware
      .expand((m) => m.tools ?? <Tool>[])
      .toList();
  for (final tool in middlewareTools) {
    if (!activeToolNames.contains(tool.name)) {
      activeToolNames.add(tool.name);
      toolDefs.add(toToolDefinition(tool));
    }
  }

  return (
    registry: currentRegistry,
    toolDefs: toolDefs,
    activeToolNames: activeToolNames,
  );
}

Future<GenerateResponseHelper> _runGenerateLoop(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx, {
  required List<GenerateMiddleware> resolvedMiddleware,
  required Future<GenerateResponseHelper> Function(
    GenerateActionOptions opts,
    int currentTurn,
  )
  composedGenerate,
  int currentTurn = 0,
}) async {
  if (options.model == null) {
    throw GenkitException(
      'Model must be provided',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  // Check turn limits
  final maxTurns = options.maxTurns ?? _defaultMaxTurns;
  if (currentTurn >= maxTurns) {
    throw GenkitException(
      'Reached max turns of $maxTurns. Adjust maxTurns option to increase the max number of turns.',
      status: StatusCodes.ABORTED,
    );
  }

  final modelName = options.model!;
  final model = await registry.lookupAction('model', modelName) as Model?;
  if (model == null) {
    throw GenkitException(
      'Model $modelName not found',
      status: StatusCodes.NOT_FOUND,
    );
  }

  // Resolve and apply format
  final format = resolveFormat(registry, options.output);
  final requestOptions = applyFormat(options, format);

  final resolved = await _resolveTools(
    registry,
    requestOptions.tools,
    resolvedMiddleware,
  );
  registry = resolved.registry;
  final toolDefs = resolved.toolDefs;

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

  final composedModel = resolvedMiddleware.reversed.fold(
    coreModel,
    (next, mw) =>
        (r, c) => mw.model(r, c, next),
  );

  // Check for resume
  if (requestOptions.resume != null) {
    final resumed = await _resolveResume(
      registry,
      currentRequest,
      requestOptions.resume!,
      ctx.context,
      resolvedMiddleware,
    );
    if (resumed.interruptedResponse != null) {
      return GenerateResponseHelper(
        resumed.interruptedResponse!,
        request: currentRequest,
        output: null,
      );
    }
    currentRequest = resumed.request!;
  }

  // Execute model with middleware
  var response = await composedModel(currentRequest, (
    streamingRequested: ctx.streamingRequested,
    sendChunk: (chunk) {
      ctx.sendChunk(
        ModelResponseChunk(
          index: currentTurn, // Use currentTurn to indicate the loop iteration
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
    middleware: resolvedMiddleware,
  );
  final toolResponses = execution.toolResponses;
  final toolStatus = execution.toolStatus;
  final interrupted = execution.interrupted;

  if (interrupted) {
    final newResponse = _buildInterruptedResponse(
      response.message!,
      toolStatus,
      originalResponse: response,
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

  final nextOptions = GenerateActionOptions(
    model: options.model,
    docs: options.docs,
    messages: newMessages,
    tools: options.tools,
    toolChoice: options.toolChoice,
    config: options.config,
    output: options.output,
    resume: null, // Clear resume as we handled it
    returnToolRequests: options.returnToolRequests,
    maxTurns: options.maxTurns,
    stepName: options.stepName,
  );

  // Recursively call composedGenerate for the next turn
  return composedGenerate(nextOptions, currentTurn + 1);
}

Future<GenerateResponseHelper> runGenerateAction(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx, {
  List<GenerateMiddlewareOneof>? middleware,
  bool skipTelemetry = false,
}) async {
  if (skipTelemetry) {
    return _runGenerateAction(registry, options, ctx, middleware: middleware);
  }
  return runInNewSpan(
    'generate',
    (telemetryContext) {
      return _runGenerateAction(registry, options, ctx, middleware: middleware);
    },
    input: options,
    actionType: 'util',
  );
}

Future<GenerateResponseHelper> _runGenerateAction(
  Registry registry,
  GenerateActionOptions options,
  ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx, {
  List<GenerateMiddlewareOneof>? middleware,
}) async {
  var resolvedModelName = options.model;
  var resolvedConfigMap = options.config;

  if (resolvedModelName == null) {
    final defaultModel = registry.lookupValue<ModelRef>(
      'defaultModel',
      'defaultModel',
    );
    if (defaultModel != null) {
      resolvedModelName = defaultModel.name;
      if (resolvedConfigMap == null && defaultModel.config != null) {
        resolvedConfigMap = _configToMap(defaultModel.config);
      }
    }
  }

  options = GenerateActionOptions.fromJson({
    ...options.toJson(),
    'model': resolvedModelName,
    'config': resolvedConfigMap,
  });

  final resolved = _resolveMiddleware(registry, middleware);
  final generateRegistry = resolved.registry;
  final resolvedMiddleware = resolved.middleware;

  late Future<GenerateResponseHelper> Function(
    GenerateActionOptions opts,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> c,
    int currentTurn,
  )
  composedGenerate;

  Future<GenerateResponseHelper> coreGenerate(
    GenerateActionOptions opts,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> c,
    int currentTurn,
  ) async {
    final resumeRestart = opts.resume?.restart ?? [];
    final toolStatus = <String, _ToolStatus>{};

    if (resumeRestart.isNotEmpty) {
      final execution = await _executeTools(
        generateRegistry,
        resumeRestart.cast<ToolRequestPart>().toList(),
        c.context,
        middleware: resolvedMiddleware,
      );
      toolStatus.addAll(execution.toolStatus);

      if (execution.interrupted) {
        // If a restarted tool interrupts, we need to bubble it up without calling the model
        final newResponse = _buildInterruptedResponse(
          opts.messages.last,
          toolStatus,
          finishMessage:
              'One or more restarted tools triggered interrupts while resuming generation. The model was not called.',
        );

        return GenerateResponseHelper(
          newResponse,
          request: ModelRequest(messages: opts.messages, config: opts.config),
          output: null,
        );
      }

      // Map outputs back to respondents
      final respond = opts.resume?.respond?.toList() ?? [];
      for (final entry in toolStatus.entries) {
        if (entry.value.interrupt == null && entry.value.output != null) {
          final reqPart = resumeRestart.firstWhere((p) {
            final t = p.toolRequest;
            return (t.ref ?? t.name) == entry.key;
          });
          respond.add(
            ToolResponsePart(
              toolResponse: ToolResponse(
                ref: reqPart.toolRequest.ref,
                name: reqPart.toolRequest.name,
                output: entry.value.output,
              ),
            ),
          );
        }
      }
      opts = GenerateActionOptions(
        model: opts.model,
        messages: opts.messages,
        config: opts.config,
        tools: opts.tools,
        toolChoice: opts.toolChoice,
        returnToolRequests: opts.returnToolRequests,
        maxTurns: opts.maxTurns,
        output: opts.output,
        resume: GenerateResumeOptions(
          respond: respond,
          restart: [],
          metadata: opts.resume?.metadata,
        ),
      );

      return composedGenerate(opts, c, currentTurn);
    }

    return _runGenerateLoop(
      generateRegistry,
      opts,
      c,
      resolvedMiddleware: resolvedMiddleware,
      composedGenerate: (opt, ct) => composedGenerate(opt, c, ct),
      currentTurn: currentTurn,
    );
  }

  composedGenerate = resolvedMiddleware.reversed.fold(
    coreGenerate,
    // Add currentTurn here since GenerateMiddleware.generate doesn't take it!
    (next, mw) =>
        (o, c, ct) => mw.generate(o, c, (no, nctx) => next(no, nctx, ct)),
  );

  return composedGenerate(options, ctx, 0);
}

typedef GenerateMiddlewareOneof = ({
  GenerateMiddleware? middlewareInstance,
  GenerateMiddlewareRef? middlewareRef,
});

/// A helper that takes loose generate arguments, contstructs GenerateActionOptions
/// and runs the generate action.
Future<GenerateResponseHelper> generateHelper<CustomOptions>(
  Registry registry, {
  String? prompt,
  List<Message>? messages,
  ModelRef<CustomOptions>? model,
  CustomOptions? config,
  List<String>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateActionOutputConfig? output,
  Map<String, dynamic>? context,
  StreamingCallback<GenerateResponseChunk>? onChunk,
  List<GenerateMiddlewareOneof>? middleware,

  /// List of interrupt responses to resolve interrupts.
  List<InterruptResponse>? resume,

  /// List of tool requests to restart during an interrupted generation session.
  List<ToolRequestPart>? restart,
}) async {
  if (messages == null && prompt == null) {
    throw ArgumentError('prompt or messages must be provided');
  }

  GenerateResumeOptions? resolvedResume;
  if (resume != null || restart != null) {
    resolvedResume = GenerateResumeOptions(
      respond: resume
          ?.where((r) => r.output != null)
          .map(
            (r) => ToolResponsePart(
              toolResponse: ToolResponse(
                ref: r.ref,
                name: r.name,
                output: r.output,
              ),
            ),
          )
          .toList(),
      restart: [
        ...?resume
            ?.where((r) => r.output == null)
            .map((r) => r.toolRequestPart),
        ...?restart,
      ],
    );
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

  var resolvedModelName = model?.name;
  var resolvedConfigMap = _configToMap(config);

  if (resolvedConfigMap == null && model?.config != null) {
    resolvedConfigMap = _configToMap(model!.config);
  }

  final format = resolveFormat(registry, output);
  final chunkParser = format?.handler(output?.jsonSchema).parseChunk;
  final previousChunks = <ModelResponseChunk>[];

  return await runGenerateAction(
    registry,
    GenerateActionOptions(
      model: resolvedModelName,
      messages: resolvedMessages,
      config: resolvedConfigMap,
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
            previousChunks: List.from(previousChunks),
            output: parseChunkOutput(chunk, previousChunks, chunkParser),
          );
          previousChunks.add(chunk);
          onChunk(wrapped);
        }
      },
      context: context,
      inputStream: null,
      init: null,
    ),
    middleware: middleware,
  );
}

dynamic _parseOutput(Message? message, MessageParser? parser) {
  if (parser != null && message != null) {
    return parser(message);
  }
  return null;
}

Output? parseChunkOutput<Output>(
  ModelResponseChunk chunk,
  List<ModelResponseChunk> previousChunks,
  ChunkParser<Output>? parser,
) {
  if (parser != null) {
    final temp = GenerateResponseChunk<Output>(
      chunk,
      previousChunks: previousChunks,
      output: null,
    );
    return parser(temp);
  }
  final dataPart = chunk.content.where((p) => p.isData).firstOrNull?.dataPart;
  if (dataPart != null && dataPart.data != null) {
    return dataPart.data as Output?;
  }
  return null;
}

Future<({ModelRequest? request, ModelResponse? interruptedResponse})>
_resolveResume(
  Registry registry,
  ModelRequest request,
  GenerateResumeOptions resume,
  Map<String, dynamic>? context,
  List<GenerateMiddleware>? middleware,
) async {
  final lastMessage = request.messages.lastOrNull;
  if (lastMessage?.role != Role.model ||
      !(lastMessage?.content.any((p) => p.isToolRequest) ?? false)) {
    return (request: request, interruptedResponse: null);
  }

  final resumeRespond = resume.respond ?? [];
  final toolResponses = <Part>[];
  final newContent = <Part>[];

  for (final part in lastMessage!.content) {
    if (!part.isToolRequest) {
      newContent.add(part);
      continue;
    }

    final req = part.toolRequestPart!.toolRequest;
    final meta = part.metadata ?? {};

    // Resolve output
    dynamic output = meta['pendingOutput'];
    if (output == null) {
      final match = resumeRespond.firstWhere(
        (r) => r.toolResponse.ref == req.ref && r.toolResponse.name == req.name,
        orElse: () => ToolResponsePart(
          toolResponse: ToolResponse(ref: '', name: '', output: null),
        ),
      );
      if (match.toolResponse.name.isNotEmpty) {
        output = match.toolResponse.output;
      }
    }

    if (output == null) {
      throw GenkitException(
        'Unresolved tool request ${req.name}. You must supply replies or restarts for all interrupted tool requests.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

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
    if (newMeta.remove('interrupt') != null) {
      newMeta['resolvedInterrupt'] = true;
    }

    newContent.add(
      ToolRequestPart(
        toolRequest: req,
        custom: part.custom,
        data: part.data,
        metadata: newMeta,
      ),
    );
  }

  final newMessage = Message(
    role: lastMessage.role,
    content: newContent,
    metadata: lastMessage.metadata,
  );

  final newMessages = List<Message>.from(request.messages);
  newMessages.removeLast();
  newMessages.add(newMessage);
  newMessages.add(Message(role: Role.tool, content: toolResponses));

  return (
    request: ModelRequest(
      messages: newMessages,
      config: request.config,
      tools: request.tools,
      toolChoice: request.toolChoice,
      output: request.output,
    ),
    interruptedResponse: null,
  );
}

ModelResponse _buildInterruptedResponse(
  Message lastMessage,
  Map<String, _ToolStatus> toolStatus, {
  ModelResponse? originalResponse,
  String? finishMessage,
}) {
  final newContent = <Part>[];
  for (final part in lastMessage.content) {
    if (part.isToolRequest) {
      final req = part.toolRequestPart!.toolRequest;
      final ref = req.ref ?? req.name;
      final status = toolStatus[ref];
      final meta = Map<String, dynamic>.from(part.metadata ?? {});

      if (status?.interrupt != null) {
        meta['interrupt'] = status!.interrupt!.interrupt;
      } else if (status?.output != null) {
        meta['pendingOutput'] = status!.output;
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
    role: lastMessage.role,
    content: newContent,
    metadata: lastMessage.metadata,
  );

  return ModelResponse(
    message: newMessage,
    finishReason: FinishReason.interrupted,
    finishMessage: finishMessage ?? originalResponse?.finishMessage,
    latencyMs: originalResponse?.latencyMs,
    usage: originalResponse?.usage,
    custom: originalResponse?.custom,
    raw: originalResponse?.raw,
    request: originalResponse?.request,
    operation: originalResponse?.operation,
  );
}

Future<
  ({
    List<Part> toolResponses,
    bool interrupted,
    Map<String, _ToolStatus> toolStatus,
  })
>
_executeTools(
  Registry registry,
  List<ToolRequestPart> toolRequests,
  Map<String, dynamic>? context, {
  List<GenerateMiddleware>? middleware,
}) async {
  final toolResponses = <ToolResponsePart>[];
  final toolStatus = <String, _ToolStatus>{};
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

    Future<ToolResponsePart> coreTool(
      ToolRequestPart req,
      ActionFnArg<void, dynamic, void> c,
    ) async {
      final out = await tool.runRaw(req.toolRequest.input, context: c.context);
      return ToolResponsePart(
        toolResponse: ToolResponse(
          ref: req.toolRequest.ref,
          name: req.toolRequest.name,
          output: out.result,
        ),
      );
    }

    final composedTool =
        middleware?.reversed.fold(
          coreTool,
          (next, mw) =>
              (r, c) => mw.tool(r, c, next),
        ) ??
        coreTool;

    try {
      final toolResponsePart = await runZoned(
        () => composedTool(toolRequest, (
          streamingRequested: false,
          sendChunk: (_) {},
          context: context,
          inputStream: null,
          init: null,
        )),
        zoneValues: {ToolRequestPart: toolRequest},
      );
      toolResponses.add(toolResponsePart);
      toolStatus[toolRequest.toolRequest.ref ?? toolRequest.toolRequest.name] =
          (output: toolResponsePart.toolResponse.output, interrupt: null);
    } on ToolInterruptException catch (e) {
      interrupted = true;
      toolStatus[toolRequest.toolRequest.ref ?? toolRequest.toolRequest.name] =
          (output: null, interrupt: e);
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

Map<String, dynamic>? _configToMap(dynamic config) {
  if (config == null) return null;
  return config is Map
      ? config as Map<String, dynamic>
      : (config as dynamic)?.toJson() as Map<String, dynamic>?;
}
