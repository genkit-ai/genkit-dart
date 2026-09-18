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

  Model({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: .model,
         inputSchema: ModelRequest.$schema,
         outputSchema: ModelResponse.$schema,
         streamSchema: ModelResponseChunk.$schema,
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

/// Capability metadata for a model that supplied none.
///
/// The chat capabilities are assumed because a model registered through a
/// plugin that says nothing is overwhelmingly a chat model, and the cost of
/// assuming wrong is a request the provider rejects on its own terms.
///
/// `constrained` is deliberately absent rather than `true`. It is the one
/// entry `generate` acts on: a model that does not claim native constrained
/// generation has it simulated for it instead (see
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
