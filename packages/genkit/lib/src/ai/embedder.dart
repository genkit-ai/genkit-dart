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

EmbedderRef<CustomOptions> embedderRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
}) {
  return _EmbedderRef<CustomOptions>(name, customOptions);
}

abstract class EmbedderRef<CustomOptions> {
  String get name;
  SchemanticType<CustomOptions>? get customOptions;
}

class _EmbedderRef<CustomOptions> implements EmbedderRef<CustomOptions> {
  @override
  final String name;
  @override
  final SchemanticType<CustomOptions>? customOptions;

  _EmbedderRef(this.name, this.customOptions);
}

class Embedder<CustomOptions>
    extends Action<EmbedRequest, EmbedResponse, void, void>
    implements EmbedderRef<CustomOptions> {
  @override
  SchemanticType<CustomOptions>? customOptions;

  Embedder({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: 'embedder',
         inputSchema: EmbedRequest.$schema,
         outputSchema: EmbedResponse.$schema,
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

ActionMetadata embedderMetadata(
  String name, {
  SchemanticType<dynamic>? customOptions,
}) {
  return ActionMetadata(
    name: name,
    description: name,
    actionType: 'embedder',
    metadata: {
      'label': name,
      'description': name,
      'model': {
        'label': name,
        if (customOptions != null)
          'customOptions': toJsonSchema(type: customOptions, useRefs: false),
      },
    },
  );
}
