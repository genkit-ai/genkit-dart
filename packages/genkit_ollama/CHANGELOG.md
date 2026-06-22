## 0.1.0

- Initial release of the Genkit Ollama plugin.
- Chat generation with real-time streaming.
- Tool/function calling.
- Vision (multimodal image) input.
- Text embeddings with automatic dimension discovery via `/api/show`.
- Constrained (JSON-schema) output.
- Per-model capability metadata from `/api/show` and dynamic model discovery
  via `/api/tags`.
- Configurable `baseUrl`, static headers, and an async headers provider for
  authenticated remote servers.
