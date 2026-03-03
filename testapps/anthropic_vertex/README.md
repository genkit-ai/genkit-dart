# Anthropic Vertex AI Sample

This test app verifies `genkit_anthropic` against Claude models hosted on Vertex AI.

## Prerequisites

1. Install dependencies:

   ```bash
   dart pub get
   ```

2. Set required environment variables:

   ```bash
   export VERTEX_PROJECT_ID="your-gcp-project"
   ```

   You can also use:

   ```bash
   export GOOGLE_CLOUD_PROJECT="your-gcp-project"
   ```

   or:

   ```bash
   export GCLOUD_PROJECT="your-gcp-project"
   ```

3. Optional settings:

   ```bash
   export VERTEX_LOCATION="global"
   export VERTEX_ANTHROPIC_MODEL="claude-sonnet-4-5"
   export VERTEX_PROMPT="Explain RAG in three bullets."
   ```

## Authentication Modes

### 1) ADC (default)

No extra app setting is required. ADC is resolved in this order:

- `GOOGLE_APPLICATION_CREDENTIALS`
- local credentials from `gcloud auth application-default login`
- metadata server (Workload Identity or attached service account)

Run:

```bash
dart run anthropic_vertex_sample
```

or:

```bash
dart run bin/anthropic_vertex_sample.dart
```

### 2) Service account file

```bash
export VERTEX_AUTH_MODE="service-account"
export VERTEX_SERVICE_ACCOUNT_PATH="/path/to/service-account.json"
dart run anthropic_vertex_sample
```

You can also pass a prompt directly:

```bash
dart run anthropic_vertex_sample "Summarize the benefits of Vertex-hosted Claude."
```

or:

```bash
dart run bin/anthropic_vertex_sample.dart "Summarize the benefits of Vertex-hosted Claude."
```

## Common Errors

- `NOT_FOUND`: model might not be enabled for your project, or model name is invalid.
- `RESOURCE_EXHAUSTED` / `429`: project quota is exhausted for the selected model/location.
