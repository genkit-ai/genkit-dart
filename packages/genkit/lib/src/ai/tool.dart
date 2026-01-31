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

import '../core/action.dart';
import 'interrupt.dart';

/// Arguments passed to a tool function execution.
class ToolFnArgs<I> {
  final ActionFnArg<void, I, void> _base;

  ToolFnArgs(this._base);

  /// The execution context.
  Map<String, dynamic>? get context => _base.context;

  /// Interrupts the generation loop with optional [data].
  Never interrupt([dynamic data]) {
    throw ToolInterruptException(data ?? true);
  }
}

/// A function that implements a tool.
typedef ToolFn<I, O> = Future<O> Function(I input, ToolFnArgs<I> context);

class Tool<I, O> extends Action<I, O, void, void> {
  Tool({
    required super.name,
    required super.description,
    required ToolFn<I, O> fn,
    super.inputSchema,
    super.outputSchema,
    super.metadata,
  }) : super(
         fn: (input, ctx) {
           if (input == null && inputSchema != null && null is! I) {
             throw ArgumentError('Tool "$name" requires a non-null input.');
           }
           return fn(input as I, ToolFnArgs(ctx));
         },
         actionType: 'tool',
       );
}
