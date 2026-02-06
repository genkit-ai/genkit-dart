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

/// The core Genkit framework library.
///
/// Use this library to define [Flow]s, [Model]s, and [Tool]s.
///
/// This is the main entry point for creating Genkit applications.
library;

import 'dart:async';

import 'package:schemantic/schemantic.dart';

import 'src/ai/embedder.dart';
import 'src/ai/formatters/formatters.dart';
import 'src/ai/generate.dart';
import 'src/ai/generate_middleware.dart';
import 'src/ai/model.dart';
import 'src/ai/tool.dart';
import 'src/core/action.dart';
import 'src/core/flow.dart';
import 'src/core/plugin.dart';
import 'src/core/reflection.dart';
import 'src/core/registry.dart';
import 'src/exception.dart';
import 'src/o11y/instrumentation.dart';
import 'src/schema.dart';
import 'src/types.dart';
import 'src/utils.dart';

export 'package:genkit/src/ai/embedder.dart'
    show Embedder, EmbedderRef, embedderMetadata, embedderRef;
export 'package:genkit/src/ai/formatters/types.dart';
export 'package:genkit/src/ai/generate.dart'
    show
        GenerateBidiSession,
        GenerateResponseChunk,
        GenerateResponseHelper,
        InterruptResponse;
export 'package:genkit/src/ai/generate_middleware.dart'
    show
        GenerateMiddleware,
        GenerateMiddlewareDef,
        GenerateMiddlewareRef,
        defineMiddleware,
        middlewareRef;
export 'package:genkit/src/ai/middleware/retry.dart'
    show RetryMiddleware, RetryOptions, RetryPlugin, retry;
export 'package:genkit/src/ai/model.dart'
    show BidiModel, Model, ModelReference, modelMetadata, modelRef;
export 'package:genkit/src/ai/tool.dart' show Tool, ToolContext, ToolFunction;
export 'package:genkit/src/core/action.dart'
    show Action, ActionMetadata, ActionType, FunctionContext;
export 'package:genkit/src/core/flow.dart';
export 'package:genkit/src/core/plugin.dart' show GenkitPlugin;
export 'package:genkit/src/exception.dart' show GenkitException, StatusCodes;
export 'package:genkit/src/o11y/otlp_http_exporter.dart'
    show configureCollectorExporter;
export 'package:genkit/src/schema_extensions.dart';
export 'package:genkit/src/types.dart';

bool _isDevEnv() {
  return getConfigVar('GENKIT_ENV') == 'dev';
}

class Genkit {
  final Registry registry = Registry();
  ReflectionServerHandle? _reflectionServer;

  late final GenerateAction _generateAction;

  Genkit({
    List<GenkitPlugin> plugins = const [],
    bool? isDevEnv,
    int? reflectionPort,
  }) {
    // Register plugins
    for (final plugin in plugins) {
      registry.registerPlugin(plugin);
      for (final mw in plugin.middleware()) {
        registry.registerValue(ActionType.middleware, mw.name, mw);
      }
    }

    // Register default formats
    configureFormats(registry);

    if (isAllowReflection && (isDevEnv ?? _isDevEnv())) {
      _reflectionServer = startReflectionServer(registry, port: reflectionPort);
    }

    _generateAction = defineGenerateAction(registry);

    registry.register(_generateAction);
  }

  Future<void> shutdown() async {
    if (_reflectionServer != null) {
      await _reflectionServer!.stop();
    }
  }

  Future<Output> run<Output>(String name, Future<Output> Function() function) {
    return runInNewSpan<void, Output>(name, (_) => function());
  }

  Flow<Input, Output, Chunk, Init> defineFlow<Input, Output, Chunk, Init>({
    required String name,
    required ActionFunction<Input, Output, Chunk, Init> function,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
    SchemanticType<Chunk>? streamSchema,
    SchemanticType<Init>? initSchema,
  }) {
    final flow = Flow(
      name: name,
      fn: (input, context) {
        if (input == null && inputSchema != null && null is! Input) {
          throw ArgumentError('Flow "$name" requires a non-null input.');
        }
        return function(input as Input, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  Flow<I, O, S, Init> defineBidiFlow<I, O, S, Init>({
    required String name,
    required BidiActionFunction<I, O, S, Init> function,
    SchemanticType<I>? inputSchema,
    SchemanticType<O>? outputSchema,
    SchemanticType<S>? streamSchema,
    SchemanticType<Init>? initSchema,
  }) {
    final flow = Flow(
      name: name,
      fn: (input, context) {
        if (context.inputStream == null) {
          throw GenkitException(
            'Bidi flow $name called without an input stream',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }
        return function(context.inputStream!, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  Tool<I, O> defineTool<I, O, S>({
    required String name,
    required String description,
    required ToolFunction<I, O> function,
    SchemanticType<I>? inputSchema,
    SchemanticType<O>? outputSchema,
    SchemanticType<S>? streamSchema,
  }) {
    final tool = Tool(
      name: name,
      description: description,
      fn: function,
      inputSchema: inputSchema,
      outputSchema: outputSchema,
    );
    registry.toolRegistry.register(tool);
    return tool;
  }

  Model<void> defineModel({
    required String name,
    required ActionFunction<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      void
    >
    function,
  }) {
    final model = Model(
      name: name,
      fn: (input, context) => function(input!, context),
    );
    registry.register(model);
    return model;
  }

  BidiModel defineBidiModel({
    required String name,
    required BidiActionFunction<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      ModelRequest
    >
    function,
  }) {
    final model = BidiModel(
      name: name,
      fn: (input, context) {
        if (context.inputStream == null) {
          throw GenkitException(
            'Bidi model $name called without an input stream',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }
        return function(context.inputStream!, context);
      },
    );
    registry.register(model);
    return model;
  }

  Embedder defineEmbedder({
    required String name,
    required ActionFunction<EmbedRequest, EmbedResponse, void, void> fn,
  }) {
    final embedder = Embedder(
      name: name,
      fn: (input, context) {
        return fn(input!, context);
      },
    );
    registry.register(embedder);
    return embedder;
  }

  Future<List<Embedding>> embedMany<C>({
    required EmbedderRef<C> embedder,
    required List<DocumentData> documents,
    C? options,
  }) async {
    final action = await registry.lookupAction(
      ActionType.embedder,
      embedder.name,
    );
    if (action == null) {
      throw GenkitException(
        'Embedder ${embedder.name} not found',
        status: StatusCodes.NOT_FOUND,
      );
    }

    final resolvedOptions = options is Map
        ? options as Map<String, dynamic>
        : (options as dynamic)?.toJson() as Map<String, dynamic>?;

    final req = EmbedRequest(input: documents, options: resolvedOptions);

    final response = await action(req) as EmbedResponse;
    return response.embeddings;
  }

  Future<List<Embedding>> embed<C>({
    required EmbedderRef<C> embedder,
    DocumentData? document,
    List<DocumentData>? documents,
    C? options,
  }) async {
    final docs = documents ?? (document != null ? [document] : []);
    if (docs.isEmpty) {
      throw ArgumentError(
        'Either document or documents must be provided to embed.',
      );
    }
    return embedMany(embedder: embedder, documents: docs, options: options);
  }

  Future<GenerateBidiSession> generateBidi({
    required String model,
    dynamic config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? system,
  }) {
    final resolved = _resolveTools(registry, toolNames, tools);
    return runGenerateBidi(
      resolved.registry,
      modelName: model,
      config: config,
      tools: resolved.toolNames,
      system: system,
    );
  }

  /// The tool resolution logic.
  ///
  /// Returns a new registry with embedded tools if necessary.
  ({Registry registry, List<String>? toolNames}) _resolveTools(
    Registry registry,
    Iterable<String>? toolNamesArg,
    Iterable<Tool>? tools,
  ) {
    final toolNames = <String>[];
    final toolsToRegister = <Tool>[];

    for (final t in tools ?? <Tool>[]) {
      toolsToRegister.add(t);
      toolNames.add(t.name);
    }
    toolNames.addAll(toolNamesArg ?? <String>[]);

    if (toolNames.isEmpty) {
      return (registry: registry, toolNames: null);
    }

    if (toolsToRegister.isEmpty) {
      return (registry: registry, toolNames: toolNames);
    }

    final childRegistry = Registry.childOf(registry);
    for (final tool in toolsToRegister) {
      childRegistry.register(tool);
    }
    return (registry: childRegistry, toolNames: toolNames);
  }

  Future<GenerateResponseHelper<OutputSchema>>
  generate<CustomOptionsSchema, OutputSchema>({
    String? prompt,
    List<Message>? messages,
    required ModelReference<CustomOptionsSchema> model,
    CustomOptionsSchema? config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<OutputSchema>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    StreamingCallback<GenerateResponseChunk>? onChunk,

    Iterable<GenerateMiddleware>? middlewares,
    Iterable<GenerateMiddlewareRef>? middlewareRefs,

    /// Optional data to resume an interrupted generation session.
    ///
    /// The list should contain [InterruptResponse]s for each interrupted tool request.
    ///
    /// Example:
    /// ```dart
    /// resume: [
    ///   InterruptResponse(interruptPart, 'User Answer')
    /// ]
    /// ```
    List<InterruptResponse>? resume,
  }) async {
    if (outputInstructions != null && outputNoInstructions == true) {
      throw ArgumentError(
        'Cannot set both outputInstructions and outputNoInstructions to true.',
      );
    }

    GenerateActionOutputConfig? outputConfig;
    if (outputSchema != null ||
        outputFormat != null ||
        outputConstrained != null ||
        outputInstructions != null ||
        outputNoInstructions != null ||
        outputContentType != null) {
      outputConfig = GenerateActionOutputConfig.fromJson({
        'format': ?outputFormat,
        if (outputSchema != null)
          'jsonSchema': toJsonSchema(type: outputSchema),
        'constrained': ?outputConstrained,
        'instructions': ?outputInstructions,
        'contentType': ?outputContentType,
        if (outputNoInstructions == true) 'instructions': false,
      });
    }
    final resolved = _resolveTools(registry, toolNames, tools);
    final rawResponse = await generateHelper(
      resolved.registry,
      prompt: prompt,
      messages: messages,
      model: model,
      config: config,
      tools: resolved.toolNames,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: outputConfig,
      context: context,
      middlewares: middlewares,
      middlewareRefs: middlewareRefs,
      resume: resume,
      onChunk: (c) {
        if (outputSchema != null) {
          onChunk?.call(
            GenerateResponseChunk<OutputSchema>(
              c.rawChunk,
              previousChunks: c.previousChunks,
              output: outputSchema.parse(c.output),
            ),
          );
        } else {
          onChunk?.call(c);
        }
      },
    );
    if (outputSchema != null) {
      return GenerateResponseHelper(
        rawResponse.rawResponse,
        output: outputSchema.parse(rawResponse.output),
      );
    } else {
      return rawResponse as GenerateResponseHelper<OutputSchema>;
    }
  }

  ActionStream<
    GenerateResponseChunk<OutputSchema>,
    GenerateResponseHelper<OutputSchema>
  >
  generateStream<CustomOptionsSchema, OutputSchema>({
    String? prompt,
    List<Message>? messages,
    required ModelReference<CustomOptionsSchema> model,
    CustomOptionsSchema? config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<OutputSchema>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    Iterable<GenerateMiddleware>? middlewares,
    Iterable<GenerateMiddlewareRef>? middlewareRefs,
    List<InterruptResponse>? resume,
  }) {
    final streamController =
        StreamController<GenerateResponseChunk<OutputSchema>>();
    final actionStream =
        ActionStream<
          GenerateResponseChunk<OutputSchema>,
          GenerateResponseHelper<OutputSchema>
        >(streamController.stream);

    generate(
          prompt: prompt,
          messages: messages,
          model: model,
          config: config,
          tools: tools,
          toolNames: toolNames,
          toolChoice: toolChoice,
          returnToolRequests: returnToolRequests,
          maxTurns: maxTurns,
          outputSchema: outputSchema,
          outputFormat: outputFormat,
          outputConstrained: outputConstrained,
          outputInstructions: outputInstructions,
          outputNoInstructions: outputNoInstructions,
          outputContentType: outputContentType,
          context: context,
          middlewares: middlewares,
          middlewareRefs: middlewareRefs,
          resume: resume,
          onChunk: (chunk) {
            if (streamController.isClosed) return;
            streamController.add(chunk as GenerateResponseChunk<OutputSchema>);
          },
        )
        .then((result) {
          actionStream.setResult(result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((e, s) {
          actionStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return actionStream;
  }
}
