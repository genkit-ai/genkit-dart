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
import 'package:logging/logging.dart';

import 'direct_http_instrumentation.dart';
import 'genkit_dev_otel_instrumentation.dart';
import 'instrumentation_api.dart';
import 'telemetry/collector_http_sink.dart';
import 'telemetry/otel_span_exporter.dart';
import 'telemetry/span_data.dart';
import 'telemetry/telemetry_platform.dart';

final _logger = Logger('GenkitInstrumentation');

/// The instrumentation scope name Genkit uses for its own spans.
const _genkitTracerName = 'genkit-dart';

/// The name of the tracer provider Genkit attaches its exporter to when a user
/// already owns the global OpenTelemetry setup.
const _genkitProviderName = 'genkit';

/// Marker mixed into Genkit's built-in instrumentation so `Genkit` can detect
/// (via `isInstrumentedBy`) whether it has already been auto-injected, and
/// avoid double-instrumenting.
mixin GenkitBuiltinInstrumentation implements Instrumentation {}

class _DirectBuiltin extends DirectHttpInstrumentation
    with GenkitBuiltinInstrumentation {
  _DirectBuiltin(super.sink);
}

class _GenkitDevOtelBuiltin extends GenkitDevOtelInstrumentation
    with GenkitBuiltinInstrumentation {
  _GenkitDevOtelBuiltin(super.tracer);
}

/// Creates Genkit's built-in Developer UI instrumentation, or `null` when there
/// is no telemetry server to export to (`GENKIT_TELEMETRY_SERVER` unset).
///
/// Two paths, matching the telemetry design:
///
///  - If a user has already initialized the global OpenTelemetry SDK, Genkit
///    participates: it attaches its own OTLP-JSON exporter to a dedicated
///    `'genkit'` tracer provider (so it reaches the Genkit server without
///    disturbing the user's default pipeline) and routes spans through it.
///  - Otherwise Genkit cannot construct a standalone provider (the SDK is
///    global-and-async-init only), so it falls back to a fully custom,
///    dependency-free tracer that posts spans directly over HTTP.

Instrumentation? genkitDevInstrumentation() {
  final server = genkitTelemetryServerUrl();
  if (server == null) return null;

  final sink = CollectorHttpSink('$server/api/otlp');

  if (_globalOtelInitialized()) {
    try {
      final provider = otel.OTel.addTracerProvider(_genkitProviderName)
        ..addSpanProcessor(RealtimeSpanProcessor(GenkitOtlpSpanExporter(sink)));
      final tracer = provider.getTracer(_genkitTracerName);
      _logger.fine(
        'Global OpenTelemetry detected; routing Genkit traces through a '
        'dedicated tracer provider.',
      );
      return _GenkitDevOtelBuiltin(tracer);
    } catch (e, stackTrace) {
      // If participating in the global setup fails for any reason, fall back to
      // the custom tracer rather than losing telemetry entirely.
      _logger.warning(
        'Failed to attach to global OpenTelemetry; falling back to the '
        'direct HTTP tracer.',
        e,
        stackTrace,
      );
    }
  }

  return _DirectBuiltin(sink);
}

/// Whether the OpenTelemetry SDK has been globally initialized by someone else.
///
/// The SDK auto-installs a no-op *API* factory on first use; a real SDK factory
/// (`isAPIFactory == false`) only appears after `OTel.initialize()`.

bool _globalOtelInitialized() {
  final factory = otel.OTelFactory.otelFactory;
  return factory != null && !factory.isAPIFactory;
}

/// Builds a [DirectHttpInstrumentation] that posts to [server]`/api/otlp`.
///
/// Exposed for tests and advanced callers that want the custom tracer without
/// the dev-environment auto-detection.
Instrumentation directHttpInstrumentation(String server, {SpanSink? sink}) {
  return DirectHttpInstrumentation(
    sink ?? CollectorHttpSink('$server/api/otlp'),
  );
}
