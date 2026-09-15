# genkit_otel

OpenTelemetry GenAI semantic-conventions instrumentation for
[Genkit Dart](https://github.com/genkit-ai/genkit-dart), built on the
[`dartastic_opentelemetry`](https://pub.dev/packages/dartastic_opentelemetry)
SDK.

It plugs into Genkit's pluggable instrumentation system and emits telemetry that
follows the
[OTel GenAI semantic conventions](https://github.com/open-telemetry/semantic-conventions-genai):

- `gen_ai.*` client spans for model operations (`chat <model>`), with request
  config, token usage, and finish reasons.
- The GenAI client metrics `gen_ai.client.token.usage` (split by
  `gen_ai.token.type`) and `gen_ai.client.operation.duration`.
- Optional message-content capture, either as span attributes or a dedicated
  `gen_ai.client.inference.operation.details` event.
- Optional `execute_tool` spans, and generic spans for other Genkit action
  types so the trace tree stays connected.

## Usage

The application owns the OpenTelemetry SDK. Initialize it, then register the
provider before creating `Genkit`:

```dart
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/telemetry.dart';
import 'package:genkit_otel/genkit_otel.dart';

Future<void> main() async {
  // Reads OTEL_* env vars; defaults to http://localhost:4318.
  await OTel.initialize();

  configureInstrumentation(GenAiInstrumentation());

  final ai = Genkit(/* plugins: [...] */);
  // ...
  await ai.shutdown();
  await OTel.shutdown(); // flushes spans and metrics
}
```

When the SDK is not initialized, the provider is effectively a no-op.

## Content capture (PII)

Prompt and response content may contain PII, so capture is off by default.
Enable it explicitly or via the spec's env var
`OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=true`:

```dart
GenAiInstrumentation(
  captureContent: true,
  // event (default): a single operation.details event keeps bodies off the span
  // span: content attached to the span as gen_ai.* attributes
  contentMode: GenAiContentMode.span,
);
```

## Options

| Option | Default | Description |
| --- | --- | --- |
| `captureContent` | env or `false` | Capture spec-shaped `gen_ai.*` message content on model spans. |
| `contentMode` | `event` | Where model content is recorded (`event` or `span`). |
| `captureActionIO` | `false` | Capture raw Genkit input/output as `genkit.input`/`genkit.output` on every span (debugging / Dev UI). |
| `emitMetrics` | `true` | Emit token-usage and operation-duration metrics. |
| `emitToolSpans` | `false` | Emit `execute_tool` spans for tool actions. |
| `scopeName` | `genkit-genai` | Instrumentation scope for tracer/meter/logger. |
| `tracer` / `meter` | resolved lazily | Escape hatches to inject explicit instances. |

## Example

See [`testapps/otel_jaeger`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/otel_jaeger)
for a runnable sample that exports traces to Jaeger and metrics to a local
collector, with a Docker-free script that downloads and runs both.
