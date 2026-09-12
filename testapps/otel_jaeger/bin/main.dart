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

  // captureContent is opt-in (it may contain PII). span mode is the easiest to
  // eyeball in Jaeger; switch to GenAiContentMode.event to keep bodies off the
  // span.
  configureInstrumentation(
    GenAiInstrumentation(
      captureContent: true,
      contentMode: GenAiContentMode.span,
      emitMetrics: false,
    ),
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
