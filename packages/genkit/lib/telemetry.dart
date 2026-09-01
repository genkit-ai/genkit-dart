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

/// Telemetry instrumentation for Genkit.
///
/// This library is the authoring surface for pluggable telemetry providers. Use
/// `configureInstrumentation` to register one or more `Instrumentation`
/// providers before creating `Genkit`. Providers compose as a middleware chain,
/// so multiple can be active at once.
///
/// ```dart
/// import 'package:genkit/telemetry.dart';
///
/// void main() {
///   configureInstrumentation(myInstrumentation());
///   final ai = Genkit(/* ... */);
/// }
/// ```
///
/// By default Genkit is not instrumented. In the dev environment the built-in
/// instrumentation (`genkitDevInstrumentation`) is auto-injected so the
/// Developer UI works out of the box. When a user has already initialized the
/// global OpenTelemetry SDK (backed by `package:dartastic_opentelemetry`), that
/// built-in routes Genkit's spans through it; otherwise it falls back to a
/// custom tracer that posts spans directly to the Genkit telemetry server.
library;

export 'src/o11y/direct_http_instrumentation.dart'
    show DirectHttpInstrumentation;
export 'src/o11y/genkit_dev_otel_instrumentation.dart'
    show GenkitDevOtelInstrumentation;

export 'src/o11y/instrumentation.dart'
    show
        Instrumentation,
        SpanContext,
        SpanMetadata,
        configureInstrumentation,
        isInstrumentedBy,
        resetInstrumentation,
        runInNewSpan,
        setCustomMetadataAttributes;
export 'src/o11y/instrumentation_setup.dart'
    show
        GenkitBuiltinInstrumentation,
        directHttpInstrumentation,
        genkitDevInstrumentation;
export 'src/o11y/telemetry/collector_http_sink.dart' show CollectorHttpSink;
export 'src/o11y/telemetry/span_data.dart'
    show
        GenkitSpanData,
        GenkitSpanKind,
        GenkitSpanStatus,
        GenkitStatusCode,
        SpanSink,
        encodeResourceSpans;
