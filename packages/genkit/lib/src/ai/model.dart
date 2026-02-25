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

ModelRef<CustomOptions> modelRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
}) {
  return _ModelRef<CustomOptions>(name, customOptions);
}

abstract class ModelRef<CustomOptions> {
  String get name;
  SchemanticType<CustomOptions>? get customOptions;
}

class _ModelRef<CustomOptions> implements ModelRef<CustomOptions> {
  @override
  final String name;
  @override
  final SchemanticType<CustomOptions>? customOptions;

  _ModelRef(this.name, this.customOptions);
}

class Model<CustomOptions>
    extends Action<ModelRequest, ModelResponse, ModelResponseChunk, void>
    implements ModelRef<CustomOptions> {
  @override
  SchemanticType<CustomOptions>? customOptions;

  Model({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: 'model',
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

ActionMetadata modelMetadata(
  String name, {
  ModelInfo? modelInfo,
  SchemanticType<dynamic>? customOptions,
}) {
  return ActionMetadata(
    name: name,
    description: name,
    actionType: 'model',
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

BidiModelRef<CustomOptions> bidiModelRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
}) {
  return _BidiModelRef<CustomOptions>(name, customOptions);
}

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
         actionType: 'bidi-model',
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
