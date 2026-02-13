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
import '../types.dart';
import 'generate_types.dart';
import 'tool.dart';

/// Middleware for the processing of a Generation request.
abstract class GenerateMiddleware {
  /// Middleware can act as a "kit" by providing tools directly.
  /// These tools will be added to the tool list of the `generate` call.
  List<Tool>? get tools => null;

  /// Middleware for the top-level generate call.
  ///
  /// Wraps the entire generation process, including the tool loop.
  ///
  /// [next] is the function to call to proceed with the generation.
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) {
    return next(options, ctx);
  }

  /// Middleware for the raw model call.
  ///
  /// Wraps the call to the model action.
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) {
    return next(request, ctx);
  }

  /// Middleware for tool execution.
  ///
  /// Wraps independent tool calls.
  /// Input is dynamic because tools can have varied input schemas.
  Future<ToolResponse> tool(
    ToolRequest request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    return next(request, ctx);
  }
}

abstract interface class GenerateMiddlewareDef<C> {
  String get name;
  SchemanticType<C>? get configSchema;
  Schema? get configJsonSchema;

  GenerateMiddleware create([C? config]);
}

class _GenerateMiddlewareDef<C> implements GenerateMiddlewareDef<C> {
  @override
  final String name;
  @override
  final SchemanticType<C>? configSchema;
  final GenerateMiddleware Function([C? config]) _create;

  _GenerateMiddlewareDef(this.name, this._create, this.configSchema);

  @override
  Schema? get configJsonSchema => configSchema?.jsonSchema();

  @override
  GenerateMiddleware create([C? config]) => _create(config);
}

GenerateMiddlewareDef<C> defineMiddleware<C>({
  required String name,
  required GenerateMiddleware Function([C? config]) create,
  SchemanticType<C>? configSchema,
}) {
  return _GenerateMiddlewareDef<C>(name, create, configSchema);
}

abstract interface class GenerateMiddlewareRef<C> {
  String get name;
  C? get config;
}

class _GenerateMiddlewareRef<C> implements GenerateMiddlewareRef<C> {
  @override
  final String name;
  @override
  final C? config;

  _GenerateMiddlewareRef(this.name, this.config);
}

GenerateMiddlewareRef<C> middlewareRef<C>({required String name, C? config}) {
  return _GenerateMiddlewareRef<C>(name, config);
}
