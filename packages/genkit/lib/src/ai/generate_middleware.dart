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
import '../genkit_ai.dart';
import '../types.dart';
import 'generate_types.dart';
import 'tool.dart';

/// The state of one turn of the generate tool loop, as seen by
/// [GenerateMiddleware.generate].
///
/// A class rather than a record so fields can be added without breaking
/// middleware that constructs one. Middleware typically rewrites only the
/// request:
///
/// ```dart
/// return next(envelope.copyWith(request: newOptions), ctx);
/// ```
final class GenerateTurnState {
  /// The generate request for this turn.
  final GenerateActionOptions request;

  /// Zero-based index of this turn in the tool loop.
  final int currentTurn;

  /// Index of the next message in the response stream; used to tag streamed
  /// chunks with the message they belong to.
  final int messageIndex;

  GenerateTurnState({
    required this.request,
    this.currentTurn = 0,
    this.messageIndex = 0,
  });

  /// Returns a copy with the given fields replaced.
  GenerateTurnState copyWith({
    GenerateActionOptions? request,
    int? currentTurn,
    int? messageIndex,
  }) {
    return GenerateTurnState(
      request: request ?? this.request,
      currentTurn: currentTurn ?? this.currentTurn,
      messageIndex: messageIndex ?? this.messageIndex,
    );
  }

  // Summarizes [request] rather than printing it: it carries the whole
  // conversation, which would drown out the turn counters in logs.
  @override
  String toString() =>
      'GenerateTurnState(currentTurn: $currentTurn, '
      'messageIndex: $messageIndex, '
      'messages: ${request.messages.length}, model: ${request.model})';
}

/// Middleware for the processing of a Generation request.
///
/// Override only the hooks you need; the defaults pass through to `next`.
///
/// Always `extend` this class; do not `implement` it. New hooks are added with
/// pass-through defaults, which is only non-breaking for subclasses. (It is
/// not marked `base` because that would force every middleware class to
/// repeat the modifier.)
abstract class GenerateMiddleware {
  /// Middleware can act as a "kit" by providing tools directly.
  /// These tools will be added to the tool list of the `generate` call.
  List<Tool>? get tools => null;

  /// Middleware for the top-level generate call.
  ///
  /// Wraps the entire generation process, including the tool loop.
  ///
  /// [next] is the function to call to proceed with the generation.
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) {
    return next(envelope, ctx);
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
  /// Wraps each tool call. Input is dynamic because tools can have varied
  /// input schemas.
  ///
  /// Works with the same [ToolResult] a tool function returns: return
  /// `.response(output)` to answer the model, or `.interrupt(data)` to stop
  /// the generate loop and hand the tool request back to the caller
  /// (human-in-the-loop). The generate loop turns the final result into the
  /// tool response message (filling in the request's `ref` and `name`), so
  /// middleware never builds one by hand.
  ///
  /// A middleware that post-processes responses must pass interrupts through:
  ///
  /// ```dart
  /// final result = await next(request, ctx);
  /// return switch (result) {
  ///   ToolResponseResult(:final output, :final parts, :final metadata) =>
  ///     .response(redact(output), parts: parts, metadata: metadata),
  ///   ToolInterruptResult() => result,
  /// };
  /// ```
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    return next(request, ctx);
  }
}

/// Ambient dependencies handed to a middleware factory at instantiation time.
///
/// A class rather than a record so more dependencies can be added without
/// breaking code that constructs one (tests that call
/// [GenerateMiddlewareDef.create] directly).
final class GenerateMiddlewareContext {
  /// An ephemeral [GenkitAI] instance backed by the active action registry.
  ///
  /// Lets a middleware run nested AI operations (e.g. [GenkitAI.generate],
  /// [GenkitAI.embed]) and resolve other registered actions (models, tools,
  /// agents, etc.) by name when it is created. The underlying registry is
  /// available via `ai.registry`.
  final GenkitAI ai;

  GenerateMiddlewareContext({required this.ai});
}

/// A named, configurable middleware, built with [generateMiddleware] or
/// `ai.defineGenerateMiddleware`.
///
/// Call it to build the ref passed to `use:`:
///
/// ```dart
/// use: [logging(LoggingOptions(level: 'debug'))]
/// use: [logging()] // config is optional
/// ```
abstract interface class GenerateMiddlewareDef<CustomOptions> {
  String get name;
  SchemanticType<CustomOptions>? get configSchema;
  Map<String, Object?>? get configJsonSchema;

  GenerateMiddleware create(
    CustomOptions? config,
    GenerateMiddlewareContext ctx,
  );

  /// Builds a ref to this middleware for `use:`, with an optional [config].
  GenerateMiddlewareRef<CustomOptions> call([CustomOptions? config]);
}

class _GenerateMiddlewareDef<CustomOptions>
    implements GenerateMiddlewareDef<CustomOptions> {
  @override
  final String name;
  @override
  final SchemanticType<CustomOptions>? configSchema;
  final GenerateMiddleware Function(
    CustomOptions? config,
    GenerateMiddlewareContext ctx,
  )
  _create;

  _GenerateMiddlewareDef(this.name, this._create, this.configSchema);

  @override
  Map<String, Object?>? get configJsonSchema => configSchema?.jsonSchema();

  @override
  GenerateMiddleware create(
    CustomOptions? config,
    GenerateMiddlewareContext ctx,
  ) => _create(config, ctx);

  @override
  GenerateMiddlewareRef<CustomOptions> call([CustomOptions? config]) =>
      middlewareRef(name: name, config: config);
}

/// Builds a middleware definition without registering it. For plugin authors:
/// return it from `GenkitPlugin.middleware`.
///
/// The definition is callable (`loggerDef(LoggerOptions(...))` builds the ref
/// for `use:`). Packaged middleware usually also exposes a named-param
/// factory on top, which reads better at the call site (see `retry`).
///
/// ```dart
/// final loggerDef = generateMiddleware<LoggerOptions>(
///   name: 'logger',
///   configSchema: LoggerOptions.$schema,
///   create: (config, ctx) => LoggerMiddleware(config),
/// );
///
/// class LoggerPlugin extends GenkitPlugin {
///   @override
///   String get name => 'logger';
///
///   @override
///   List<GenerateMiddlewareDef> middleware() => [loggerDef];
/// }
///
/// // Optional sugar: `logger(enableColor: true)` instead of
/// // `loggerDef(LoggerOptions(enableColor: true))`.
/// GenerateMiddlewareRef<LoggerOptions> logger({bool? enableColor}) =>
///     loggerDef(LoggerOptions(enableColor: enableColor));
/// ```
///
/// App code that doesn't need a plugin should use
/// `ai.defineGenerateMiddleware`, which also registers the middleware.
///
/// Matches JS's `generateMiddleware`. The types are named differently: what
/// JS calls `GenerateMiddleware` (the definition) is [GenerateMiddlewareDef]
/// here, and [GenerateMiddleware] is the class with the hooks.
GenerateMiddlewareDef<CustomOptions> generateMiddleware<CustomOptions>({
  required String name,
  required GenerateMiddleware Function(
    CustomOptions? config,
    GenerateMiddlewareContext ctx,
  )
  create,
  SchemanticType<CustomOptions>? configSchema,
}) {
  return _GenerateMiddlewareDef<CustomOptions>(name, create, configSchema);
}

abstract interface class GenerateMiddlewareRef<CustomOptions> {
  String get name;
  CustomOptions? get config;
}

class _GenerateMiddlewareRef<CustomOptions>
    implements GenerateMiddlewareRef<CustomOptions> {
  @override
  final String name;
  @override
  final CustomOptions? config;

  _GenerateMiddlewareRef(this.name, this.config);
}

GenerateMiddlewareRef<CustomOptions> middlewareRef<CustomOptions>({
  required String name,
  CustomOptions? config,
}) {
  return _GenerateMiddlewareRef<CustomOptions>(name, config);
}
