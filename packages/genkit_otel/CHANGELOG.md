## 0.1.0

- Initial release: `GenAiInstrumentation`, an OpenTelemetry GenAI
  semantic-conventions provider for Genkit built on `dartastic_opentelemetry`.
- Emits `gen_ai.*` client spans for model operations, optional `execute_tool`
  spans, and generic spans for other Genkit action types.
- Emits the GenAI client metrics `gen_ai.client.token.usage` and
  `gen_ai.client.operation.duration`.
- Optional message-content capture via `contentCapturingMode`
  (`noContent`/`spanOnly`/`eventOnly`/`spanAndEvent`), mirroring the OTel GenAI
  `ContentCapturingMode`. Off by default; when unset, the env var
  `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` is parsed using the
  spec's UPPER_SNAKE tokens.
