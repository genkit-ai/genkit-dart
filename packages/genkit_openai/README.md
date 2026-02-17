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
  config: OpenAIOptionsSchema(
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

### GPT-5.x Series

- `openAI.gpt5` - gpt-5
- `openAI.gpt520250807` - gpt-5-2025-08-07
- `openAI.gpt5ChatLatest` - gpt-5-chat-latest
- `openAI.gpt5Mini` - gpt-5-mini
- `openAI.gpt5Mini20250807` - gpt-5-mini-2025-08-07
- `openAI.gpt5Nano` - gpt-5-nano
- `openAI.gpt5Nano20250807` - gpt-5-nano-2025-08-07
- `openAI.gpt5Pro` - gpt-5-pro
- `openAI.gpt5Pro20251006` - gpt-5-pro-2025-10-06
- `openAI.gpt5Codex` - gpt-5-codex
- `openAI.gpt5SearchApi` - gpt-5-search-api
- `openAI.gpt5SearchApi20251014` - gpt-5-search-api-2025-10-14
- `openAI.gpt51` - gpt-5.1
- `openAI.gpt5120251113` - gpt-5.1-2025-11-13
- `openAI.gpt51ChatLatest` - gpt-5.1-chat-latest
- `openAI.gpt51Codex` - gpt-5.1-codex
- `openAI.gpt51CodexMini` - gpt-5.1-codex-mini
- `openAI.gpt51CodexMax` - gpt-5.1-codex-max
- `openAI.gpt52` - gpt-5.2
- `openAI.gpt5220251211` - gpt-5.2-2025-12-11
- `openAI.gpt52ChatLatest` - gpt-5.2-chat-latest
- `openAI.gpt52Pro` - gpt-5.2-pro
- `openAI.gpt52Pro20251211` - gpt-5.2-pro-2025-12-11
- `openAI.gpt52Codex` - gpt-5.2-codex

### GPT-4.x Series

- `openAI.gpt4` - gpt-4
- `openAI.gpt40613` - gpt-4-0613
- `openAI.gpt41106Preview` - gpt-4-1106-preview
- `openAI.gpt40125Preview` - gpt-4-0125-preview
- `openAI.gpt4Turbo` - gpt-4-turbo
- `openAI.gpt4TurboPreview` - gpt-4-turbo-preview
- `openAI.gpt4Turbo20240409` - gpt-4-turbo-2024-04-09
- `openAI.gpt41` - gpt-4.1
- `openAI.gpt4120250414` - gpt-4.1-2025-04-14
- `openAI.gpt41Mini` - gpt-4.1-mini
- `openAI.gpt41Mini20250414` - gpt-4.1-mini-2025-04-14
- `openAI.gpt41Nano` - gpt-4.1-nano
- `openAI.gpt41Nano20250414` - gpt-4.1-nano-2025-04-14

### GPT-4o Series

- `openAI.gpt4o` - gpt-4o
- `openAI.gpt4o20240513` - gpt-4o-2024-05-13
- `openAI.gpt4o20240806` - gpt-4o-2024-08-06
- `openAI.gpt4o20241120` - gpt-4o-2024-11-20
- `openAI.chatgpt4oLatest` - chatgpt-4o-latest
- `openAI.gpt4oMini` - gpt-4o-mini
- `openAI.gpt4oMini20240718` - gpt-4o-mini-2024-07-18

### GPT-4o Search

- `openAI.gpt4oSearchPreview` - gpt-4o-search-preview
- `openAI.gpt4oSearchPreview20250311` - gpt-4o-search-preview-2025-03-11
- `openAI.gpt4oMiniSearchPreview` - gpt-4o-mini-search-preview
- `openAI.gpt4oMiniSearchPreview20250311` - gpt-4o-mini-search-preview-2025-03-11

### GPT-3.5 Series

- `openAI.gpt35Turbo` - gpt-3.5-turbo
- `openAI.gpt35Turbo16k` - gpt-3.5-turbo-16k
- `openAI.gpt35Turbo1106` - gpt-3.5-turbo-1106
- `openAI.gpt35Turbo0125` - gpt-3.5-turbo-0125
- `openAI.gpt35TurboInstruct` - gpt-3.5-turbo-instruct
- `openAI.gpt35TurboInstruct0914` - gpt-3.5-turbo-instruct-0914

### O-Series Models

- `openAI.o1` - o1
- `openAI.o120241217` - o1-2024-12-17
- `openAI.o1Pro` - o1-pro
- `openAI.o1Pro20250319` - o1-pro-2025-03-19
- `openAI.o3` - o3
- `openAI.o320250416` - o3-2025-04-16
- `openAI.o3Mini` - o3-mini
- `openAI.o3Mini20250131` - o3-mini-2025-01-31
- `openAI.o4Mini` - o4-mini
- `openAI.o4Mini20250416` - o4-mini-2025-04-16
- `openAI.o4MiniDeepResearch` - o4-mini-deep-research
- `openAI.o4MiniDeepResearch20250626` - o4-mini-deep-research-2025-06-26

### Codex Models

- `openAI.codexMiniLatest` - codex-mini-latest

### Using Any Model by Name

Or use any model by name with the `model()` method:

```dart
final response = await ai.generate(
  model: openAI.model('gpt-4o-2024-08-06'),
  prompt: 'Hello',
);
```

## Options

The `OpenAIOptionsSchema` class supports the following options:

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
