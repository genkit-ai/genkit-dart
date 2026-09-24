// Copyright 2026 Google LLC
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

/// Experimental bi-directional (bidi) veneer on [GenkitAI] / [Genkit].
///
/// These methods live in the experimental surface so they can evolve without a
/// major version bump. See `package:genkit/experimental.dart` for the stability
/// policy.
library;

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import '../ai/generate_bidi.dart' show GenerateBidiSession, runGenerateBidi;
import '../ai/model.dart' show BidiModel;
import '../ai/tool.dart' show Tool;
import '../core/action.dart' show BidiActionFn;
import '../core/cancellation.dart' show CancellationToken;
import '../core/flow.dart' show Flow;
import '../exception.dart' show GenkitException, StatusCodes;
import '../genkit_ai.dart' show GenkitAI, resolveInlineTools;
import '../genkit_class.dart' show Genkit;
import '../types.dart' show ModelRequest, ModelResponse, ModelResponseChunk;

/// Experimental live-session method on [GenkitAI].
///
/// Import `package:genkit/experimental.dart` to bring this into scope.
@experimental
extension GenkitBidi on GenkitAI {
  /// Starts a bi-directional (live) generator session.
  Future<GenerateBidiSession> generateBidi({
    required String model,
    dynamic config,
    List<Tool>? tools,
    List<String>? toolNames,
    String? system,
    CancellationToken? cancel,
  }) {
    final resolved = resolveInlineTools(
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
      cancel: cancel,
    );
  }
}

/// Experimental bi-directional authoring methods on [Genkit].
///
/// Import `package:genkit/experimental.dart` to bring these into scope.
@experimental
extension GenkitBidiModel on Genkit {
  /// Defines a bi-directional Genkit flow.
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

  /// Defines a bi-directional (live) AI model interface.
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
}
