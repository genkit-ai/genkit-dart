# Genkit Ollama Plugin

Run local LLMs and embedding models with [Genkit](https://genkit.dev) via an
[Ollama](https://ollama.com) server.

Supports chat, real-time streaming, tool/function calling, vision (multimodal)
input, text embeddings, constrained (JSON-schema) output, and dynamic model
discovery.

## Setup

1. Install Ollama: https://ollama.com/download
2. Start the server and pull a model:

   ```sh
   ollama serve
   ollama pull llama3.2
   ollama pull nomic-embed-text   # for embeddings
   ```

3. Add the dependency:

   ```sh
   dart pub add genkit_ollama
   ```

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_ollama/genkit_ollama.dart';

final ai = Genkit(plugins: [ollama()]);

final response = await ai.generate(
  model: ollama.model('llama3.2'),
  prompt: 'Hello!',
);
print(response.text);
```

By default the plugin connects to `http://localhost:11434`. Point it elsewhere
with `baseUrl`:

```dart
ollama(baseUrl: 'http://my-server:11434');
```

### Streaming

```dart
final stream = ai.generateStream(
  model: ollama.model('llama3.2'),
  prompt: 'Tell me a story.',
);
await for (final chunk in stream) {
  stdout.write(chunk.text);
}
```

### Configuration

`ollama.model` accepts an `OllamaChatOptions` config, including two Ollama knobs
(`numCtx`, `keepAlive`) beyond the common generation options:

```dart
await ai.generate(
  model: ollama.model('llama3.2'),
  prompt: 'Summarize this.',
  config: OllamaChatOptions(
    temperature: 0.6,
    topK: 40,
    topP: 0.9,
    numCtx: 8192,       // context window size
    keepAlive: '5m',    // keep the model loaded for 5 minutes
    stop: ['\n\n'],
  ),
);
```

### Embeddings

The embedding dimension is discovered automatically from the server; you can
also declare it explicitly.

```dart
final embeddings = await ai.embed(
  embedder: ollama.embedder('nomic-embed-text'),
  document: DocumentData(content: [TextPart(text: 'Hello Genkit')]),
);
```

To declare the dimension explicitly (e.g. when targeting a server that doesn't
report it), register the embedder on the plugin:

```dart
ollama(
  embedders: [
    OllamaEmbedderDefinition(name: 'nomic-embed-text', dimensions: 768),
  ],
);
```

### Remote / authenticated servers

Provide static headers, or an async provider for short-lived tokens:

```dart
ollama(
  baseUrl: 'https://ollama.example.com',
  headersProvider: () async => {'Authorization': 'Bearer ${await fetchToken()}'},
);
```

## Capabilities

Model capabilities (`tools`, `vision`/`media`, `constrained`, ...) are read
per-model from Ollama's `/api/show`, so each model advertises only what it
actually supports.

## License

Apache 2.0 — see [LICENSE](LICENSE).
