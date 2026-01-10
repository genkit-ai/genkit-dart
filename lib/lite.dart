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
  GenerateOutput? output,
  Map<String, dynamic>? context,
  StreamingCallback<ModelResponseChunk>? onChunk,
}) async {
  final registry = Registry();
  registry.register(model);
  tools?.forEach((t) => registry.register(t));
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
    output: output,
    context: context,
    onChunk: onChunk,
  );
}

ActionStream<ModelResponseChunk, GenerateResponse> generateStream<C>({
  required Model<C> model,
  String? prompt,
  List<Message>? messages,
  C? config,
  List<Tool>? tools,
  String? toolChoice,
  bool? returnToolRequests,
  int? maxTurns,
  GenerateOutput? output,
  Map<String, dynamic>? context,
}) {
  final streamController = StreamController<ModelResponseChunk>();
  final actionStream = ActionStream<ModelResponseChunk, GenerateResponse>(
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
        output: output,
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
