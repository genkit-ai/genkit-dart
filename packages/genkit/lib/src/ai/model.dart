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

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../schema.dart';
import '../types.dart';
import 'middleware/simulate_constrained_generation.dart';

ModelRef<CustomOptions> modelRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
  CustomOptions? config,
}) {
  return _ModelRef<CustomOptions>(name, customOptions, config: config);
}

abstract class ModelRef<CustomOptions> {
  String get name;
  CustomOptions? get config;
  SchemanticType<CustomOptions>? get customOptions;
}

class _ModelRef<CustomOptions> implements ModelRef<CustomOptions> {
  @override
  final String name;
  @override
  final CustomOptions? config;
  @override
  final SchemanticType<CustomOptions>? customOptions;

  _ModelRef(this.name, this.customOptions, {this.config});
}

class Model<CustomOptions>
    extends Action<ModelRequest, ModelResponse, ModelResponseChunk, void>
    implements ModelRef<CustomOptions> {
  // For a model instance the config is always null.
  @override
  final CustomOptions? config = null;

  @override
  final SchemanticType<CustomOptions>? customOptions;

  /// Redirects so [metadata] is one map for the whole object: the same
  /// instance backs the field and the capability lookup below. Callers fill it
  /// after construction - `defineRemoteModel` does, by cascade - so the
  /// lookup has to read that map when the model is called, not copy a value
  /// out of it while the model is still being built.
  Model({
    required String name,
    required InternalActionFn<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      void
    >
    fn,
    Map<String, dynamic>? metadata,
    SchemanticType<CustomOptions>? customOptions,
  }) : this._(
         metadata ?? <String, dynamic>{},
         name: name,
         fn: fn,
         customOptions: customOptions,
       );

  Model._(
    Map<String, dynamic> metadata, {
    required super.name,
    required InternalActionFn<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      void
    >
    fn,
    this.customOptions,
  }) : super(
         // Wrapped here, not where `generate` composes middleware, so a direct
         // action call - `registry.lookupAction` and the Dev UI's `runAction`
         // both invoke the action `fn` straight, bypassing `generate` entirely
         // - still gets the fallback a model that never claimed
         // `supports.constrained` needs. This is the only place it is
         // installed; `generate` does not add one of its own.
         //
         // The cost of sitting this deep: `generate` builds the trace and
         // `response.request` from the request as the caller made it, so both
         // show a schema the provider was never sent. Read the prompt, not
         // `output.schema`, when a simulated response comes back malformed.
         fn: _withConstrainedSimulation(metadata, fn),
         actionType: .model,
         inputSchema: ModelRequest.$schema,
         outputSchema: ModelResponse.$schema,
         streamSchema: ModelResponseChunk.$schema,
         metadata: metadata,
       ) {
    metadata['description'] = name;

    final model = <String, dynamic>{
      ...(metadata['model'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    };
    metadata['model'] = model;

    if (model['label'] == null) {
      model['label'] = name;
    }
    if (customOptions != null) {
      model['customOptions'] = toJsonSchema(
        type: customOptions,
        useRefs: false,
      );
    }
  }
}

/// Wraps [fn] so a call to the action itself - not just one routed through
/// `generate` - simulates constrained generation when [metadata] does not
/// declare `supports.constrained`.
///
/// [metadata] is read per call, not at construction: `defineRemoteModel` and
/// any caller building a `Model` and then filling its metadata would
/// otherwise have their declaration ignored, and be simulated for a
/// capability they said they had.
InternalActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void>
_withConstrainedSimulation(
  Map<String, dynamic> metadata,
  InternalActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
) {
  return (request, ctx) {
    if (request == null) return fn(request, ctx);
    final modelMeta = metadata['model'];
    final supports = modelMeta is Map ? modelMeta['supports'] : null;
    final middleware = SimulateConstrainedGenerationMiddleware(
      constrained: supports is Map ? supports['constrained'] : null,
    );
    return middleware.model(request, ctx, fn);
  };
}

/// Capability metadata for a model that supplied none.
///
/// The chat capabilities are assumed because a model registered through a
/// plugin that says nothing is overwhelmingly a chat model, and the cost of
/// assuming wrong is a request the provider rejects on its own terms.
///
/// `constrained` is deliberately absent rather than `true`. It is the one
/// entry the [Model] constructor acts on: a model that does not claim native
/// constrained generation has it simulated for it instead (see
/// `middleware/simulate_constrained_generation.dart`). Claiming it here would
/// opt every undeclared model out of that fallback on the strength of a
/// default nobody wrote, which is the failure the fallback exists to prevent.
ModelInfo _unclaimedModelInfo(String name) => ModelInfo(
  label: name,
  supports: const {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
  },
);

ActionMetadata modelMetadata(
  String name, {
  ModelInfo? modelInfo,
  SchemanticType<dynamic>? customOptions,
}) {
  return ActionMetadata(
    name: name,
    description: name,
    actionType: .model,
    metadata: {
      'label': name,
      'description': name,
      'model': {
        ...(modelInfo ?? _unclaimedModelInfo(name)).toJson(),
        if (customOptions != null)
          'customOptions': toJsonSchema(type: customOptions, useRefs: false),
      },
    },
  );
}

/// Experimental: lives behind `package:genkit/experimental.dart`.
@experimental
BidiModelRef<CustomOptions> bidiModelRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
}) {
  return _BidiModelRef<CustomOptions>(name, customOptions);
}

/// Experimental: lives behind `package:genkit/experimental.dart`.
@experimental
abstract class BidiModelRef<CustomOptions> {
  String get name;
  SchemanticType<CustomOptions>? get customOptions;
}

class _BidiModelRef<CustomOptions> implements BidiModelRef<CustomOptions> {
  @override
  final String name;
  @override
  final SchemanticType<CustomOptions>? customOptions;

  _BidiModelRef(this.name, this.customOptions);
}

/// Experimental: lives behind `package:genkit/experimental.dart`.
@experimental
class BidiModel<CustomOptions>
    extends
        Action<ModelRequest, ModelResponse, ModelResponseChunk, ModelRequest>
    implements BidiModelRef<CustomOptions> {
  @override
  SchemanticType<CustomOptions>? customOptions;

  BidiModel({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: .bidiModel,
         inputSchema: ModelRequest.$schema,
         initSchema: ModelRequest.$schema,
         outputSchema: ModelResponse.$schema,
         streamSchema: ModelResponseChunk.$schema,
       ) {
    metadata['description'] = name;
    final model =
        (metadata['model'] ??= <String, dynamic>{}) as Map<String, dynamic>;
    model['label'] = name;
    if (customOptions != null) {
      model['customOptions'] = toJsonSchema(type: customOptions);
    }
  }
}
