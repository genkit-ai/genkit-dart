<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./docs/resources/genkit-logo-dark.png">
    <img alt="Genkit logo" src="./docs/resources/genkit-logo.png" width="400">
  </picture>
  <br>
  <strong>Genkit Dart (Preview)</strong>
  <br>
  <em>AI SDK for Dart &bull; LLM Framework &bull; AI Agent Toolkit</em>
</p>

<p align="center">
  <a href="https://pub.dev/packages/genkit"><img src="https://img.shields.io/pub/v/genkit.svg" alt="Pub"></a>
</p>

<p align="center">
  Build production-ready AI-powered applications in Dart with a unified interface for text generation, structured output, tool calling, and agentic workflows.
</p>

<p align="center">
  <a href="https://genkit.dev">Documentation</a> &bull;
  <a href="https://pub.dev/packages/genkit">API Reference</a> &bull;
  <a href="https://discord.gg/qXt5zzQKpc">Discord</a>
</p>

---

## Installation

```bash
dart pub add genkit
dart pub add genkit_google_genai
```

## Quick Start

Get up and running in under a minute:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: 'Why is Dart a great language for AI applications?',
  );

  print(response.text);
}
```

```bash
export GEMINI_API_KEY="your-api-key"
dart run main.dart
```

---

## Features

Genkit Dart gives you everything you need to build AI applications with confidence.

### Generate Text

Call any model with a simple, unified API:

```dart
final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Explain quantum computing in simple terms.',
);
print(response.text);
```

### Stream Responses

Stream text as it's generated for responsive user experiences:

```dart
final stream = ai.generateStream(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Write a short story about a robot learning to paint.',
);

await for (final chunk in stream) {
  print(chunk.text);
}
```

### Define Tools

Give models the ability to take actions and access external data:

```dart
// Define schemas for tool input
@GenkitSchema()
abstract class WeatherInput {
  String get location;
}

// ... run build_runner to generate WeatherInputType ...

final weatherTool = ai.defineTool(
  name: 'getWeather',
  description: 'Gets the current weather for a location',
  inputType: WeatherInputType,
  fn: (input, _) async {
    // Call your weather API here
    return 'Weather in ${input.location}: 72°F and sunny';
  },
);

final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'What\'s the weather like in San Francisco?',
  tools: ['getWeather'],
);
print(response.text);
```

### Define Flows

Wrap your AI logic in flows for better observability, testing, and deployment:

```dart
final jokeFlow = ai.defineFlow(
  name: 'tellJoke',
  inputType: StringType,
  outputType: StringType,
  fn: (topic, _) async {
    final response = await ai.generate(
      model: googleAI.gemini('gemini-2.5-flash'),
      prompt: 'Tell me a joke about $topic',
    );
    return response.text;
  },
);

final joke = await jokeFlow('programming');
print(joke);
```

### Streaming Flows

Stream data from your flows using `context.sendChunk`:

```dart
final streamStory = ai.defineFlow(
  name: 'streamStory',
  inputType: StringType,
  outputType: StringType,
  streamType: StringType,
  fn: (topic, context) async {
    final stream = ai.generateStream(
      model: googleAI.gemini('gemini-2.5-flash'),
      prompt: 'Write a story about $topic',
    );

    await for (final chunk in stream) {
      context.sendChunk(chunk.text);
    }
    return 'Story complete';
  },
);
```

---

## Development Tools

### Genkit CLI

Use the Genkit CLI to run your app with tracing and a local development UI:

```bash
curl -sL cli.genkit.dev | bash
genkit start -- dart run main.dart
```

### Developer UI

The local developer UI lets you:

- **Test flows** with different inputs interactively
- **Inspect traces** to debug complex multi-step operations
- **View traces** of your generative AI applications

---

<p align="center">
  Built by Google with contributions from the <a href="https://github.com/genkit-ai/genkit-dart/graphs/contributors">Open Source Community</a>
</p>
