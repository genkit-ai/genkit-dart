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

import 'src/ai/generate.dart';
import 'src/ai/generate_middleware.dart';
import 'src/ai/model.dart';
import 'src/ai/tool.dart';
import 'src/core/action.dart';
import 'src/core/registry.dart';
import 'src/types.dart';

export 'src/schema_extensions.dart';
export 'src/types.dart';

Future<GenerateResponseHelper> generate<C>({
  String? prompt,
  List<Message>? messages,
  required Model<C> model,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  SchemanticType? outputSchema,
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
  /// The list should contain [InterruptResponse]s for each interrupted tool request
  /// that is providing an explicit output reply.
  ///
  /// Example (providing a response):
  /// ```dart
  /// resume: [
  ///   InterruptResponse(interruptPart, 'User Answer')
  /// ]
  /// ```
  List<InterruptResponse>? interruptRespond,

  /// Optional list of tool requests to restart during an interrupted generation session.
  ///
  /// Restarts the execution of the specified tool part instead of providing a reply.
  /// Example:
  /// ```dart
  /// restart: [interruptPart]
  /// ```
  List<ToolRequestPart>? interruptRestart,
}) async {
  if (outputInstructions != null && outputNoInstructions == true) {
    throw ArgumentError(
      'Cannot set both outputInstructions and outputNoInstructions to true.',
    );
  }

  final registry = Registry();
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
      if (outputSchema != null)
        'jsonSchema': outputSchema.jsonSchema as Map<String, dynamic>,
      'constrained': ?outputConstrained,
      'instructions': ?outputInstructions,
      'contentType': ?outputContentType,
      if (outputNoInstructions == true) 'instructions': false,
    });
  }
  return generateHelper(
    registry,
    prompt: prompt,
    messages: messages,
    model: model,
    config: config,
    tools: tools?.map((t) => t.name).toList(),
    toolChoice: toolChoice,
    returnToolRequests: returnToolRequests,
    maxTurns: maxTurns,
    output: outputConfig,
    context: context,
    onChunk: onChunk,
    middlewares: use,
    resume: interruptRespond,
    restart: interruptRestart,
  );
}

ActionStream<GenerateResponseChunk, GenerateResponseHelper> generateStream<C>({
  required Model<C> model,
  String? prompt,
  List<Message>? messages,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  SchemanticType? outputSchema,
  String? outputFormat,
  bool? outputConstrained,
  String? outputInstructions,
  bool? outputNoInstructions,
  String? outputContentType,
  Map<String, dynamic>? context,
  List<GenerateMiddleware>? use,
  List<InterruptResponse>? interruptRespond,
  List<ToolRequestPart>? interruptRestart,
}) {
  final streamController = StreamController<GenerateResponseChunk>();
  final actionStream =
      ActionStream<GenerateResponseChunk, GenerateResponseHelper>(
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
        onChunk: (chunk) {
          if (streamController.isClosed) return;
          streamController.add(chunk);
        },
        use: use,
        interruptRespond: interruptRespond,
        interruptRestart: interruptRestart,
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
