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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_otel/genkit_otel.dart';

/// A minimal Genkit app wired to OpenTelemetry GenAI instrumentation.
///
/// Run the local telemetry stack first (`dart run tool/telemetry.dart`), then
/// this app. Traces land in Jaeger (http://localhost:16686) and metrics in the
/// collector debug log. See README.md.
Future<void> main() async {
  // The application owns the OTel SDK. With no arguments it reads the standard
  // OTEL_* env vars and otherwise defaults to http://localhost:4318 (OTLP
  // http/protobuf), which the local collector from tool/telemetry.dart accepts.
  //
  // Override via env, e.g.:
  //   OTEL_SERVICE_NAME=genkit-otel-sample
  //   OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
  //   OTEL_EXPORTER_OTLP_PROTOCOL=grpc
  await OTel.initialize();

  // Quiet dartastic's internal diagnostic logger. By default it prints an
  // '[ERROR] Tracer: Exception in withSpanAsync ...' line for every
  // exception that passes through a span, which can look like the
  // instrumentation itself failed. The exception is still recorded on the
  // span and rethrown to the caller. Apps can also set OTEL_LOG_LEVEL.
  OTelLog.currentLevel = LogLevel.fatal;

  // Content capture is opt-in (it may contain PII). spanOnly is the easiest to
  // eyeball in Jaeger; eventOnly emits a logs-signal event Jaeger can't show,
  // spanAndEvent does both. Unset consults
  // OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT.
  configureInstrumentation(
    GenAiInstrumentation(contentCapturingMode: .spanOnly, emitMetrics: false),
  );

  final ai = Genkit(plugins: [googleAI()]);

  final response = await ai.generate(
    model: googleAI.gemini('gemini-flash-latest'),
    prompt: 'Explain OpenTelemetry in one sentence.',
  );
  print(response.text);

  // Flush and shut down: Genkit disposes instrumentation, OTel flushes spans
  // and metrics to the collector.
  await ai.shutdown();
  await OTel.shutdown();
}
