[![Pub](https://img.shields.io/pub/v/genkit_google_genai.svg)](https://pub.dev/packages/genkit_google_genai)

Google AI plugin for Genkit Dart.

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

### Video Generation With Veo

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final response = await ai.generate(
    model: googleAI.veo('veo-3.1-generate-preview'),
    prompt: 'A cinematic drone shot of cliffs at golden hour.',
    config: VeoOptions(
      aspectRatio: '16:9',
      durationSeconds: 8,
      numberOfVideos: 1,
      // Set embedMedia: true to download the video and return a data URI.
      // By default, Veo returns the generated video's source URL.
    ),
  );

  print(response.media?.url);
}
```

### Tool Calling

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

part 'main.g.dart';

@Schema()
abstract class $WeatherToolInput {
  String get location;
}

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  ai.defineTool(
    name: 'getWeather',
    description: 'Get the weather for a location',
    inputSchema: WeatherToolInput.$schema,
    fn: (input, context) async {
      return 'The weather in ${input.location} is 75 and sunny.';
    },
  );

  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: 'What is the weather in Boston?',
    toolNames: ['getWeather'],
  );

  print(response.text);
}
```

### Embeddings

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final embeddings = await ai.embedMany(
    embedder: googleAI.textEmbedding('text-embedding-004'),
    documents: [
      DocumentData(content: [TextPart(text: 'Hello world')]),
      DocumentData(content: [TextPart(text: 'Genkit is awesome')]),
    ],
  );

  print(embeddings[0].embedding);
}
```
