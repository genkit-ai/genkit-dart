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

/// OpenTelemetry GenAI semantic-conventions instrumentation for Genkit.
///
/// Configure the `GenAiInstrumentation` provider before creating `Genkit`, and
/// let the application own the `dartastic_opentelemetry` SDK setup:
///
/// ```dart
/// import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
/// import 'package:genkit/genkit.dart';
/// import 'package:genkit/telemetry.dart';
/// import 'package:genkit_otel/genkit_otel.dart';
///
/// Future<void> main() async {
///   await OTel.initialize(
///     endpoint: 'http://localhost:4317',
///     serviceName: 'my-service',
///   );
///   configureInstrumentation(GenAiInstrumentation());
///   final ai = Genkit(/* ... */);
/// }
/// ```
///
/// It emits `gen_ai.*` spans and metrics following the
/// [OTel GenAI semantic conventions][spec]. It composes freely with the
/// built-in Genkit dev provider (they export to separate pipelines).
///
/// [spec]: https://github.com/open-telemetry/semantic-conventions-genai
library;

export 'src/genai_instrumentation.dart'
    show GenAiContentMode, GenAiInstrumentation;
