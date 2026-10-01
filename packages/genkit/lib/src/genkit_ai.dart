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

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import 'ai/embedder.dart';
import 'ai/generate.dart';
import 'ai/generate_middleware.dart';
import 'ai/generate_types.dart';
import 'ai/model.dart';
import 'ai/tool.dart';
import 'core/action.dart';
import 'core/cancellation.dart';
import 'core/registry.dart';
import 'exception.dart';
import 'o11y/instrumentation.dart';
import 'schema.dart';
import 'types.dart';

/// Encapsulates Genkit's AI APIs.
///
/// [GenkitAI] exposes the model-orchestration veneer ([generate],
/// [generateStream], [embed], [run]) on top of a
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
    return runInNewSpan(
      name,
      (_) => fn(),
      actionType: ActionType.flowStep.value,
    );
  }

  /// Generates a response using the specified model and context.
  Future<GenerateResult<Output>> generate<Output, CustomOptions>({
    String? system,
    String? prompt,
    List<Part>? promptParts,
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    ToolChoice? toolChoice,
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

    /// Cooperative cancellation token, observed by the model call, tools, and
    /// middleware to abort generation.
    CancellationToken? cancel,

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
    final resolved = resolveInlineTools(
      registry,
      tools: tools,
      toolNames: toolNames,
    );
    final result = await generateHelper(
      resolved.registry,
      system: system,
      prompt: prompt,
      promptParts: promptParts,
      messages: messages,
      model: model,
      config: config,
      tools: resolved.toolNames,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: outputConfig,
      context: context,
      cancel: cancel,
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
                    c.modelChunk,
                    previousChunks: List.from(c.previousChunks),
                    output: _parsePartial(outputSchema, c.output),
                  ),
                );
              } else {
                onChunk.call(
                  GenerateResponseChunk<Output>(
                    c.modelChunk,
                    previousChunks: List.from(c.previousChunks),
                    // Partial output that does not fit Output yet is not a
                    // failure; the chunk's output is just unavailable.
                    output: c.output is Output ? c.output as Output : null,
                  ),
                );
              }
            },
    );
    if (outputSchema != null) {
      return GenerateResult(
        result.modelResponse,
        request: result.modelRequest,
        // An aborted response carries no output; guard the parse so the
        // aborted response (with its resumable history) survives structured
        // output calls too.
        output: result.output == null
            ? null
            : outputSchema.parse(result.output),
        cause: result.cause,
      );
    } else {
      return GenerateResult(
        result.modelResponse,
        request: result.modelRequest,
        output: castOutput<Output>(result.output),
        cause: result.cause,
      );
    }
  }

  /// Streams a response from the specified model.
  ActionStream<GenerateResponseChunk<Output>, GenerateResult<Output>>
  generateStream<Output, CustomOptions>({
    String? system,
    String? prompt,
    List<Part>? promptParts,
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    ToolChoice? toolChoice,
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
    CancellationToken? cancel,
    List<InterruptResponse>? interruptRespond,
    List<ToolRequestPart>? interruptRestart,
  }) {
    final streamController = StreamController<GenerateResponseChunk<Output>>();
    final actionStream =
        ActionStream<GenerateResponseChunk<Output>, GenerateResult<Output>>(
          streamController.stream,
        );

    generate(
          system: system,
          prompt: prompt,
          promptParts: promptParts,
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
          cancel: cancel,
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

  /// Embeds a single [document] or a list of [documents] (exactly one must be
  /// given). An empty [documents] list is passed through to the embedder.
  ///
  /// Typically returns one [Embedding] per document, in order:
  ///
  /// ```dart
  /// final [vector] = await ai.embed(embedder: e, document: doc);
  /// final vectors = await ai.embed(embedder: e, documents: [a, b]);
  /// ```
  ///
  /// Some embedders return several embeddings per document (e.g. Vertex AI's
  /// `multimodalembedding` returns one per modality), so the result is not
  /// always 1:1 with the input. Such embedders identify the source document
  /// in each embedding's metadata (e.g. `documentIndex`); check the embedder's
  /// docs before destructuring or zipping by position.
  Future<List<Embedding>> embed<CustomOptions>({
    required EmbedderRef<CustomOptions> embedder,
    DocumentData? document,
    List<DocumentData>? documents,
    CustomOptions? options,
  }) async {
    if ((document == null) == (documents == null)) {
      throw ArgumentError(
        'Provide exactly one of document or documents to embed.',
      );
    }
    final action = await registry.lookupAction(.embedder, embedder.name);
    if (action == null) {
      throw GenkitException(
        'Embedder ${embedder.name} not found',
        status: StatusCode.notFound,
      );
    }

    final resolvedOptions = options is Map
        ? options as Map<String, dynamic>
        : (options as dynamic)?.toJson() as Map<String, dynamic>?;

    final req = EmbedRequest(
      input: documents ?? [document!],
      options: resolvedOptions,
    );

    final response = await action(req) as EmbedResponse;
    return response.embeddings;
  }
}

/// Parses a streamed chunk's *partial* output against [schema].
///
/// While JSON is still arriving the partial value is often incomplete (e.g.
/// `{"a": null}` for a map of strings), and a strict schema rejects it. That is
/// not a generation failure: the chunk's typed output is just not available
/// yet, so it is `null`. The final response is still parsed strictly.
Output? _parsePartial<Output>(SchemanticType<Output> schema, Object? raw) {
  if (raw == null) return null;
  try {
    return schema.parse(raw);
  } on Object {
    return null;
  }
}

/// Resolves inline [Tool] objects into a (possibly child) registry plus the
/// combined tool-name list, so callers can pass ad-hoc tools alongside
/// registered tool names.
///
/// Returns a new child registry with the inline tools registered when any are
/// supplied; otherwise the original registry is returned unchanged.
@internal
({Registry registry, List<String>? toolNames}) resolveInlineTools(
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
