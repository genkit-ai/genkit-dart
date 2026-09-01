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

/// Backend-agnostic span data and the sink abstraction Genkit exports through.
///
/// This layer deliberately carries no OpenTelemetry dependency: both the
/// custom direct-HTTP tracer and the OpenTelemetry-backed instrumentation lower
/// their spans into [GenkitSpanData] and hand them to a [SpanSink]. The sink

/// (see `collector_http_sink.dart`) is what actually serializes to OTLP JSON
/// and ships spans to the Genkit telemetry server.
library;

/// OpenTelemetry span kind, mirrored as a plain enum so we avoid leaking any
/// OTel types into this layer.
enum GenkitSpanKind { internal, server, client, producer, consumer }

/// OpenTelemetry status code, mirrored as a plain enum.
enum GenkitStatusCode { unset, ok, error }

/// The status of a finished span.
class GenkitSpanStatus {
  final GenkitStatusCode code;
  final String? message;

  const GenkitSpanStatus({this.code = GenkitStatusCode.unset, this.message});
}

/// A finished span, ready to be serialized and exported.
///
/// Timestamps are Unix nanoseconds since epoch (the OTLP wire unit).
class GenkitSpanData {
  final String traceId;
  final String spanId;

  /// The parent span id, or `null`/empty for a root span.
  final String? parentSpanId;

  final String name;
  final GenkitSpanKind kind;

  final int startTimeUnixNano;
  final int endTimeUnixNano;

  /// Attribute values are plain Dart scalars (String/bool/int/double) or, as a
  /// fallback, anything with a sensible `toString()`.
  final Map<String, Object?> attributes;

  final GenkitSpanStatus status;

  /// Instrumentation scope (OTLP `scope`).
  final String scopeName;
  final String? scopeVersion;

  /// Resource attributes (e.g. `service.name`). May be empty.
  final Map<String, Object?> resourceAttributes;

  const GenkitSpanData({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    this.kind = GenkitSpanKind.internal,
    required this.startTimeUnixNano,
    required this.endTimeUnixNano,
    this.attributes = const {},
    this.status = const GenkitSpanStatus(),
    this.scopeName = 'genkit-dart',
    this.scopeVersion,
    this.resourceAttributes = const {},
  });
}

/// A destination for finished spans.
///
/// This is the single "accepts spans, routes them somewhere" seam described in
/// the telemetry design: whether spans originate from the custom tracer or from
/// OpenTelemetry, they funnel through a [SpanSink]. Soon this will also carry
/// logs.

abstract interface class SpanSink {
  /// Exports [spans]. Implementations are expected to be non-blocking
  /// (fire-and-forget) so instrumentation never stalls the traced operation.
  void export(List<GenkitSpanData> spans);

  /// Releases resources; subsequent [export] calls should be no-ops.
  void shutdown();
}

/// Serializes [spans] into the OTLP/JSON `resourceSpans` structure expected by
/// the Genkit telemetry server's `/api/otlp` endpoint.
///
/// Spans are grouped by resource attributes and then by instrumentation scope,
/// matching the OTLP wire shape.
List<Map<String, dynamic>> encodeResourceSpans(List<GenkitSpanData> spans) {
  // Group by resource (keyed by a stable string) then by scope. We key on the
  // rendered attribute map since GenkitSpanData carries plain maps rather than
  // identity-comparable resource objects.
  final byResource = <String, _ResourceGroup>{};

  for (final span in spans) {
    final resourceKey = _stableKey(span.resourceAttributes);
    final group = byResource.putIfAbsent(
      resourceKey,
      () => _ResourceGroup(span.resourceAttributes),
    );
    final scopeKey = '${span.scopeName}:${span.scopeVersion ?? ''}';
    final scope = group.scopes.putIfAbsent(
      scopeKey,
      () => _ScopeGroup(span.scopeName, span.scopeVersion),
    );
    scope.spans.add(_encodeSpan(span));
  }

  return byResource.values.map((group) {
    return {
      'resource': {
        'attributes': _encodeAttributes(group.resourceAttributes),
        'droppedAttributesCount': 0,
      },
      'scopeSpans': group.scopes.values.map((scope) {
        return {
          // The telemetry server maps `scope` to `instrumentationLibrary` and
          // requires a string version, so coalesce a null version to ''.
          'scope': {'name': scope.name, 'version': scope.version ?? ''},
          'spans': scope.spans,
        };
      }).toList(),
    };
  }).toList();
}

class _ResourceGroup {
  final Map<String, Object?> resourceAttributes;
  final Map<String, _ScopeGroup> scopes = {};
  _ResourceGroup(this.resourceAttributes);
}

class _ScopeGroup {
  final String name;
  final String? version;
  final List<Map<String, dynamic>> spans = [];
  _ScopeGroup(this.name, this.version);
}

String _stableKey(Map<String, Object?> map) {
  final keys = map.keys.toList()..sort();
  return keys.map((k) => '$k=${map[k]}').join('\u0000');
}

Map<String, dynamic> _encodeSpan(GenkitSpanData span) {
  final map = <String, dynamic>{
    'traceId': span.traceId,
    'spanId': span.spanId,
    'name': span.name,
    'kind': _encodeKind(span.kind),
    'startTimeUnixNano': span.startTimeUnixNano.toString(),
    'endTimeUnixNano': span.endTimeUnixNano.toString(),
    'attributes': _encodeAttributes(span.attributes),
    'droppedAttributesCount': 0,
    'events': [],
    'droppedEventsCount': 0,
    'status': _encodeStatus(span.status),
    'links': [],
    'droppedLinksCount': 0,
  };
  final parent = span.parentSpanId;
  if (parent != null && parent.isNotEmpty && !_isZeroId(parent)) {
    map['parentSpanId'] = parent;
  }
  return map;
}

bool _isZeroId(String id) => RegExp(r'^0+$').hasMatch(id);

int _encodeKind(GenkitSpanKind kind) {
  return switch (kind) {
    GenkitSpanKind.internal => 1,
    GenkitSpanKind.server => 2,
    GenkitSpanKind.client => 3,
    GenkitSpanKind.producer => 4,
    GenkitSpanKind.consumer => 5,
  };
}

Map<String, dynamic> _encodeStatus(GenkitSpanStatus status) {
  final code = switch (status.code) {
    GenkitStatusCode.ok => 1,
    GenkitStatusCode.error => 2,
    GenkitStatusCode.unset => 0,
  };
  return {'code': code, 'message': status.message};
}

List<Map<String, dynamic>> _encodeAttributes(Map<String, Object?> attributes) {
  final result = <Map<String, dynamic>>[];
  attributes.forEach((key, value) {
    result.add({'key': key, 'value': _encodeAttributeValue(value)});
  });
  return result;
}

Map<String, dynamic> _encodeAttributeValue(Object? value) {
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'boolValue': value};
  if (value is int) return {'intValue': value};
  if (value is double) return {'doubleValue': value};
  return {'stringValue': value.toString()};
}
