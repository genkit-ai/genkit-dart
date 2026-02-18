# Genkit Google GenAI Plugin (`genkit_google_genai`)

The Google AI plugin provides an interface against the official Google AI Gemini API.

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  // Initialize Genkit with the Google AI plugin
  final ai = Genkit(plugins: [googleAI()]);

  // Generate text
  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
}
```

## Embeddings

```dart
final embeddings = await ai.embedMany(
  embedder: googleAI.textEmbedding('text-embedding-004'),
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
);
```
