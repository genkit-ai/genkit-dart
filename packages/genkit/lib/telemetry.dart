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
/// By default Genkit is not instrumented. In the dev environment a built-in
/// provider is auto-injected only when a Genkit telemetry server is configured
/// (via the `GENKIT_TELEMETRY_SERVER` environment variable, or the CLI
/// reflection handshake), so the Developer UI receives traces. That built-in
/// runs independently of OpenTelemetry, posting Genkit's spans directly to the
/// server over HTTP. It also bridges `package:logging` records (correlated with
/// the active span) to the server so logs show up in the Developer UI; that
/// logging bridge is an implementation detail of the built-in provider, not a
/// behavior of Genkit core. In production, configure a provider explicitly with
/// `configureInstrumentation`.
///
/// A provider that holds resources (subscriptions, clients) can implement
/// `DisposableInstrumentation`; Genkit disposes it on `Genkit.shutdown()`.
///
/// Plugins can open spans of their own with `runInNewSpan` (e.g. one per
/// HTTP request to a model API). The span goes to every configured provider
/// and nests under the active span. The function's return value is recorded
/// as the span output (providers JSON-encode it), and an error it throws is
/// recorded on the span and rethrown. The span ends when the returned future
/// completes, so for a streaming call don't return the `Stream` or
/// `StreamedResponse` from inside the span: return something encodable
/// instead (the collected chunks, or a placeholder like JS's
/// `'[Streaming Response]'`). With no provider configured, `runInNewSpan` is
/// effectively a no-op.
///
/// For OpenTelemetry GenAI semantic-convention telemetry, add the
/// `genkit_otel` package and configure its `GenAiInstrumentation` provider. It
/// is built on the `dartastic_opentelemetry` SDK, which the application owns and
/// initializes; it composes freely with the built-in dev provider.
library;

// The type of runInNewSpan's `actionType`; the same declaration genkit.dart
// and plugin.dart export, so importing several of them doesn't conflict.
export 'src/core/action_type.dart' show ActionType;
export 'src/o11y/instrumentation.dart'
    show
        DisposableInstrumentation,
        Instrumentation,
        SpanContext,
        SpanMetadata,
        configureInstrumentation,
        runInNewSpan;
