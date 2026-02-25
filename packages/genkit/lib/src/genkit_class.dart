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

import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import 'ai/embedder.dart';
import 'ai/formatters/formatters.dart';
import 'ai/generate.dart';
import 'ai/generate_bidi.dart';
import 'ai/generate_middleware.dart';
import 'ai/generate_types.dart';
import 'ai/model.dart';
import 'ai/prompt.dart';
import 'ai/resource.dart';
import 'ai/tool.dart';
import 'client/client.dart';
import 'core/action.dart';
import 'core/flow.dart';
import 'core/plugin.dart';
import 'core/reflection.dart';
import 'core/registry.dart';
import 'exception.dart';
import 'o11y/instrumentation.dart';
import 'o11y/otlp_http_exporter.dart' show configureCollectorExporter;
import 'schema.dart';
import 'types.dart';
import 'utils.dart';

bool _isDevEnv() {
  return getConfigVar('GENKIT_ENV') == 'dev';
}

/// The main entry point for creating Genkit applications.
///
/// The [Genkit] instance initializes the framework, loads [GenkitPlugin]s, and
/// provides a central registry for defining Genkit primitives. It exposes
/// methods to create AI actions, such as [defineFlow], [defineTool],
/// [definePrompt], and [defineResource].
///
/// If `isDevEnv` is true or the `GENKIT_ENV` environment variable is set to
/// 'dev', initializing [Genkit] also starts a local reflection server that
/// communicates with the Genkit Developer UI.
final class Genkit {
  final Registry registry = Registry();
  ReflectionServerHandle? _reflectionServer;

  late final GenerateAction _generateAction;

  Genkit({
    List<GenkitPlugin> plugins = const [],
    bool? isDevEnv,
    int? reflectionPort,
  }) {
    configureCollectorExporter();

    // Register plugins
    for (final plugin in plugins) {
      registry.registerPlugin(plugin);
      for (final mw in plugin.middleware()) {
        registry.registerValue('middleware', mw.name, mw);
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

  Future<Output> run<Output>(String name, Future<Output> Function() fn) {
    return runInNewSpan(name, (_) => fn());
  }

  Flow<Input, Output, Chunk, Init> defineFlow<Input, Output, Chunk, Init>({
    required String name,
    required ActionFn<Input, Output, Chunk, Init> fn,
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
        return fn(input as Input, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  Flow<Input, Output, Chunk, Init> defineBidiFlow<Input, Output, Chunk, Init>({
    required String name,
    required BidiActionFn<Input, Output, Chunk, Init> fn,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
    SchemanticType<Chunk>? streamSchema,
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
        return fn(context.inputStream!, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  Tool<Input, Output> defineTool<Input, Output>({
    required String name,
    required String description,
    required ToolFn<Input, Output> fn,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
  }) {
    final tool = Tool(
      name: name,
      description: description,
      fn: fn,
      inputSchema: inputSchema,
      outputSchema: outputSchema,
    );
    registry.register(tool);
    return tool;
  }

  PromptAction<Input> definePrompt<Input>({
    required String name,
    String? description,
    SchemanticType<Input>? inputSchema,
    required PromptFn<Input> fn,
    Map<String, dynamic>? metadata,
  }) {
    final prompt = PromptAction<Input>(
      name: name,
      description: description,
      inputSchema: inputSchema,
      fn: fn,
      metadata: metadata,
    );
    registry.register(prompt);
    return prompt;
  }

  ResourceAction defineResource({
    String? name,
    String? uri,
    String? template,
    String? description,
    Map<String, dynamic>? metadata,
    required ResourceFn fn,
  }) {
    final resourceName = name ?? uri ?? template;
    if (resourceName == null) {
      throw GenkitException(
        'Resource must specify a name, uri, or template.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final resourceMetadata = <String, dynamic>{
      ...?metadata,
      'resource': {'uri': uri, 'template': template},
    };
    final resource = ResourceAction(
      name: resourceName,
      description: description,
      metadata: resourceMetadata,
      matches: createResourceMatcher(uri: uri, template: template),
      fn: fn,
    );
    registry.register(resource);
    return resource;
  }

  Model defineModel({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
  }) {
    final model = Model(
      name: name,
      fn: (input, context) {
        return fn(input!, context);
      },
    );
    registry.register(model);
    return model;
  }

  BidiModel defineBidiModel({
    required String name,
    required BidiActionFn<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      ModelRequest
    >
    fn,
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
        return fn(context.inputStream!, context);
      },
    );
    registry.register(model);
    return model;
  }

  /// Defines a remote Genkit model.
  Model defineRemoteModel({
    required String name,
    required String url,
    Map<String, String>? Function(Map<String, dynamic> context)? headers,
    ModelInfo? modelInfo,
    http.Client? httpClient,
  }) {
    final remoteAction =
        defineRemoteAction<
          ModelRequest,
          ModelResponse,
          ModelResponseChunk,
          void
        >(
          url: url,
          httpClient: httpClient,
          inputSchema: ModelRequest.$schema,
          outputSchema: ModelResponse.$schema,
          streamSchema: ModelResponseChunk.$schema,
        );

    return defineModel(
        name: name,
        fn: (input, context) async {
          if (context.streamingRequested) {
            final stream = remoteAction.stream(
              input: input,
              headers: headers?.call(context.context ?? {}),
            );

            await for (final chunk in stream) {
              context.sendChunk(chunk);
            }

            return stream.result;
          }

          return await remoteAction(
            input: input,
            headers: headers?.call(context.context ?? {}),
          );
        },
      )
      ..metadata.addAll(
        modelMetadata(
          name,
          modelInfo:
              modelInfo ??
              ModelInfo(
                supports: {
                  'multiturn': true,
                  'media': true,
                  'tools': true,
                  'toolChoice': true,
                  'systemRole': true,
                  'constrained': true,
                },
              ),
        ).metadata,
      );
  }

  Embedder defineEmbedder({
    required String name,
    required ActionFn<EmbedRequest, EmbedResponse, void, void> fn,
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

  Future<List<Embedding>> embedMany<CustomOptions>({
    required EmbedderRef<CustomOptions> embedder,
    required List<DocumentData> documents,
    CustomOptions? options,
  }) async {
    final action = await registry.lookupAction('embedder', embedder.name);
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

  Future<List<Embedding>> embed<CustomOptions>({
    required EmbedderRef<CustomOptions> embedder,
    DocumentData? document,
    List<DocumentData>? documents,
    CustomOptions? options,
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
    final resolved = _resolveTools(
      registry,
      tools: tools,
      toolNames: toolNames,
    );
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
    Registry registry, {
    List<Tool>? tools,
    List<String>? toolNames,
  }) {
    if ((tools == null || tools.isEmpty) &&
        (toolNames == null || toolNames.isEmpty)) {
      return (registry: registry, toolNames: null);
    }

    final resolvedToolNames = <String>[...?toolNames];

    if (tools == null || tools.isEmpty) {
      return (registry: registry, toolNames: resolvedToolNames);
    }

    final childRegistry = Registry.childOf(registry);
    for (final tool in tools) {
      childRegistry.register(tool);
      if (!resolvedToolNames.contains(tool.name)) {
        resolvedToolNames.add(tool.name);
      }
    }
    return (registry: childRegistry, toolNames: resolvedToolNames);
  }

  Future<GenerateResponseHelper<Output>> generate<CustomOptions, Output>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<CustomOptions> model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<Output>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    StreamingCallback<GenerateResponseChunk<Output>>? onChunk,
    List<GenerateMiddlewareRef>? use,

    /// Optional data to resume an interrupted generation session.
    ///
    /// The list should contain [InterruptResponse]s for each interrupted tool request
    /// that is providing an explicit output reply.
    ///
    /// Example (providing a response):
    /// ```dart
    /// interruptRespond: [
    ///   InterruptResponse(interruptPart, 'User Answer')
    /// ]
    /// ```
    List<InterruptResponse>? interruptRespond,

    /// Optional list of tool requests to restart during an interrupted generation session.
    ///
    /// Restarts the execution of the specified tool part instead of providing a reply.
    /// Example:
    /// ```dart
    /// interruptRestart: [interruptPart]
    /// ```
    List<ToolRequestPart>? interruptRestart,
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
    final resolved = _resolveTools(
      registry,
      tools: tools,
      toolNames: toolNames,
    );
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
      middleware: use
          ?.map<GenerateMiddlewareOneof>(
            (mw) => (middlewareRef: mw, middlewareInstance: null),
          )
          .toList(),
      resume: interruptRespond,
      restart: interruptRestart,
      onChunk: onChunk == null
          ? null
          : (c) {
              if (outputSchema != null) {
                onChunk.call(
                  GenerateResponseChunk<Output>(
                    c.rawChunk,
                    previousChunks: List.from(c.previousChunks),
                    output: c.output != null
                        ? outputSchema.parse(c.output)
                        : null,
                  ),
                );
              } else {
                onChunk.call(
                  GenerateResponseChunk<Output>(
                    c.rawChunk,
                    previousChunks: List.from(c.previousChunks),
                    output: c.output as Output?,
                  ),
                );
              }
            },
    );
    if (outputSchema != null) {
      return GenerateResponseHelper(
        rawResponse.rawResponse,
        output: outputSchema.parse(rawResponse.output),
      );
    } else {
      return GenerateResponseHelper(
        rawResponse.rawResponse,
        request: rawResponse.modelRequest,
        output: rawResponse.output as Output?,
      );
    }
  }

  ActionStream<GenerateResponseChunk<Output>, GenerateResponseHelper<Output>>
  generateStream<CustomOptions, Output>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<CustomOptions> model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<Output>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    List<GenerateMiddlewareRef>? use,
    List<InterruptResponse>? interruptRespond,
    List<ToolRequestPart>? interruptRestart,
  }) {
    final streamController = StreamController<GenerateResponseChunk<Output>>();
    final actionStream =
        ActionStream<
          GenerateResponseChunk<Output>,
          GenerateResponseHelper<Output>
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
          use: use,
          interruptRespond: interruptRespond,
          interruptRestart: interruptRestart,
          onChunk: (chunk) {
            if (streamController.isClosed) return;
            streamController.add(chunk);
          },
        )
        .then((result) {
          actionStream.setResult(result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((Object e, StackTrace s) {
          actionStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return actionStream;
  }
}
