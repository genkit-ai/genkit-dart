## 0.2.0-rc.2

 - updated internal dependencies.

## 0.2.0-rc.1

### Breaking Changes

 - type usage counts and indexes as int (#546)

### Other Changes

 - add Genkit Dart agent skill install instructions to READMEs (#521)


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
