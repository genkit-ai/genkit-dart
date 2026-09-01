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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;

import 'span_data.dart';

/// Bridges OpenTelemetry spans to Genkit's backend-agnostic [SpanSink].
///
/// When Genkit participates in a global OpenTelemetry setup, spans are produced
/// by the OTel SDK. This exporter lowers each [otel.Span] into a
/// [GenkitSpanData] and forwards it to the sink, which serializes to OTLP/JSON
/// and posts to the Genkit telemetry server. We keep our own exporter rather
/// than the SDK's built-in OTLP HTTP exporter because the latter targets the
/// standard `/v1/traces` path, whereas the Genkit server expects `/api/otlp`.
class GenkitOtlpSpanExporter implements otel.SpanExporter {
  final SpanSink _sink;
  bool _isShutdown = false;

  GenkitOtlpSpanExporter(this._sink);

  @override
  Future<void> export(List<otel.Span> spans) async {
    if (_isShutdown || spans.isEmpty) return;
    _sink.export(spans.map(_toSpanData).toList());
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
    _sink.shutdown();
  }

  GenkitSpanData _toSpanData(otel.Span span) {
    final parentSpanId = span.parentSpanContext?.spanId.toString();
    return GenkitSpanData(
      traceId: span.spanContext.traceId.toString(),
      spanId: span.spanContext.spanId.toString(),
      parentSpanId: parentSpanId,
      name: span.name,
      kind: _toKind(span.kind),
      startTimeUnixNano: _toUnixNano(span.startTime),
      endTimeUnixNano: span.endTime == null ? 0 : _toUnixNano(span.endTime!),
      // The SDK marks Span.attributes @visibleForTesting since there is no
      // other public accessor; reading it here is the only way to serialize a
      // finished span's attributes, and the SDK's own transformer does the same.
      // ignore: invalid_use_of_visible_for_testing_member
      attributes: _toAttributeMap(span.attributes),
      status: GenkitSpanStatus(
        code: _toStatusCode(span.status),
        message: span.statusDescription,
      ),
      scopeName: span.instrumentationScope.name,
      scopeVersion: span.instrumentationScope.version,
      resourceAttributes: span.resource == null
          ? const {}
          : _toAttributeMap(span.resource!.attributes),
    );
  }

  static int _toUnixNano(DateTime time) => time.microsecondsSinceEpoch * 1000;

  static Map<String, Object?> _toAttributeMap(otel.Attributes attributes) {
    final result = <String, Object?>{};
    for (final attr in attributes.toList()) {
      result[attr.key] = attr.value;
    }
    return result;
  }

  static GenkitSpanKind _toKind(otel.SpanKind kind) {
    return switch (kind) {
      otel.SpanKind.internal => GenkitSpanKind.internal,
      otel.SpanKind.server => GenkitSpanKind.server,
      otel.SpanKind.client => GenkitSpanKind.client,
      otel.SpanKind.producer => GenkitSpanKind.producer,
      otel.SpanKind.consumer => GenkitSpanKind.consumer,
    };
  }

  static GenkitStatusCode _toStatusCode(otel.SpanStatusCode code) {
    return switch (code) {
      otel.SpanStatusCode.Ok => GenkitStatusCode.ok,
      otel.SpanStatusCode.Error => GenkitStatusCode.error,
      otel.SpanStatusCode.Unset => GenkitStatusCode.unset,
    };
  }
}

/// A [otel.SpanProcessor] that exports each span the moment it starts and again
/// when it ends.
///
/// The Genkit Developer UI expects spans to appear live as an operation runs,
/// so we do not buffer: `onStart` streams the freshly opened span and `onEnd`
/// streams the finished one.
class RealtimeSpanProcessor implements otel.SpanProcessor {
  final otel.SpanExporter _exporter;

  RealtimeSpanProcessor(this._exporter);

  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {
    await _exporter.export([span]);
  }

  @override
  Future<void> onEnd(otel.Span span) async {
    await _exporter.export([span]);
  }

  @override
  Future<void> onNameUpdate(otel.Span span, String newName) async {}

  @override
  Future<void> forceFlush() async {
    await _exporter.forceFlush();
  }

  @override
  Future<void> shutdown() async {
    await _exporter.shutdown();
  }
}
