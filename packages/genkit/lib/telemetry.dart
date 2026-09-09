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
library;

export 'src/o11y/instrumentation.dart'
    show
        DisposableInstrumentation,
        Instrumentation,
        SpanContext,
        SpanMetadata,
        configureInstrumentation;
