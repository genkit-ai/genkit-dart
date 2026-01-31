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

import 'package:schemantic/schemantic.dart';

import 'src/ai/formatters/formatters.dart';
import 'src/ai/generate.dart';
import 'src/ai/generate_middleware.dart';
import 'src/ai/model.dart';
import 'src/ai/tool.dart';
import 'src/core/action.dart';
import 'src/core/flow.dart';
import 'src/core/plugin.dart';
import 'src/core/reflection.dart';
import 'src/core/reflection_v2.dart';
import 'src/core/registry.dart';
import 'src/exception.dart';
import 'src/o11y/instrumentation.dart';
import 'src/schema.dart';
import 'src/types.dart';
import 'src/utils.dart';

export 'package:genkit/src/ai/formatters/types.dart';
export 'package:genkit/src/ai/generate.dart'
    show GenerateBidiSession, GenerateResponseChunk, GenerateResponseHelper;
export 'package:genkit/src/ai/generate_middleware.dart' show GenerateMiddleware;
export 'package:genkit/src/ai/middleware/retry.dart' show RetryMiddleware;
export 'package:genkit/src/ai/model.dart'
    show BidiModel, Model, ModelRef, modelMetadata, modelRef;
export 'package:genkit/src/ai/tool.dart' show Tool, ToolFn, ToolFnArgs;
export 'package:genkit/src/core/action.dart'
    show Action, ActionFnArg, ActionMetadata;
export 'package:genkit/src/core/flow.dart';
export 'package:genkit/src/core/plugin.dart' show GenkitPlugin;
export 'package:genkit/src/exception.dart' show GenkitException, StatusCodes;
export 'package:genkit/src/o11y/otlp_http_exporter.dart'
    show configureCollectorExporter;
export 'package:genkit/src/schema_extensions.dart';
export 'package:genkit/src/types.dart';

bool _isDevEnv() {
  return getEnvVar('GENKIT_ENV') == 'dev';
}

class Genkit {
  final Registry registry = Registry();
  Object? _reflectionServer;
  Action<GenerateActionOptions, ModelResponse, ModelResponseChunk, void>?
  _generateAction;

  Genkit({
    List<GenkitPlugin> plugins = const [],
    bool? isDevEnv,
    int? reflectionPort,
  }) {
    // Register plugins
    for (final plugin in plugins) {
      registry.registerPlugin(plugin);
    }

    // Register default formats
    configureFormats(registry);

    if (isDevEnv ?? _isDevEnv()) {
      final v2ServerUrl = getEnvVar('GENKIT_REFLECTION_V2_SERVER');
      if (v2ServerUrl != null) {
        final server = ReflectionServerV2(registry, url: v2ServerUrl);
        server.start();
        _reflectionServer = server;
      } else {
        final server = ReflectionServer(registry, port: reflectionPort ?? 3110);
        server.start();
        _reflectionServer = server;
      }
    }

    _generateAction = defineGenerateAction(registry);

    registry.register(_generateAction!);
  }

  Future<void> shutdown() async {
    if (_reflectionServer is ReflectionServer) {
      await (_reflectionServer as ReflectionServer).stop();
    } else if (_reflectionServer is ReflectionServerV2) {
      await (_reflectionServer as ReflectionServerV2).stop();
    }
  }

  Future<O> run<O>(String name, Future<O> Function() fn) {
    return runInNewSpan(name, (_) => fn());
  }

  Flow<I, O, S, Init> defineFlow<I, O, S, Init>({
    required String name,
    required ActionFn<I, O, S, Init> fn,
    SchemanticType<I>? inputSchema,
    SchemanticType<O>? outputSchema,
    SchemanticType<S>? streamSchema,
    SchemanticType<Init>? initSchema,
  }) {
    final flow = Flow(
      name: name,
      fn: (input, context) {
        if (input == null && inputSchema != null && null is! I) {
          throw ArgumentError('Flow "$name" requires a non-null input.');
        }
        return fn(input as I, context);
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
    required BidiActionFn<I, O, S, Init> fn,
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

  Tool<I, O> defineTool<I, O, S>({
    required String name,
    required String description,
    required ToolFn<I, O> fn,
    SchemanticType<I>? inputSchema,
    SchemanticType<O>? outputSchema,
    SchemanticType<S>? streamSchema,
  }) {
    final tool = Tool(
      name: name,
      description: description,
      fn: (input, context) {
        if (input == null && inputSchema != null && null is! I) {
          throw ArgumentError('Tool "$name" requires a non-null input.');
        }
        return fn(input, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
    );
    registry.register(tool);
    return tool;
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

  Future<GenerateBidiSession> generateBidi({
    required String model,
    dynamic config,
    List<String>? tools,
    String? system,
  }) {
    return runGenerateBidi(
      registry,
      modelName: model,
      config: config,
      tools: tools,
      system: system,
    );
  }

  Future<GenerateResponseHelper<S>> generate<C, S>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<S>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    StreamingCallback<GenerateResponseChunk>? onChunk,
    List<GenerateMiddleware>? use,
    /// Optional data to resume an interrupted generation session.
    ///
    /// The map should contain a `respond` key with a list of tool responses, matching
    /// the structure of the interrupted tool requests.
    ///
    /// Example:
    /// ```dart
    /// resume: {
    ///   'respond': [
    ///     {
    ///       'ref': 'toolRef', // or 'name'
    ///       'output': 'User Answer'
    ///     }
    ///   ]
    /// }
    /// ```
    Map<String, dynamic>? resume,
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
    final rawResponse = await generateHelper(
      registry,
      prompt: prompt,
      messages: messages,
      model: model,
      config: config,
      tools: tools,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: outputConfig,
      context: context,
      middlewares: use,
      resume: resume,
      onChunk: (c) {
        if (outputSchema != null) {
          onChunk?.call(
            GenerateResponseChunk<S>(
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
      return rawResponse as GenerateResponseHelper<S>;
    }
  }

  ActionStream<GenerateResponseChunk<S>, GenerateResponseHelper<S>>
  generateStream<C, S>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    SchemanticType<S>? outputSchema,
    String? outputFormat,
    bool? outputConstrained,
    String? outputInstructions,
    bool? outputNoInstructions,
    String? outputContentType,
    Map<String, dynamic>? context,
    List<GenerateMiddleware>? use,
    Map<String, dynamic>? resume,
  }) {
    final streamController = StreamController<GenerateResponseChunk<S>>();
    final actionStream =
        ActionStream<GenerateResponseChunk<S>, GenerateResponseHelper<S>>(
          streamController.stream,
        );

    generate(
          prompt: prompt,
          messages: messages,
          model: model,
          config: config,
          tools: tools,
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
          use: use,
          resume: resume,
          onChunk: (chunk) {
            if (streamController.isClosed) return;
            streamController.add(chunk as GenerateResponseChunk<S>);
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
