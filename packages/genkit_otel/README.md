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

### SDK logging

dartastic's internal logger defaults to printing an
`[ERROR] Tracer: Exception in withSpanAsync ...` line for every exception that
flows through a span. The exception is still recorded and rethrown; the line is
just diagnostic noise. To quiet it, lower the level after `OTel.initialize()`:

```dart
OTelLog.currentLevel = LogLevel.fatal; // or set OTEL_LOG_LEVEL=fatal
```

## Content capture (PII)

Prompt and response content may contain PII, so capture is off by default.
`contentCapturingMode` mirrors the OTel GenAI `ContentCapturingMode`:

| Mode | Where content goes |
| --- | --- |
| `noContent` (default) | not captured |
| `spanOnly` | span attributes (`gen_ai.*.messages`) as JSON strings |
| `eventOnly` | a `gen_ai.client.inference.operation.details` log event |
| `spanAndEvent` | both |

```dart
GenAiInstrumentation(
  contentCapturingMode: ContentCapturingMode.spanOnly,
);
```

When not supplied, the env var `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`
is consulted using the spec's UPPER_SNAKE tokens (`NO_CONTENT`, `SPAN_ONLY`,
`EVENT_ONLY`, `SPAN_AND_EVENT`); an explicit value overrides it. An unknown
token logs a one-time warning and falls back to `NO_CONTENT`.

> `EVENT_ONLY` emits content on the OpenTelemetry logs signal (a
> `gen_ai.client.inference.operation.details` log record), not on the span.
> Trace-only backends like Jaeger cannot display it (its GenAI tab reads span
> attributes; its "Trace Logs" tab reads span events, neither is the logs
> signal). Use `SPAN_ONLY` or `SPAN_AND_EVENT` for Jaeger, or a logs backend
> (e.g. Loki, Elasticsearch/OpenSearch) for `EVENT_ONLY`.

## Options

| Option | Default | Description |
| --- | --- | --- |
| `contentCapturingMode` | env or `noContent` | Where spec-shaped `gen_ai.*` message content is recorded (`noContent`/`spanOnly`/`eventOnly`/`spanAndEvent`). |
| `captureActionIO` | `false` | Capture raw Genkit input/output as `genkit.input`/`genkit.output` on every span (debugging / Dev UI). |
| `emitMetrics` | `true` | Emit token-usage and operation-duration metrics. |
| `emitToolSpans` | `false` | Emit `execute_tool` spans for tool actions. |
| `scopeName` | `genkit-genai` | Instrumentation scope for tracer/meter/logger. |
| `tracer` / `meter` | resolved lazily | Escape hatches to inject explicit instances. |

## Example

See [`testapps/otel_jaeger`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/otel_jaeger)
for a runnable sample that exports traces to Jaeger and metrics to a local
collector, with a Docker-free script that downloads and runs both.
