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

import 'dart:async';

import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../o11y/instrumentation.dart';
import '../types.dart';
import 'interrupt.dart';

/// Arguments passed to a tool function execution.
class ToolFnArgs<Input> {
  final ActionFnArg<void, Input, void> _base;

  ToolFnArgs(this._base);

  /// The execution context.
  Map<String, dynamic>? get context => _base.context;

  /// The tool request that triggered this execution.
  ToolRequestPart? get toolRequest =>
      Zone.current[ToolRequestPart] as ToolRequestPart?;

  /// The resumed payload if this tool was restarted after an interrupt.
  ///
  /// Populated from the triggering tool request's `resumed` metadata. Mirrors
  /// the JS `ToolRunOptions.resumed`. The value is typically `true` or a
  /// `Map<String, dynamic>` supplied via `restart(...)`. Null when the tool was
  /// not resumed.
  dynamic get resumed => toolRequest?.metadata?['resumed'];

  /// Interrupts the generation loop with optional [data].
  @Deprecated(
    'Return `.interrupt(data)` from your tool function instead. '
    'This throwing form will be removed in a future release.',
  )
  Never interrupt([dynamic data]) {
    setCustomMetadataAttributes({'interrupt': data ?? true});
    throw ToolInterruptException(data ?? true);
  }
}

/// The result returned by a tool's implementation function.
///
/// Construct with the dot-shorthand factories:
/// - `return .response(output)` for a normal result.
/// - `return .response(output, parts: [...])` for a multipart result (images,
///   media, etc.).
/// - `return .interrupt(data)` to interrupt the generation loop.
sealed class ToolResult<Output> {
  const ToolResult._();

  /// A normal tool response with structured [output] and optional multipart
  /// [parts] (images, media, etc.) and [metadata].
  factory ToolResult.response(
    Output output, {
    List<Part>? parts,
    Map<String, dynamic>? metadata,
  }) = ToolResponseResult<Output>;

  /// Interrupts the generation loop, bubbling the tool request back to the
  /// caller with the optional [data] payload.
  factory ToolResult.interrupt([Object? data]) = ToolInterruptResult<Output>;

  /// Whether this is a normal [ToolResponseResult] carrying structured output.
  ///
  /// Use this to guard [output] before reading it:
  /// ```dart
  /// final result = await myTool(input);
  /// if (result.hasResponse) print(result.output);
  /// ```
  bool get hasResponse => this is ToolResponseResult<Output>;

  /// Whether this is a [ToolInterruptResult] that halted the generation loop.
  ///
  /// Use this to guard [interrupt] before reading it:
  /// ```dart
  /// final result = await myTool(input);
  /// if (result.hasInterrupt) print(result.interrupt);
  /// ```
  bool get hasInterrupt => this is ToolInterruptResult<Output>;

  /// The structured output of a normal tool response.
  ///
  /// Throws a [StateError] when this result is a [ToolInterruptResult]. Check
  /// [hasResponse] first, or pattern-match on [ToolResponseResult], when an
  /// interrupt is possible.
  Output get output {
    final self = this;
    if (self is ToolResponseResult<Output>) return self.output;
    throw StateError(
      'ToolResult.output was read on an interrupt result. Check hasResponse '
      'first, or pattern-match on ToolResponseResult.',
    );
  }

  /// The interrupt data payload of an interrupt result.
  ///
  /// Throws a [StateError] when this result is a [ToolResponseResult]. Check
  /// [hasInterrupt] first, or pattern-match on [ToolInterruptResult], when a
  /// normal response is possible.
  Object? get interrupt {
    final self = this;
    if (self is ToolInterruptResult<Output>) return self.data;
    throw StateError(
      'ToolResult.interrupt was read on a response result. Check hasInterrupt '
      'first, or pattern-match on ToolInterruptResult.',
    );
  }

  /// Serializes this result to the multipart `tool.v2` shape
  /// (`{output, content?, metadata?}` or `{interrupt}`). Used at the reflection
  /// boundary so the Dev UI can render tool results.
  Map<String, dynamic> toJson();
}

/// A normal tool response carrying structured [output] and optional multipart
/// [parts] and [metadata].
final class ToolResponseResult<Output> extends ToolResult<Output> {
  /// The structured output of the tool.
  @override
  final Output output;

  /// Optional multipart content (images, media, etc.) returned alongside the
  /// structured [output].
  final List<Part>? parts;

  /// Optional metadata attached to the resulting tool response part.
  final Map<String, dynamic>? metadata;

  const ToolResponseResult(this.output, {this.parts, this.metadata})
    : super._();

  @override
  Map<String, dynamic> toJson() {
    return {
      'output': output,
      if (parts != null) 'content': parts!.map((p) => p.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// An interrupt result that bubbles the tool request back to the caller with an
/// optional [data] payload.
final class ToolInterruptResult<Output> extends ToolResult<Output> {
  /// The interrupt data payload.
  final Object? data;

  const ToolInterruptResult([this.data]) : super._();

  @override
  Map<String, dynamic> toJson() {
    return {'interrupt': data ?? true};
  }
}

/// A function that implements a tool.
///
/// Returns a [ToolResult]: `.response(output)` for a normal result (optionally
/// with multipart `parts`) or `.interrupt(data)` to interrupt the generation
/// loop. Both synchronous and asynchronous bodies are supported via [FutureOr].
typedef ToolFn<Input, Output> =
    FutureOr<ToolResult<Output>> Function(
      Input input,
      ToolFnArgs<Input> context,
    );

class Tool<Input, Output>
    extends Action<Input, ToolResult<Output>, void, void> {
  /// The user-declared output schema (the schema of `Output`, not
  /// [ToolResult]). Used to build the model-facing tool definition and the
  /// action manifest (see [manifestOutputSchema]).
  final SchemanticType<Output>? toolOutputSchema;

  // Uses an explicit super call (not super parameters) because the base `fn`
  // is wrapped here, which is incompatible with super-parameter forwarding.
  // ignore: use_super_parameters
  Tool({
    required String name,
    required String description,
    required ToolFn<Input, Output> fn,
    SchemanticType<Input>? inputSchema,
    this.toolOutputSchema,
    Map<String, dynamic>? metadata,
  }) : super(
         name: name,
         description: description,
         inputSchema: inputSchema,
         // Every Genkit Dart tool implements the multipart ("v2") contract, so
         // it is registered and resolved under `ActionType.tool` (`tool.v2`).
         metadata: {...?metadata, 'type': ActionType.tool.value},
         actionType: .tool,
         fn: (input, ctx) async {
           if (input == null && inputSchema != null && null is! Input) {
             throw ArgumentError('Tool "$name" requires a non-null input.');
           }
           final result = await fn(input as Input, ToolFnArgs(ctx));
           // Record the interrupt on the tool's telemetry span so traces match
           // the (deprecated) throwing `ToolFnArgs.interrupt` form. This runs
           // inside the tool's span (see `Action.run` -> `runInNewSpan`).
           if (result is ToolInterruptResult<Output>) {
             setCustomMetadataAttributes({'interrupt': result.data ?? true});
           }
           return result;
         },
       );

  // A tool's base `outputSchema` describes the wrapper `ToolResult<Output>`,
  // not the user-declared `Output`. Surface the declared schema so action
  // manifests (Dev UI, reflection) and MCP `tools/list` advertise the shape
  // callers actually receive.
  @override
  SchemanticType? get manifestOutputSchema => toolOutputSchema;
}
