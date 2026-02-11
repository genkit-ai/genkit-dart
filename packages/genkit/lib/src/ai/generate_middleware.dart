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
import 'generate.dart';
import 'tool.dart';

/// Middleware for the processing of a Generation request.
abstract class GenerateMiddleware {
  /// Middlewares can act as a "kit" by providing tools directly.
  /// These tools will be added to the tool list of the `generate` call.
  List<Tool>? get tools => null;

  /// Middleware for the top-level generate call.
  ///
  /// Wraps the entire generation process, including the tool loop.
  ///
  /// [next] is the function to call to proceed with the generation.
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    FunctionContext<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      FunctionContext<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) => next(options, ctx);

  /// Middleware for the raw model call.
  ///
  /// Wraps the call to the model action.
  Future<ModelResponse> model(
    ModelRequest request,
    FunctionContext<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      FunctionContext<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) => next(request, ctx);

  /// Middleware for tool execution.
  ///
  /// Wraps independent tool calls.
  /// Input is dynamic because tools can have varied input schemas.
  Future<ToolResponse> tool(
    ToolRequest request,
    FunctionContext<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      FunctionContext<void, dynamic, void> ctx,
    )
    next,
  ) => next(request, ctx);
}

final class GenerateMiddlewareDef<C> {
  final String name;
  final SchemanticType<C>? configSchema;
  final GenerateMiddleware Function([C? config]) _create;

  Schema? get configJsonSchema => configSchema?.jsonSchema();

  GenerateMiddleware create([C? config]) => _create(config);

  GenerateMiddlewareDef._(this.name, this._create, this.configSchema);
}

GenerateMiddlewareDef<C> defineMiddleware<C>({
  required String name,
  required GenerateMiddleware Function([C? config]) create,
  SchemanticType<C>? configSchema,
}) {
  return GenerateMiddlewareDef<C>._(name, create, configSchema);
}

final class GenerateMiddlewareRef<C> {
  final String name;
  final C? config;

  const GenerateMiddlewareRef._(this.name, this.config);
}

GenerateMiddlewareRef<C> middlewareRef<C>({required String name, C? config}) {
  return GenerateMiddlewareRef<C>._(name, config);
}
