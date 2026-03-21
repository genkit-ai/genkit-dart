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

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

final _tracer = OTelAPI.tracer('genkit-dart');

typedef TelemetryContext = ({
  Map<String, String> attributes,
  String traceId,
  String spanId,
});

Future<Output> runInNewSpan<Input, Output>(
  String name,
  Future<Output> Function(TelemetryContext) fn, {
  String? actionType,
  Input? input,
  Map<String, String>? attributes,
}) async {
  final spanAttributes = <Attribute>[];
  spanAttributes.add(OTelAPI.attributeString('genkit:name', name));
  if (actionType != null) {
    spanAttributes.addAll([
      OTelAPI.attributeString('genkit:type', actionType),
      // tmp hack...
      if (actionType == 'flow')
        OTelAPI.attributeString('genkit:metadata:flow:name', name),
    ]);
  }
  if (input != null) {
    try {
      spanAttributes.add(
        OTelAPI.attributeString('genkit:input', jsonEncode(input)),
      );
    } catch (e) {
      spanAttributes.add(
        OTelAPI.attributeString('genkit:input', 'Unable to encode input: $e'),
      );
    }
  }
  attributes?.forEach((key, value) {
    spanAttributes.add(OTelAPI.attributeString(key, value));
  });

  final span = _tracer.startSpan(
    name,
    attributes: OTelAPI.attributes(spanAttributes),
  );

  return Context.current.withSpan(span).run(() async {
    try {
      final telemetryContext = (
        attributes: <String, String>{},
        traceId: span.spanContext.traceId.toString(),
        spanId: span.spanContext.spanId.toString(),
      );
      final output = await fn(telemetryContext);
      telemetryContext.attributes.forEach(span.setStringAttribute);
      try {
        span.setStringAttribute('genkit:output', jsonEncode(output));
      } catch (e) {
        // Ignore json encoding errors for output
        span.setStringAttribute('genkit:output', 'Unable to encode output: $e');
      }
      return output;
    } catch (e, s) {
      span
        ..setStatus(SpanStatusCode.Error, e.toString())
        ..recordException(e, stackTrace: s);
      rethrow;
    } finally {
      span.end();
    }
  });
}
