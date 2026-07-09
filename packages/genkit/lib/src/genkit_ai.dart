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

import 'ai/embedder.dart';
import 'ai/generate.dart';
import 'ai/generate_bidi.dart';
import 'ai/generate_middleware.dart';
import 'ai/generate_types.dart';
import 'ai/model.dart';
import 'ai/tool.dart';
import 'core/action.dart';
import 'core/registry.dart';
import 'exception.dart';
import 'o11y/instrumentation.dart';
import 'schema.dart';
import 'types.dart';

/// Encapsulates Genkit's AI APIs.
///
/// [GenkitAI] exposes the model-orchestration veneer ([generate],
/// [generateStream], [generateBidi], [embed], [embedMany], [run]) on top of a
/// [Registry]. It only requires a registry to operate, making it cheap to
/// create ephemeral, throwaway instances (the registry holds all the state).
/// The full framework entry point `Genkit` extends this class to add plugin
/// loading, the reflection server, and the various `define*` methods.
base class GenkitAI {
  /// The action registry backing this instance.
  final Registry registry;

  GenkitAI(this.registry);

  /// Runs an AI operation within a new trace span.
  Future<Output> run<Output>(String name, Future<Output> Function() fn) {
    return runInNewSpan(name, (_) => fn());
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

  /// Starts a bi-directional generator session.
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

  /// Generates a response using the specified model and context.
  Future<GenerateResponseHelper<Output>> generate<CustomOptions, Output>({
    String? system,
    String? prompt,
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
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
      system: system,
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

  /// Streams a response from the specified model.
  ActionStream<GenerateResponseChunk<Output>, GenerateResponseHelper<Output>>
  generateStream<CustomOptions, Output>({
    String? system,
    String? prompt,
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
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
          system: system,
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

  /// Embeds multiple documents using the specified embedder.
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

  /// Embeds a single document or a list of documents.
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
}
