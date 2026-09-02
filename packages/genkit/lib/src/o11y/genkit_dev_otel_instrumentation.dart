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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;

import 'instrumentation_api.dart';

/// Genkit's dev-mode instrumentation that emits spans via the OpenTelemetry SDK.
///
/// Used when Genkit is able to participate in a global OpenTelemetry setup.
/// Spans are created via an [otel.Tracer] and flow to whatever span processors
/// are attached to its provider (Genkit attaches its own exporter targeting the
/// telemetry server; a user-configured pipeline receives them too).
///
/// Encodes Genkit span metadata as OpenTelemetry attributes prefixed with
/// `genkit:`, so the Developer UI works. This is distinct from the general
/// OpenTelemetry GenAI semantic-convention instrumentation (added separately).
class GenkitDevOtelInstrumentation implements Instrumentation {
  final otel.Tracer _tracer;

  GenkitDevOtelInstrumentation(this._tracer);

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) {
    final attributes = <String, Object>{'genkit:name': metadata.name};
    final actionType = metadata.actionType;
    if (actionType != null) {
      attributes['genkit:type'] = actionType;
      // The Developer UI keys flow lookups off this metadata attribute.
      if (actionType == 'flow') {
        attributes['genkit:metadata:flow:name'] = metadata.name;
      }
    }
    final input = metadata.input;
    if (input != null) {
      attributes['genkit:input'] = _encodeJson(input);
    }
    metadata.attributes.forEach((key, value) {
      attributes[key] = value;
    });

    // startSpan parents off Context.current; withSpanAsync (below) makes each
    // span active for its subtree, so nested Genkit spans nest correctly.
    final span = _tracer.startSpan(
      metadata.name,
      attributes: otel.Attributes.of(attributes),
    );

    return _tracer.withSpanAsync(span, () async {
      try {
        final output = await next(_OtelSpanContext(span));
        span.setStringAttribute<String>('genkit:output', _encodeJson(output));
        span.setStatus(otel.SpanStatusCode.Ok);
        return output;
      } catch (e, s) {
        span
          ..setStatus(otel.SpanStatusCode.Error, e.toString())
          ..recordException(e, stackTrace: s);
        rethrow;
      } finally {
        span.end();
      }
    });
  }
}

/// Always JSON-encodes (a String becomes a quoted JSON string), matching the
/// historical `genkit:input`/`genkit:output` encoding.
String _encodeJson(Object? value) {
  try {
    return jsonEncode(value);
  } catch (e) {
    return 'Unable to encode: $e';
  }
}

/// Encodes metadata values: passes Strings through as-is, JSON-encodes the rest.
String _encodeMetadata(Object? value) {
  try {
    return value is String ? value : jsonEncode(value);
  } catch (e) {
    return 'Unable to encode: $e';
  }
}

/// A [SpanContext] backed by an OpenTelemetry span.
class _OtelSpanContext implements SpanContext {
  final otel.Span _span;

  _OtelSpanContext(this._span);

  @override
  String get traceId => _span.spanContext.traceId.toString();

  @override
  String get spanId => _span.spanContext.spanId.toString();

  @override
  void setMetadata(Map<String, Object?> metadata) {
    metadata.forEach((key, value) {
      _span.setStringAttribute<String>(
        'genkit:metadata:$key',
        _encodeMetadata(value),
      );
    });
  }
}
