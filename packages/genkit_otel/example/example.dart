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
import 'package:genkit_otel/genkit_otel.dart';

/// Wires OpenTelemetry GenAI instrumentation into a Genkit app.
///
/// Uses a plain flow so the example stays dependency-free; add a model plugin
/// and call `ai.generate(...)` to get the `gen_ai.*` model spans and the token
/// usage / operation duration metrics. See testapps/otel_jaeger for that, plus
/// a Docker-free Jaeger + collector stack to view the output.
Future<void> main() async {
  // The application owns the OTel SDK. With no arguments this reads the
  // standard OTEL_* env vars and defaults to http://localhost:4318.
  await OTel.initialize();

  // dartastic logs an '[ERROR] Tracer: Exception in withSpanAsync ...' line for
  // every exception crossing a span. It is still recorded and rethrown; this
  // just quiets the diagnostic noise.
  OTelLog.currentLevel = LogLevel.fatal;

  // Content capture is opt-in because prompts and responses may contain PII.
  // Unset consults OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT.
  configureInstrumentation(
    GenAiInstrumentation(contentCapturingMode: .spanOnly),
  );

  final ai = Genkit();

  final greet = ai.defineFlow(
    name: 'greet',
    inputSchema: .string(defaultValue: 'World'),
    outputSchema: .string(),
    fn: (String subject, _) async => 'hello $subject',
  );

  print(await greet('World'));

  // Genkit disposes instrumentation; OTel flushes spans and metrics.
  await OTel.shutdown();
}
