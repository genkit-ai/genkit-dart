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

import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../schema.dart';
import '../types.dart';

ModelReference<C> modelRef<C>(
  String name, {
  SchemanticType<C>? customOptions,
}) {
  return _ModelRef<C>(name, customOptions);
}

abstract class ModelReference<C> {
  String get name;
  SchemanticType<C>? get customOptions;
}

class _ModelRef<C> implements ModelReference<C> {
  @override
  final String name;
  @override
  final SchemanticType<C>? customOptions;

  _ModelRef(this.name, this.customOptions);
}

class Model<C>
    extends Action<ModelRequest, ModelResponse, ModelResponseChunk, void>
    implements ModelReference<C> {
  @override
  SchemanticType<C>? customOptions;

  Model({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: ActionType.model,
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
        type: customOptions!,
        useRefs: false,
      );
    }
  }
}

ActionMetadata modelMetadata(
  String name, {
  ModelInfo? modelInfo,
  SchemanticType<Object>? customOptions,
}) {
  return ActionMetadata(
    name: name,
    description: name,
    actionType: ActionType.model,
    metadata: {
      'label': name,
      'description': name,
      'model': {
        ...(modelInfo ??
                ModelInfo(
                  label: name,
                  supports: {
                    'multiturn': true,
                    'media': true,
                    'tools': true,
                    'toolChoice': true,
                    'systemRole': true,
                    'constrained': true,
                  },
                ))
            .toJson(),
        if (customOptions != null)
          'customOptions': toJsonSchema(type: customOptions, useRefs: false),
      },
    },
  );
}

BidiModelRef<C> bidiModelRef<C>(
  String name, {
  SchemanticType<C>? customOptions,
}) {
  return _BidiModelRef<C>(name, customOptions);
}

abstract class BidiModelRef<C> {
  String get name;
  SchemanticType<C>? get customOptions;
}

class _BidiModelRef<C> implements BidiModelRef<C> {
  @override
  final String name;
  @override
  final SchemanticType<C>? customOptions;

  _BidiModelRef(this.name, this.customOptions);
}

class BidiModel<C>
    extends
        Action<ModelRequest, ModelResponse, ModelResponseChunk, ModelRequest>
    implements BidiModelRef<C> {
  @override
  SchemanticType<C>? customOptions;

  BidiModel({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: ActionType.bidiModel,
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
      model['customOptions'] = toJsonSchema(type: customOptions!);
    }
  }
}
