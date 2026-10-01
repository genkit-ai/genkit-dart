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

/// A lightweight entry point for Genkit.
///
/// Use this library for simple scripts or applications that need to perform
/// generation tasks (using [generate] or [generateStream]) without setting up
/// the full Genkit framework or reflection server.
///
/// This is useful for quick prototyping or simple LLM interactions.
library;

import 'dart:async';

import 'package:schemantic/schemantic.dart';

import 'src/ai/formatters/formatters.dart';
import 'src/ai/generate.dart';
import 'src/ai/generate_middleware.dart';
import 'src/ai/generate_types.dart';
import 'src/ai/model.dart';
import 'src/ai/tool.dart';
import 'src/core/action.dart';
import 'src/core/cancellation.dart';
import 'src/core/registry.dart';
import 'src/types.dart';

export 'src/ai/generate_types.dart'
    show GenerateResponseChunk, GenerateResponseHelper, InterruptResponse;
export 'src/ai/remote_model.dart' show remoteModel;
export 'src/ai/tool.dart'
    show
        Interrupt,
        Tool,
        ToolFn,
        ToolFnArg,
        ToolInterruptResult,
        ToolResponseResult,
        ToolResult;
export 'src/core/action.dart' show ActionStream, StreamingCallback;
export 'src/core/cancellation.dart'
    show CancellationController, CancellationToken;
export 'src/schema_extensions.dart';
export 'src/types.dart';

/// Generates a response from [model].
///
/// Pass [outputSchema] to get typed structured output: `response.output` (and
/// each streamed chunk's `output`) is then parsed into `Output`.
Future<GenerateResponseHelper<Output>> generate<C, Output>({
  String? system,
  String? prompt,
  List<Part>? promptParts,
  List<Message>? messages,
  required Model<C> model,
  C? config,
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
  List<GenerateMiddleware>? use,

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

  final registry = Registry();
  configureFormats(registry);
  registry.register(model);
  tools?.forEach(registry.register);
  GenerateActionOutputConfig? outputConfig;
  if (outputSchema != null ||
      outputFormat != null ||
      outputConstrained != null ||
      outputInstructions != null ||
      outputNoInstructions != null ||
      outputContentType != null) {
    outputConfig = GenerateActionOutputConfig.fromJson({
      'format': ?outputFormat,
      if (outputSchema != null) 'jsonSchema': outputSchema.jsonSchema(),
      'constrained': ?outputConstrained,
      'instructions': ?outputInstructions,
      'contentType': ?outputContentType,
      if (outputNoInstructions == true) 'instructions': false,
    });
  }
  // Parse raw (JSON) output into `Output` when a schema was given; without
  // one, `Output` is whatever the caller asserted (typically `dynamic`).
  Output? parse(Object? raw) => raw == null
      ? null
      : outputSchema != null
      ? outputSchema.parse(raw)
      : raw as Output;

  // A streamed chunk carries *partial* output (e.g. `{"a": null}` while the
  // value is still arriving), which a strict schema may reject. That is not
  // an error: the chunk's output just is not available yet.
  Output? parsePartial(Object? raw) {
    try {
      return parse(raw);
    } on Object {
      return null;
    }
  }

  final raw = await generateHelper(
    registry,
    system: system,
    prompt: prompt,
    promptParts: promptParts,
    messages: messages,
    model: model,
    config: config,
    tools: [...?tools?.map((t) => t.name), ...?toolNames],
    toolChoice: toolChoice,
    returnToolRequests: returnToolRequests,
    maxTurns: maxTurns,
    output: outputConfig,
    context: context,
    cancel: cancel,
    onChunk: onChunk == null
        ? null
        : (c) => onChunk(
            GenerateResponseChunk<Output>(
              c.rawChunk,
              previousChunks: List.from(c.previousChunks),
              output: parsePartial(c.output),
            ),
          ),
    middleware: use
        ?.map((mw) => (middlewareInstance: mw, middlewareRef: null))
        .toList(),
    resume: interruptRespond,
    restart: interruptRestart,
  );
  return GenerateResponseHelper<Output>(
    raw.rawResponse,
    request: raw.modelRequest,
    output: parse(raw.output),
    cause: raw.cause,
  );
}

/// Streams a response from [model]; see [generate].
ActionStream<GenerateResponseChunk<Output>, GenerateResponseHelper<Output>>
generateStream<C, Output>({
  required Model<C> model,
  String? system,
  String? prompt,
  List<Part>? promptParts,
  List<Message>? messages,
  C? config,
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
  List<GenerateMiddleware>? use,
  CancellationToken? cancel,
  List<InterruptResponse>? interruptRespond,
  List<ToolRequestPart>? interruptRestart,
}) {
  final chunks = StreamController<GenerateResponseChunk<Output>>();
  final result = generate<C, Output>(
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
    context: context,
    cancel: cancel,
    onChunk: (chunk) {
      if (!chunks.isClosed) chunks.add(chunk);
    },
    use: use,
    interruptRespond: interruptRespond,
    interruptRestart: interruptRestart,
  );
  // Close the chunk stream once generation settles, surfacing a failure on
  // the stream as well as on `onResult`.
  result.then(
    (_) => chunks.close(),
    onError: (Object e, StackTrace s) {
      chunks
        ..addError(e, s)
        ..close();
    },
  );
  return ActionStream.withResult(chunks.stream, result);
}
