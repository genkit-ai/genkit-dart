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
import '../o11y/instrumentation.dart';
import '../schema.dart';
import '../types.dart';
import 'tool_input_wrapping.dart';

ModelRef<CustomOptions> modelRef<CustomOptions>(
  String name, {
  SchemanticType<CustomOptions>? customOptions,
  CustomOptions? config,
}) {
  return _ModelRef<CustomOptions>(name, customOptions, config: config);
}

abstract interface class ModelRef<CustomOptions> {
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

base class Model<CustomOptions>
    extends Action<ModelRequest, ModelResponse, ModelResponseChunk, void>
    implements ModelRef<CustomOptions> {
  // For a model instance the config is always null.
  @override
  final CustomOptions? config = null;

  @override
  final SchemanticType<CustomOptions>? customOptions;

  /// Creates a model backed by [fn].
  ///
  /// Tools with a non-object input schema (e.g. `.string()`) work with any
  /// model: [fn] sees them as `{input: <schema>}` and their calls as
  /// `{input: <value>}`, which is what providers accept. Everything outside
  /// [fn] (history, middleware, tools) sees the declared shape.
  Model({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
    Map<String, dynamic>? metadata,
    SchemanticType<CustomOptions>? customOptions,
  }) : this._(
         name: name,
         fn: _withToolInputWrapping(fn),
         metadata: metadata,
         customOptions: customOptions,
       );

  /// A model that forwards requests to another Genkit model (e.g. over HTTP).
  ///
  /// The serving model owns tool input wrapping, so requests pass through
  /// with the declared tool schemas. Its wire format is then its own business
  /// and does not have to match this implementation.
  @internal
  Model.proxy({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
    Map<String, dynamic>? metadata,
    SchemanticType<CustomOptions>? customOptions,
  }) : this._(
         name: name,
         fn: fn,
         metadata: metadata,
         customOptions: customOptions,
       );

  Model._({
    required super.name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
    super.metadata,
    this.customOptions,
  }) : super(
         fn: requireInput('Model', name, fn),
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

// Tool input wrapping lives on the model action itself (see
// [ToolInputWrapping]): the model implementation sees the wire shape, while
// the model span, middleware, history and tools see the declared shape. The
// span gets a `toolInputWrapped` attribute so the difference from the raw
// provider payload is discoverable in traces. Proxies (`Model.proxy`, e.g.
// remote models) skip it: the serving model wraps.

ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void>
_withToolInputWrapping(
  ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
) {
  return (request, ctx) async {
    final wrapping = ToolInputWrapping.forTools(request.tools);
    if (wrapping == null) return fn(request, ctx);
    setCustomMetadataAttributes({'toolInputWrapped': wrapping.toolNames});
    final response = await fn(
      wrapping.wrapRequest(request),
      ctx.copyWith(
        sendChunk: (chunk) => ctx.sendChunk(wrapping.unwrapChunk(chunk)),
      ),
    );
    return wrapping.unwrapResponse(response);
  };
}

BidiActionFn<ModelRequest, ModelResponse, ModelResponseChunk, ModelRequest>
_withBidiToolInputWrapping(
  BidiActionFn<ModelRequest, ModelResponse, ModelResponseChunk, ModelRequest>
  fn,
) {
  return (inputStream, ctx) async {
    // Tools are declared once, on the session's init request.
    final init = ctx.init;
    final wrapping = ToolInputWrapping.forTools(init?.tools);
    if (wrapping == null) return fn(inputStream, ctx);
    setCustomMetadataAttributes({'toolInputWrapped': wrapping.toolNames});
    // `inputStream` is `ctx.inputStream`, a single-subscription stream, so
    // both views must share one mapped stream.
    final wrappedInput = inputStream.map(wrapping.wrapRequest);
    final response = await fn(
      wrappedInput,
      ActionFnArg(
        streamingRequested: ctx.streamingRequested,
        sendChunk: (chunk) => ctx.sendChunk(wrapping.unwrapChunk(chunk)),
        context: ctx.context,
        inputStream: wrappedInput,
        init: wrapping.wrapRequest(init!),
        cancel: ctx.cancel,
      ),
    );
    return wrapping.unwrapResponse(response);
  };
}

/// Capability metadata for a model that supplied none: an ordinary chat model
/// with native constrained output. Descriptive only (the Dev UI and
/// `listActions` show it); core does not act on `supports`.
ModelInfo _defaultModelInfo({String? label}) => ModelInfo(
  label: label,
  supports: const {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

ActionMetadata modelMetadata(
  String name, {
  ModelInfo? info,
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
        ...(info ?? _defaultModelInfo(label: name)).toJson(),
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
abstract interface class BidiModelRef<CustomOptions> {
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
base class BidiModel<CustomOptions>
    extends
        Action<ModelRequest, ModelResponse, ModelResponseChunk, ModelRequest>
    implements BidiModelRef<CustomOptions> {
  @override
  final SchemanticType<CustomOptions>? customOptions;

  BidiModel({
    required super.name,
    required BidiActionFn<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      ModelRequest
    >
    fn,
    super.metadata,
    this.customOptions,
  }) : super(
         fn: bidiInput('Bidi model', name, _withBidiToolInputWrapping(fn)),
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
