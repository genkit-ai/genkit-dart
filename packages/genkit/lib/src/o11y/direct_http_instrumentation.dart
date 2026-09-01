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
import 'dart:math';

import 'instrumentation_api.dart';
import 'telemetry/span_data.dart';

/// Zone key under which the active [_ActiveSpan] is propagated so child spans
/// can find their parent's ids and trace across async gaps.
const _activeSpanKey = #genkit.directHttpSpan;

/// A completely self-contained [Instrumentation] that needs no OpenTelemetry
/// runtime.
///
/// This is the fallback path: when Genkit cannot participate in a global OTel
/// setup, it mints its own trace/span ids, tracks parentage via the current
/// [Zone], times each operation, and on completion serializes the span to a
/// [SpanSink] (which POSTs OTLP/JSON to the Genkit telemetry server).
///
/// It intentionally reproduces the `genkit:*` attribute conventions the
/// Developer UI relies on, matching the OTel-backed instrumentation.
class DirectHttpInstrumentation implements Instrumentation {
  final SpanSink _sink;
  final Random _random;
  final Map<String, Object?> _resourceAttributes;

  DirectHttpInstrumentation(
    this._sink, {
    Map<String, Object?> resourceAttributes = const {
      'service.name': 'genkit-dart',
    },
    Random? random,
  }) : _resourceAttributes = resourceAttributes,
       _random = random ?? Random();

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function(SpanContext span) next,
  ) {
    final parent = Zone.current[_activeSpanKey] as _ActiveSpan?;
    final span = _ActiveSpan(
      traceId: parent?.traceId ?? _newTraceId(),
      spanId: _newSpanId(),
      parentSpanId: parent?.spanId,
      name: metadata.name,
      startTimeUnixNano: _nowUnixNano(),
    );

    span.attributes['genkit:name'] = metadata.name;
    final actionType = metadata.actionType;
    if (actionType != null) {
      span.attributes['genkit:type'] = actionType;
      // The Developer UI keys flow lookups off this metadata attribute.
      if (actionType == 'flow') {
        span.attributes['genkit:metadata:flow:name'] = metadata.name;
      }
    }
    final input = metadata.input;
    if (input != null) {
      span.attributes['genkit:input'] = _encodeJson(input);
    }
    metadata.attributes.forEach((key, value) {
      span.attributes[key] = value;
    });

    // Export the started span (endTime 0, unset status) so the Developer UI can
    // show it live, then export again once finished. This mirrors the OTel-
    // backed path, whose RealtimeSpanProcessor emits on both start and end.
    _sink.export([span.toSpanData(_resourceAttributes)]);

    return runZoned(() async {
      try {
        final output = await next(_DirectSpanContext(span));
        span.attributes['genkit:output'] = _encodeJson(output);
        span.status = const GenkitSpanStatus(code: GenkitStatusCode.ok);
        return output;
      } catch (e) {
        span.status = GenkitSpanStatus(
          code: GenkitStatusCode.error,
          message: e.toString(),
        );
        rethrow;
      } finally {
        span.endTimeUnixNano = _nowUnixNano();
        _sink.export([span.toSpanData(_resourceAttributes)]);
      }
    }, zoneValues: {_activeSpanKey: span});
  }

  String _newTraceId() => _hex(16);
  String _newSpanId() => _hex(8);

  String _hex(int bytes) {
    final sb = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      sb.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}

int _nowUnixNano() => DateTime.now().microsecondsSinceEpoch * 1000;

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

/// Mutable state for a span while its operation runs.
class _ActiveSpan {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String name;
  final int startTimeUnixNano;
  int endTimeUnixNano = 0;
  final Map<String, Object?> attributes = {};
  GenkitSpanStatus status = const GenkitSpanStatus();

  _ActiveSpan({
    required this.traceId,
    required this.spanId,
    required this.parentSpanId,
    required this.name,
    required this.startTimeUnixNano,
  });

  GenkitSpanData toSpanData(Map<String, Object?> resourceAttributes) {
    return GenkitSpanData(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      name: name,
      startTimeUnixNano: startTimeUnixNano,
      endTimeUnixNano: endTimeUnixNano,
      attributes: Map.of(attributes),
      status: status,
      resourceAttributes: resourceAttributes,
    );
  }
}

/// [SpanContext] handed to the traced function.
class _DirectSpanContext implements SpanContext {
  final _ActiveSpan _span;

  _DirectSpanContext(this._span);

  @override
  String get traceId => _span.traceId;

  @override
  String get spanId => _span.spanId;

  @override
  void setMetadata(Map<String, Object?> metadata) {
    metadata.forEach((key, value) {
      _span.attributes['genkit:metadata:$key'] = _encodeMetadata(value);
    });
  }
}
