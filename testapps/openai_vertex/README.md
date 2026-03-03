# OpenAI Vertex Sample

This test app verifies `genkit_openai` against the Vertex AI OpenAI-compatible
endpoint.

By default it targets the GLM-5 model ID `zai-org/glm-5-maas`.

## Prerequisites

1. Install dependencies:

   ```bash
   dart pub get
   ```

2. Set required environment variables (one of):

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
   export VERTEX_ENDPOINT_ID="openapi"
   export VERTEX_OPENAI_MODEL="zai-org/glm-5-maas"
   export VERTEX_PROMPT="Reply with exactly: GLM-5 is online."
   ```

## Authentication Modes

### 1) ADC (default)

No extra app setting is required. ADC is resolved in this order:

- `GOOGLE_APPLICATION_CREDENTIALS`
- local credentials from `gcloud auth application-default login`
- metadata server (Workload Identity or attached service account)

Run:

```bash
dart run openai_vertex_sample
```

or:

```bash
dart run bin/openai_vertex_sample.dart
```

### 2) Service account file

```bash
export VERTEX_AUTH_MODE="service-account"
export VERTEX_SERVICE_ACCOUNT_PATH="/path/to/service-account.json"
dart run openai_vertex_sample
```

You can pass a prompt directly:

```bash
dart run openai_vertex_sample "Summarize transformer attention in 3 bullets."
```

## Notes

- The sample defaults to the `zai-org/glm-5-maas` model ID.
- Override model with `VERTEX_OPENAI_MODEL` for other partner models.
- OpenAPI endpoint models must use `<publisher>/<model>` format.
