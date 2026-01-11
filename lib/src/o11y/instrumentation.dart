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

final _tracer = api.globalTracerProvider.getTracer('genkit-dart');

typedef TelemetryContext = ({
  Map<String, String> attributes,
  String traceId,
  String spanId,
});

Future<O> runInNewSpan<I, O>(
  String name,
  Future<O> Function(TelemetryContext) fn, {
  String? actionType,
  I? input,
  Map<String, String>? attributes,
}) async {
  final parentContext = Zone.current[#api.context] as api.Context?;
  final span = parentContext == null
      ? _tracer.startSpan(name)
      : _tracer.startSpan(name, context: parentContext);
  return runZoned(
    () async {
      try {
        span.setName(name);
        span.setAttribute(api.Attribute.fromString('genkit:name', name));
        if (actionType != null) {
          span.setAttribute(
            api.Attribute.fromString('genkit:type', actionType),
          );
          // tmp hack...
          if (actionType == 'flow') {
            span.setAttribute(
              api.Attribute.fromString('genkit:metadata:flow:name', name),
            );
          }
        }
        if (input != null) {
          try {
            span.setAttribute(
              api.Attribute.fromString('genkit:input', jsonEncode(input)),
            );
          } catch (e) {
            span.setAttribute(
              api.Attribute.fromString(
                  'genkit:input', 'Unable to encode input: $e'),
            );
          }
        }
        attributes?.forEach((key, value) {
          span.setAttribute(api.Attribute.fromString(key, value));
        });
        final telemetryContext = (
          attributes: <String, String>{},
          traceId: span.spanContext.traceId.toString(),
          spanId: span.spanContext.spanId.toString(),
        );
        final output = await fn(telemetryContext);
        telemetryContext.attributes.forEach((key, value) {
          span.setAttribute(api.Attribute.fromString(key, value));
        });
        try {
          span.setAttribute(
            api.Attribute.fromString('genkit:output', jsonEncode(output)),
          );
        } catch (e) {
          // Ignore json encoding errors for output
          span.setAttribute(
            api.Attribute.fromString(
                'genkit:output', 'Unable to encode output: $e'),
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
    zoneValues: {#api.context: api.contextWithSpan(api.Context.current, span)},
  );
}
