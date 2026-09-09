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

import 'direct_http_instrumentation.dart';
import 'instrumentation_api.dart';
import 'telemetry/collector_http_sink.dart';
import 'telemetry/span_data.dart';
import 'telemetry/telemetry_platform.dart';

/// Marker mixed into Genkit's built-in instrumentation so `Genkit` can detect
/// (via `isInstrumentedBy`) whether it has already been auto-injected, and
/// avoid double-instrumenting.
mixin GenkitBuiltinInstrumentation implements Instrumentation {}

class _DirectBuiltin extends DirectHttpInstrumentation
    with GenkitBuiltinInstrumentation {
  _DirectBuiltin(super.sink);
}

/// Creates Genkit's built-in Developer UI instrumentation, or `null` when there
/// is no telemetry server to export to (`GENKIT_TELEMETRY_SERVER` unset).
///
/// This built-in runs completely independently of OpenTelemetry: it uses a
/// dependency-free tracer that mints its own trace/span ids and posts spans
/// directly over HTTP to the Genkit telemetry server. Optional OpenTelemetry
/// instrumentation is provided separately.
Instrumentation? genkitDevInstrumentation() {
  final server = genkitTelemetryServerUrl();
  if (server == null) return null;
  return _DirectBuiltin(CollectorHttpSink('$server/api/otlp'));
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
