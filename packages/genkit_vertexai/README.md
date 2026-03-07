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
    model: vertexAI.gemini('gemini-2.5-flash'),
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
