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

import 'package:genkit/schema.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/types.dart';

ModelRef<C> modelRef<C>(String name, {JsonExtensionType<C>? customOptions}) {
  return _ModelRef<C>(name, customOptions);
}

abstract class ModelRef<C> {
  String get name;
  JsonExtensionType<C>? get customOptions;
}

class _ModelRef<C> implements ModelRef<C> {
  @override
  final String name;
  @override
  final JsonExtensionType<C>? customOptions;

  _ModelRef(this.name, this.customOptions);
}

class Model<C> extends Action<ModelRequest, ModelResponse, ModelResponseChunk>
    implements ModelRef<C> {
  @override
  JsonExtensionType<C>? customOptions;

  Model({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: 'model',
         inputType: ModelRequestType,
         outputType: ModelResponseType,
         streamType: ModelResponseChunkType,
       ) {
    metadata['description'] = name;
    metadata['model'] = <String, dynamic>{};
    metadata['model']['label'] = name;
    if (customOptions != null) {
      metadata['model']['customOptions'] = customOptions!.jsonSchema.toJson();
    }
  }
}
