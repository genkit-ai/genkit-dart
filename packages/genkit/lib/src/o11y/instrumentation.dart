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

import 'instrumentation_api.dart';

export 'instrumentation_api.dart'
    show Instrumentation, SpanContext, SpanMetadata;

/// Zone key under which the active [SpanContext] is stored while a span runs.
const _spanContextKey = #genkit.spanContext;

/// The ordered list of configured instrumentation providers.
///
/// Providers compose as middleware: index 0 is outermost, the wrapped function
/// is innermost. By default this is empty, meaning Genkit is not instrumented at
/// all (spans are a no-op and no telemetry backend is touched).
final List<Instrumentation> _instrumentations = [];

/// Registers an [instrumentation] provider.
///
/// May be called multiple times to stack providers; they compose as a chain in
/// registration order. Configure providers before creating `Genkit`.
void configureInstrumentation(Instrumentation instrumentation) {
  _instrumentations.add(instrumentation);
}

/// Removes all configured instrumentation providers.
///
/// Primarily intended for tests and re-initialization.
void resetInstrumentation() {
  _instrumentations.clear();
}

/// Whether any configured provider is of type [T].
///
/// Useful to guard against injecting a built-in provider more than once.
bool isInstrumentedBy<T extends Instrumentation>() {
  return _instrumentations.any((i) => i is T);
}

/// Attaches custom metadata to the currently active span, if any.
///
/// No-op when running outside an instrumented span.
void setCustomMetadataAttributes(Map<String, Object?> attributes) {
  final span = Zone.current[_spanContextKey] as SpanContext?;
  span?.setMetadata(attributes);
}

/// Runs [fn] inside a new span, dispatching to all configured
/// [Instrumentation] providers as a middleware chain.
///
/// When no providers are configured, [fn] runs directly with a no-op
/// [SpanContext] (empty trace/span ids).
Future<Output> runInNewSpan<Input, Output>(
  String name,
  Future<Output> Function(SpanContext) fn, {
  String? actionType,
  Input? input,
  Map<String, String>? attributes,
}) {
  final metadata = SpanMetadata(
    name: name,
    actionType: actionType,
    input: input,
    attributes: attributes ?? const {},
  );

  // Snapshot the providers up front so that mutations to [_instrumentations]
  // (e.g. configureInstrumentation/resetInstrumentation) during asynchronous
  // gaps cannot cause a RangeError or an inconsistent middleware chain.
  final instrumentations = List<Instrumentation>.of(_instrumentations);
  if (instrumentations.isEmpty) {
    return _runWithSpan(const _NoopSpanContext(), fn);
  }

  // Collect the per-provider spans while descending the chain, so the composite
  // span handed to [fn] can fan metadata out to all of them and resolve
  // trace/span ids from the first provider that supplies them.
  final spans = <SpanContext>[];

  Future<Output> build(int index) {
    if (index == instrumentations.length) {
      return _runWithSpan(_CompositeSpanContext(spans), fn);
    }
    return instrumentations[index].runInNewSpan(metadata, (span) {
      spans.add(span);
      return build(index + 1);
    });
  }

  return build(0);
}

/// Runs [fn] with [span] recorded in the current zone so that
/// [setCustomMetadataAttributes] can reach it.
Future<Output> _runWithSpan<Output>(
  SpanContext span,
  Future<Output> Function(SpanContext) fn,
) {
  return runZoned(() => fn(span), zoneValues: {_spanContextKey: span});
}

/// A [SpanContext] used when no instrumentation is configured.
class _NoopSpanContext implements SpanContext {
  const _NoopSpanContext();

  @override
  String get traceId => '';

  @override
  String get spanId => '';

  @override
  void setMetadata(Map<String, Object?> metadata) {}
}

/// A [SpanContext] that fans out to every provider's span.
///
/// [traceId] and [spanId] resolve to the first non-empty value across the
/// underlying spans, so a real backend (e.g. the dev OTel provider) surfaces
/// usable ids even when combined with backends that do not expose them.
class _CompositeSpanContext implements SpanContext {
  final List<SpanContext> _spans;

  _CompositeSpanContext(this._spans);

  @override
  String get traceId => _firstNonEmpty((s) => s.traceId);

  @override
  String get spanId => _firstNonEmpty((s) => s.spanId);

  @override
  void setMetadata(Map<String, Object?> metadata) {
    for (final span in _spans) {
      span.setMetadata(metadata);
    }
  }

  String _firstNonEmpty(String Function(SpanContext) get) {
    for (final span in _spans) {
      final value = get(span);
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
