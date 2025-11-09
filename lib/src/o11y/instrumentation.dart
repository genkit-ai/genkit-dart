import 'dart:async';
import 'dart:convert';

import 'package:opentelemetry/api.dart' as api;

final _tracer = api.globalTracerProvider.getTracer('genkit-dart');

typedef TelemetryContext = ({Map<String, String> attributes});

Future<O> runInNewSpan<I, O>(
  String name,
  Future<O> Function(TelemetryContext) fn, {
  String? actionType,
  I? input,
  Map<String, String>? attributes,
}) async {
  final span = _tracer.startSpan(name);
  try {
    span.setAttribute(api.Attribute.fromString('genkit:name', name));
    if (actionType != null) {
      span.setAttribute(api.Attribute.fromString('genkit:type', actionType));
    }
    if (input != null) {
      span.setAttribute(
          api.Attribute.fromString('genkit:input', jsonEncode(input)));
    }
    attributes?.forEach((key, value) {
      span.setAttribute(api.Attribute.fromString(key, value));
    });
    final telemetryContext = (attributes: <String, String>{});
    final output = await fn(telemetryContext);
    telemetryContext.attributes.forEach((key, value) {
      span.setAttribute(api.Attribute.fromString(key, value));
    });
    span.setAttribute(
      api.Attribute.fromString('genkit:output', jsonEncode(output)),
    );
    return output;
  } catch (e, s) {
    span
      ..setStatus(api.StatusCode.error, e.toString())
      ..recordException(e, stackTrace: s);
    rethrow;
  } finally {
    span.end();
  }
}
