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

import '../../client.dart';
import '../../genkit.dart';

/// Defines a remote Genkit model.
Model remoteModel({
  required String name,
  required String url,
  FutureOr<Map<String, String>?> Function(Map<String, dynamic> context)?
  headers,
  ModelInfo? modelInfo,
  http.Client? httpClient,
}) {
  final remoteAction =
      defineRemoteAction<ModelRequest, ModelResponse, ModelResponseChunk, void>(
        url: url,
        httpClient: httpClient,
        inputSchema: ModelRequest.$schema,
        outputSchema: ModelResponse.$schema,
        streamSchema: ModelResponseChunk.$schema,
      );

  return Model(
      name: name,
      fn: (request, context) async {
        if (request == null) {
          throw ArgumentError('Model request cannot be null');
        }

        final resolvedHeaders = await headers?.call(context.context ?? {});

        if (context.streamingRequested) {
          final stream = remoteAction.stream(
            input: request,
            headers: resolvedHeaders,
          );

          await for (final chunk in stream) {
            context.sendChunk(chunk);
          }

          return stream.result;
        }

        return await remoteAction(input: request, headers: resolvedHeaders);
      },
    )
    // No local fallback: a caller that omits [modelInfo] gets `modelMetadata`'s
    // undeclared-model defaults, which withhold `constrained` so the remote
    // model is simulated for rather than sent a schema it never claimed to
    // honour. The remote endpoint is a model action, so its own generate loop
    // — and any fallback in it — never runs for this call.
    ..metadata.addAll(modelMetadata(name, modelInfo: modelInfo).metadata);
}
