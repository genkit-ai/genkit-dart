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
import 'instrumentation.dart' show configureInstrumentation, isInstrumentedBy;
import 'instrumentation_api.dart';
import 'telemetry/collector_http_sink.dart';
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

/// Enables the built-in dev instrumentation targeting [server], as requested by
/// the CLI reflection handshake (`telemetryServerUrl`).
///
/// The `GENKIT_TELEMETRY_SERVER` environment variable takes precedence: when it
/// is set, the env-configured instrumentation wins and this is a no-op. Also a
/// no-op when a built-in provider is already registered, so repeated handshakes
/// never double-instrument.
void enableDevInstrumentationForServer(String server) {
  if (server.isEmpty) return;
  // Env var wins; if set, the dev instrumentation is already configured off it.
  if (genkitTelemetryServerUrl() != null) return;
  if (isInstrumentedBy<GenkitBuiltinInstrumentation>()) return;
  configureInstrumentation(
    _DirectBuiltin(CollectorHttpSink('$server/api/otlp')),
  );
}
