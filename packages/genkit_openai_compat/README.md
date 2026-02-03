[![Pub](https://img.shields.io/pub/v/genkit_openai_compat.svg)](https://pub.dev/packages/genkit_openai_compat)

OpenAI-compatible API plugin for Genkit Dart. Supports OpenAI models (GPT-4o, GPT-4, GPT-3.5-turbo, etc.) and any OpenAI-compatible API (xAI/Grok, DeepSeek, Together AI, Groq, etc.).

## Installation

Add `genkit_openai_compat` to your `pubspec.yaml`:

```yaml
dependencies:
  genkit: ^0.10.0
  genkit_openai_compat: ^0.0.1-dev.1
```

## Usage

### Basic Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_openai_compat/genkit_openai_compat.dart';

void main() async {
  // Initialize Genkit with the OpenAI plugin
  final ai = Genkit(plugins: [
    openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
  ]);

  // Generate text
  final response = await ai.generate(
    model: openAI.gpt4o,
    prompt: 'Tell me a joke.',
  );

  print(response.text);
}
```

### With Custom Options

```dart
final response = await ai.generate(
  model: openAI.gpt4o,
  prompt: 'Write a haiku about Dart.',
  config: OpenAIOptions.from(
    temperature: 0.7,
    maxTokens: 100,
    jsonMode: false,
  ),
);
```

### Streaming

```dart
await for (final chunk in ai.generateStream(
  model: openAI.gpt4o,
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
import 'package:genkit/genkit.dart';
import 'package:genkit_openai_compat/genkit_openai_compat.dart';

part 'main.g.dart';

@Schematic()
abstract class WeatherInputSchema {
  String get location;
}

void main() async {
  final ai = Genkit(plugins: [
    openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
  ]);

  final weatherTool = ai.defineTool(
    name: 'getWeather',
    description: 'Get the weather for a location',
    inputType: WeatherInputType,
    fn: (input, ctx) async {
      return {'temperature': 72, 'condition': 'sunny'};
    },
  );

  final response = await ai.generate(
    model: openAI.gpt4o,
    prompt: 'What\'s the weather in Boston?',
    tools: ['getWeather'],
  );

  print(response.text);
}
```

### Multi-turn Conversations

```dart
final response = await ai.generate(
  model: openAI.gpt4o,
  messages: [
    Message.from(
      role: Role.user,
      content: [TextPart.from(text: 'My name is Alice.')],
    ),
    Message.from(
      role: Role.model,
      content: [TextPart.from(text: 'Hello Alice! Nice to meet you.')],
    ),
    Message.from(
      role: Role.user,
      content: [TextPart.from(text: 'What is my name?')],
    ),
  ],
);
```

## OpenAI-Compatible APIs

The plugin supports any OpenAI-compatible API by specifying a custom `baseURL`:

### Groq

```dart
final ai = Genkit(plugins: [
  openAI(
    apiKey: Platform.environment['GROQ_API_KEY'],
    baseURL: 'https://api.groq.com/openai/v1',
    models: [
      CustomModelDefinition(
        name: 'llama-3.3-70b-versatile',
        info: ModelInfo.from(
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

### xAI (Grok)

```dart
final ai = Genkit(plugins: [
  openAI(
    apiKey: Platform.environment['XAI_API_KEY'],
    baseURL: 'https://api.x.ai/v1',
    models: [
      CustomModelDefinition(name: 'grok-2'),
      CustomModelDefinition(name: 'grok-2-mini'),
    ],
  ),
]);
```

### DeepSeek

```dart
final ai = Genkit(plugins: [
  openAI(
    apiKey: Platform.environment['DEEPSEEK_API_KEY'],
    baseURL: 'https://api.deepseek.com/v1',
    models: [
      CustomModelDefinition(name: 'deepseek-chat'),
      CustomModelDefinition(name: 'deepseek-reasoner'),
    ],
  ),
]);
```

## API Key Resolution

The plugin follows this priority order for API key resolution:

1. **Per-request config** (highest priority): `OpenAIOptions.from(apiKey: '...')`
2. **Plugin constructor**: `openAI(apiKey: '...')`
3. **Environment variable**: You must pass it explicitly - the plugin does NOT automatically read environment variables

```dart
// Per-request API key (highest priority)
final response = await ai.generate(
  model: openAI.gpt4o,
  prompt: 'Hello',
  config: OpenAIOptions.from(apiKey: 'request-specific-key'),
);

// Plugin-level API key (fallback)
final ai = Genkit(plugins: [
  openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
]);
```

## Available Models

Pre-defined model references:

- `openAI.gpt4o` - GPT-4o
- `openAI.gpt4oMini` - GPT-4o Mini
- `openAI.gpt4Turbo` - GPT-4 Turbo
- `openAI.gpt35Turbo` - GPT-3.5 Turbo
- `openAI.o1` - O1
- `openAI.o1Mini` - O1 Mini
- `openAI.o3Mini` - O3 Mini

Or use any model by name:

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
- `apiKey` (String?) - Per-request API key override

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
