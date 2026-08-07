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
import 'dart:convert';

import 'package:opentelemetry/api.dart' as api;

import 'instrumentation_api.dart';
import 'otlp_http_exporter.dart' show configureCollectorExporter;

/// Zone key under which the OpenTelemetry [api.Context] is propagated.
const _otelContextKey = #api.context;

/// The built-in OpenTelemetry-based [Instrumentation].
///
/// Encodes Genkit span metadata as OpenTelemetry span attributes prefixed with
/// `genkit:`. This is the same behavior Genkit has historically had, and is
/// auto-injected in the dev environment so the Developer UI works out of the box.
class OtelInstrumentation implements Instrumentation {
  final api.TracerProvider? _tracerProvider;
  api.Tracer? _cachedTracer;

  /// Creates an instrumentation that emits spans via [tracerProvider].
  ///
  /// When [tracerProvider] is `null`, the global tracer provider is used as a
  /// fallback. Prefer passing an explicit provider (e.g. the one returned by
  /// `configureCollectorExporter`) so Genkit's traces are routed correctly even
  /// if a global tracer provider was registered elsewhere.
  OtelInstrumentation({api.TracerProvider? tracerProvider})
    : _tracerProvider = tracerProvider;

  /// Resolves the tracer lazily on first use.
  ///
  /// Binding to the provider instance (rather than always reading
  /// `api.globalTracerProvider`) ensures Genkit's spans reach the configured
  /// collector even when a different global tracer provider is registered.
  api.Tracer get _tracer => _cachedTracer ??=
      (_tracerProvider ?? api.globalTracerProvider).getTracer('genkit-dart');

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) {
    final parentContext = Zone.current[_otelContextKey] as api.Context?;
    final spanAttributes = <api.Attribute>[
      api.Attribute.fromString('genkit:name', metadata.name),
    ];
    final actionType = metadata.actionType;
    if (actionType != null) {
      spanAttributes.add(api.Attribute.fromString('genkit:type', actionType));
      // tmp hack...
      if (actionType == 'flow') {
        spanAttributes.add(
          api.Attribute.fromString('genkit:metadata:flow:name', metadata.name),
        );
      }
    }
    final input = metadata.input;
    if (input != null) {
      try {
        spanAttributes.add(
          api.Attribute.fromString('genkit:input', jsonEncode(input)),
        );
      } catch (e) {
        spanAttributes.add(
          api.Attribute.fromString(
            'genkit:input',
            'Unable to encode input: $e',
          ),
        );
      }
    }
    metadata.attributes.forEach((key, value) {
      spanAttributes.add(api.Attribute.fromString(key, value));
    });

    final span = parentContext == null
        ? _tracer.startSpan(metadata.name, attributes: spanAttributes)
        : _tracer.startSpan(
            metadata.name,
            context: parentContext,
            attributes: spanAttributes,
          );

    return runZoned(
      () async {
        try {
          final output = await next(_OtelSpanContext(span));
          try {
            span.setAttribute(
              api.Attribute.fromString('genkit:output', jsonEncode(output)),
            );
          } catch (e) {
            // Ignore json encoding errors for output.
            span.setAttribute(
              api.Attribute.fromString(
                'genkit:output',
                'Unable to encode output: $e',
              ),
            );
          }
          return output;
        } catch (e, s) {
          span
            ..setStatus(api.StatusCode.error, e.toString())
            ..recordException(e, stackTrace: s);
          rethrow;
        } finally {
          span.end();
        }
      },
      zoneValues: {
        _otelContextKey: api.contextWithSpan(api.Context.current, span),
      },
    );
  }
}

/// Creates the built-in OpenTelemetry [Instrumentation] used by the Genkit
/// Developer UI.
///
/// This configures the OTLP collector exporter (when `GENKIT_TELEMETRY_SERVER`
/// is set) and routes Genkit's spans through the returned tracer provider, so
/// traces reach the collector even if another global tracer provider is already
/// registered. Falls back to the global tracer provider when no collector is
/// configured.
Instrumentation genkitDevInstrumentation() =>
    OtelInstrumentation(tracerProvider: configureCollectorExporter());

/// A [SpanContext] backed by an OpenTelemetry span.
class _OtelSpanContext implements SpanContext {
  final api.Span _span;

  _OtelSpanContext(this._span);

  @override
  String get traceId => _span.spanContext.traceId.toString();

  @override
  String get spanId => _span.spanContext.spanId.toString();

  @override
  void setMetadata(Map<String, Object?> metadata) {
    metadata.forEach((key, value) {
      String valueString;
      try {
        valueString = value is String ? value : jsonEncode(value);
      } catch (e) {
        valueString = 'Error encoding metadata: $e';
      }
      _span.setAttribute(
        api.Attribute.fromString('genkit:metadata:$key', valueString),
      );
    });
  }
}
