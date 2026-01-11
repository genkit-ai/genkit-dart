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
import 'package:genkit/src/ai/generate.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';

export 'package:genkit/src/types.dart';
export 'package:genkit/src/schema_extensions.dart';

Future<GenerateResponse> generate<C>({
  String? prompt,
  List<Message>? messages,
  required Model<C> model,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  JsonExtensionType? outputSchema,
  String? outputFormat,
  bool? outputConstrained,
  String? outputInstructions,
  bool? outputNoInstructions,
  String? outputContentType,
  Map<String, dynamic>? context,
  StreamingCallback<GenerateResponseChunk>? onChunk,
}) async {
  if (outputInstructions != null && outputNoInstructions == true) {
    throw ArgumentError(
      'Cannot set both outputInstructions and outputNoInstructions to true.',
    );
  }

  final registry = Registry();
  registry.register(model);
  tools?.forEach((t) => registry.register(t));
  GenerateActionOutputConfig? outputConfig;
  if (outputSchema != null ||
      outputFormat != null ||
      outputConstrained != null ||
      outputInstructions != null ||
      outputNoInstructions != null ||
      outputContentType != null) {
    outputConfig = GenerateActionOutputConfig({
      if (outputFormat != null) 'format': outputFormat,
      if (outputSchema != null)
        'jsonSchema': outputSchema.jsonSchema as Map<String, dynamic>,
      if (outputConstrained != null) 'constrained': outputConstrained,
      if (outputInstructions != null) 'instructions': outputInstructions,
      if (outputContentType != null) 'contentType': outputContentType,
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
  );
}

ActionStream<GenerateResponseChunk, GenerateResponse> generateStream<C>({
  required Model<C> model,
  String? prompt,
  List<Message>? messages,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  JsonExtensionType? outputSchema,
  String? outputFormat,
  bool? outputConstrained,
  String? outputInstructions,
  bool? outputNoInstructions,
  String? outputContentType,
  Map<String, dynamic>? context,
}) {
  final streamController = StreamController<GenerateResponseChunk>();
  final actionStream = ActionStream<GenerateResponseChunk, GenerateResponse>(
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
