[![Pub](https://img.shields.io/pub/v/genkit_vertexai.svg)](https://pub.dev/packages/genkit_vertexai)

Vertex AI plugin for Genkit Dart.

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
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'us-central1',
      )
    ],
  );

  // Generate text
  final response = await ai.generate(
    model: vertexAI.gemini('gemini-flash-latest'),
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
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'us-central1',
      )
    ],
  );

  final embeddings = await ai.embedMany(
    embedder: vertexAI.textEmbedding('text-embedding-004'),
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

`TextEmbedderOptions` lets you tune a request. `outputDimensionality` reduces the
vector size, while `taskType` and `title` tailor the embedding to its use case
(supported by the Gemini and `text-embedding-*` models).

```dart
final embeddings = await ai.embedMany(
  embedder: vertexAI.textEmbedding('gemini-embedding-001'),
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
  options: TextEmbedderOptions(
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
final embeddings = await ai.embedMany(
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
