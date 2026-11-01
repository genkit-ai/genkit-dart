[![Pub](https://img.shields.io/pub/v/genkit_vertexai.svg)](https://pub.dev/packages/genkit_vertexai)

Vertex AI plugin for Genkit Dart.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Usage

To use Google's Vertex AI models, simply import this package and pass `vertexAI` to the `Genkit` initialization. 

Authentication is handled automatically via Application Default Credentials (e.g. `gcloud auth application-default login`), keeping the implementation clean and avoiding dependencies on `dart:io` in the core components.

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart';

void main() async {
  // Initialize Genkit with the Vertex AI plugin
  // Authentication is handled automatically via Application Default Credentials.
  // Project ID and location can be specified explicitly or inferred from the environment.
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      )
    ],
  );

  // Generate text
  final response = await ai.generate(
    model: vertexAI.gemini('gemini-3.8-flash'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
}
```

### Embeddings

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart';

void main() async {
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      )
    ],
  );

  final embeddings = await ai.embed(
    embedder: vertexAI.textEmbedding('gemini-embedding-001'),
    documents: [
      DocumentData(content: [TextPart(text: 'Hello world')]),
      DocumentData(content: [TextPart(text: 'Genkit is awesome')]),
    ],
  );

  print(embeddings[0].embedding);
}
```

Both the legacy `text-embedding-*` models and the newer `gemini-embedding-*`
models are supported through the same `textEmbedding` call; the correct request
shape is selected from the model name.

#### Embedding options

`GoogleGenAiEmbedderOptions` lets you tune a request. `outputDimensionality`
reduces the vector size, while `taskType` and `title` tailor the embedding to
its use case (supported by the Gemini and `text-embedding-*` models).

```dart
final embeddings = await ai.embed(
  embedder: vertexAI.textEmbedding('gemini-embedding-001'),
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
  options: GoogleGenAiEmbedderOptions(
    outputDimensionality: 256,
    taskType: 'RETRIEVAL_DOCUMENT',
  ),
);
```

#### Multimodal embeddings

The `multimodalembedding` model embeds text, images, and video. Provide each
input as a `MediaPart` using either an inline `data:` URI or a `gs://` / `https`
Google Cloud Storage URI (with a `contentType`). Text parts are embedded too.

A single document can produce **more than one embedding**: one per modality (and
one per video segment). The flat result is therefore not 1:1 with the input
documents, so each embedding carries metadata (`documentIndex`, `modality`,
`partIndex`, `segmentIndex`, ...) that you use to map it back to its source.

```dart
final embeddings = await ai.embed(
  embedder: vertexAI.textEmbedding('multimodalembedding'),
  documents: [
    DocumentData(
      content: [
        TextPart(text: 'A photo of a cat.'),
        MediaPart(
          media: Media(
            url: 'gs://my-bucket/cat.jpg',
            contentType: 'image/jpeg',
          ),
        ),
      ],
    ),
  ],
);

for (final e in embeddings) {
  print('${e.metadata?['modality']}: ${e.embedding.length} dims');
}
```

## Interactions API and `response.raw`

Newer Gemini models are called through the platform's **Interactions API**
(`.../projects/<project>/locations/<location>/interactions`) instead of
`generateContent`, as in the JS plugin.

### Model routing

Newer Gemini models (for example `gemini-3.8-flash`), Gemini Omni video
models and any Gemini model not listed below use the Interactions API. These
models still use `generateContent`:

- `gemini-3.8-flash-cyber`
- `gemini-3.5-flash`
- `gemini-3.1-flash-lite`
- `gemini-3.1-pro-preview`, `gemini-3.1-pro-preview-customtools`
- `gemini-3-flash-preview`
- `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`
- image models (`gemini-*-image*`, `gemini-nano-banana-*`) and text-to-speech
  models (`gemini-*-tts*`): the platform's Interactions API doesn't support
  them

The Interactions API is available on the `global` location (the default)
and on the `us` and `eu` multi-regions. A location you set is used as is,
and the server returns an error if the model isn't available there.

### Differences on the Interactions API

- **Stateless by default:** the plugin sends `store: false`. Set
  `GeminiOptions(store: true)` on a request (or `vertexAI(store: true)` for
  every request; a request's own `store` wins) to store interactions and
  continue a conversation from the previous response's messages. On models
  that use `generateContent`, `store: true` is ignored with a warning.
- **Safety settings** are supported (unlike the Gemini API plugin).
- In a stateless conversation, earlier results of server-side tools other
  than code execution (Google Search, URL context, Google Maps, file search,
  MCP servers) are not sent back with the history, because the platform
  rejects them (a warning is logged once). The model may call those tools
  again; set `store: true` to keep the full tool history on the server.
- The other differences are the same as for the Gemini API plugin (options
  that aren't sent, `response.raw` shape, streaming): see the
  [genkit_google_genai README](https://pub.dev/packages/genkit_google_genai).
- If your code reads `response.raw`: on `generateContent` it's a
  `GenerateContentResponse` with `candidates[]`; on the Interactions API
  it's an interaction with `id`, `status` and a `steps[]` timeline.
