[![Pub](https://img.shields.io/pub/v/genkit_openai.svg)](https://pub.dev/packages/genkit_openai)

OpenAI-compatible API plugin for Genkit Dart. Supports OpenAI models (GPT-4o, GPT-4, GPT-3.5-turbo, etc.) and any OpenAI-compatible API (xAI/Grok, DeepSeek, Together AI, Groq, etc.).

## Installation

Add `genkit_openai` to your `pubspec.yaml`:

```yaml
dependencies:
  genkit: ^0.10.0
  genkit_openai: ^0.0.1-dev.1
```

## Usage

### Basic Usage

```dart
import 'dart:io';
import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

void main() async {
  // Initialize Genkit with the OpenAI plugin
  final ai = Genkit(plugins: [
    openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
  ]);

  // Generate text
  final response = await ai.generate(
    model: openAI.model('gpt-4o'),
    prompt: 'Tell me a joke.',
  );

  print(response.text);
}
```

### With Custom Options

```dart
final response = await ai.generate(
  model: openAI.model('gpt-4o'),
  prompt: 'Write a haiku about Dart.',
  config: OpenAIOptions(
    temperature: 0.7,
    maxTokens: 100,
    jsonMode: false,
  ),
);
```

### Streaming

```dart
await for (final chunk in ai.generateStream(
  model: openAI.model('gpt-4o'),
  prompt: 'Count from 1 to 10.',
)) {
  for (final part in chunk.content) {
    if (part.isText) {
      print(part.text);
    }
  }
}
```

### Tool Calling

```dart
import 'dart:io';
import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:schemantic/schemantic.dart';

part 'example.g.dart';

@Schematic()
abstract class $WeatherInputSchema {
  String get location;
}

@Schematic()
abstract class $WeatherOutputSchema {
  int get temperature;
  String get condition;
}

void main() async {
  final ai = Genkit(plugins: [
    openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
  ]);

  ai.defineTool(
    name: 'getWeather',
    description: 'Get the weather for a location',
    inputSchema: WeatherInputSchema.$schema,
    outputSchema: WeatherOutputSchema.$schema,
    fn: (input, ctx) async {
      return WeatherOutput(
        temperature: 72,
        condition: 'sunny',
      );
    },
  );

  final response = await ai.generate(
    model: openAI.model('gpt-4o'),
    prompt: 'What\'s the weather in Boston?',
    tools: ['getWeather'],
  );

  print(response.text);
}
```

### Multi-turn Conversations

```dart
final response = await ai.generate(
  model: openAI.model('gpt-4o'),
  messages: [
    Message(
      role: Role.user,
      content: [TextPart(text: 'My name is Alice.')],
    ),
    Message(
      role: Role.model,
      content: [TextPart(text: 'Hello Alice! Nice to meet you.')],
    ),
    Message(
      role: Role.user,
      content: [TextPart(text: 'What is my name?')],
    ),
  ],
);
```

## OpenAI-Compatible APIs

The plugin supports any OpenAI-compatible API by specifying a custom `baseUrl`:

### Groq

```dart
final ai = Genkit(plugins: [
  openAI(
    apiKey: Platform.environment['GROQ_API_KEY'],
    baseUrl: 'https://api.groq.com/openai/v1',
    models: [
      CustomModelDefinition(
        name: 'llama-3.3-70b-versatile',
        info: ModelInfo(
          label: 'Llama 3.3 70B',
          supports: {
            'multiturn': true,
            'tools': true,
            'systemRole': true,
          },
        ),
      ),
    ],
  ),
]);

final response = await ai.generate(
  model: openAI.model('llama-3.3-70b-versatile'),
  prompt: 'Hello!',
);
```

## Available Models

Any OpenAI-compatible model can be used by providing its name to the `model()` method:

```dart
final response = await ai.generate(
  model: openAI.model('gpt-4o-2024-08-06'),
  prompt: 'Hello',
);
```

## Options

The `OpenAIOptions` class supports the following options:

- `temperature` (double?, 0.0-2.0) - Sampling temperature
- `topP` (double?, 0.0-1.0) - Nucleus sampling
- `maxTokens` (int?) - Maximum tokens to generate
- `stop` (List<String>?) - Stop sequences
- `presencePenalty` (double?, -2.0 to 2.0) - Presence penalty
- `frequencyPenalty` (double?, -2.0 to 2.0) - Frequency penalty
- `seed` (int?) - Seed for deterministic sampling
- `user` (String?) - User identifier for abuse detection
- `jsonMode` (bool?) - Enable JSON mode
- `visualDetailLevel` (String?, 'auto'|'low'|'high') - Visual detail level for images
- `version` (String?) - Model version override

## Custom Headers

You can pass custom headers to the OpenAI client:

```dart
final ai = Genkit(plugins: [
  openAI(
    apiKey: 'your-key',
    headers: {
      'X-Custom-Header': 'value',
    },
  ),
]);
```

## License

Apache 2.0
