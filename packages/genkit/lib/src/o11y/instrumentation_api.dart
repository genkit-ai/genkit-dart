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

/// Backend-agnostic description of a span about to be created.
///
/// A [SpanMetadata] carries everything an [Instrumentation] provider needs to
/// start a span. It intentionally uses plain Dart types (no OpenTelemetry
/// dependency), leaving the encoding of values up to each provider.
class SpanMetadata {
  /// The span name (typically the action or operation name).
  final String name;

  /// The Genkit action type, e.g. `'flow'`, `'model'`, `'tool'`.
  final String? actionType;

  /// The raw input passed to the wrapped operation.
  ///
  /// Providers decide whether and how to encode this (e.g. JSON). May be `null`.
  final Object? input;

  /// Additional static attributes supplied by the caller.
  final Map<String, String> attributes;

  const SpanMetadata({
    required this.name,
    this.actionType,
    this.input,
    this.attributes = const {},
  });
}

/// A handle to a live span, handed to the wrapped function.
///
/// Exposes just enough to correlate traces and to annotate the current span
/// mid-execution, without leaking any OpenTelemetry types.
abstract interface class SpanContext {
  /// The trace id, or an empty string when unknown / not instrumented.
  String get traceId;

  /// The span id, or an empty string when unknown / not instrumented.
  String get spanId;

  /// Attaches custom metadata to the current span.
  ///
  /// Providers decide how to encode values. Safe to call multiple times.
  void setMetadata(Map<String, Object?> metadata);
}

/// A pluggable telemetry instrumentation provider.
///
/// The [Instrumentation.runInNewSpan] hook behaves like middleware: it receives
/// a `next` function and is expected to invoke it (usually inside its own span),
/// then return its result. Providers may inspect the awaited result to record
/// outputs, catch errors to record exceptions, and propagate their own context
/// around the `next` call.
///
/// Configure providers via `configureInstrumentation` (see `instrumentation.dart`).

abstract interface class Instrumentation {
  /// Wraps [next] in a new span described by [metadata].
  ///
  /// Implementations must call [next], passing a [SpanContext] representing the
  /// span they created, and return its result.
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  );
}
