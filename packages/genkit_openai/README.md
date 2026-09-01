[![Pub](https://img.shields.io/pub/v/genkit_openai.svg)](https://pub.dev/packages/genkit_openai)

OpenAI-compatible API plugin for Genkit Dart. Supports OpenAI models (GPT-4o, GPT-4, GPT-3.5-turbo, etc.) and any OpenAI-compatible API (xAI/Grok, DeepSeek, Together AI, Groq, etc.).

## Installation

Add `genkit_openai` to your `pubspec.yaml`:

```yaml
dependencies:
  genkit: ^0.13.0
  genkit_openai: ^0.3.0
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
  config: OpenAIChatOptions(
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

@Schema()
abstract class $WeatherInputSchema {
  String get location;
}

@Schema()
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
      return .response(WeatherOutput(
        temperature: 72,
        condition: 'sunny',
      ));
    },
  );

  final response = await ai.generate(
    model: openAI.model('gpt-4o'),
    prompt: 'What\'s the weather in Boston?',
    toolNames: ['getWeather'],
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

The plugin supports any OpenAI-compatible API by specifying a custom `baseUrl`.
Use the `name` parameter to give each backend a unique identity — this is
required when registering multiple backends in the same `Genkit` instance.

### Groq

```dart
final ai = Genkit(plugins: [
  openAI(
    name: 'groq',
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
  model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
  prompt: 'Hello!',
);
```

### Multiple Backends

You can use several OpenAI-compatible providers side by side by giving each a
unique `name`:

```dart
final ai = Genkit(plugins: [
  openAI(apiKey: Platform.environment['OPENAI_API_KEY']),
  openAI(
    name: 'openrouter',
    apiKey: Platform.environment['OPENROUTER_API_KEY'],
    baseUrl: 'https://openrouter.ai/api/v1',
    models: [CustomModelDefinition(name: 'gpt-4o')],
  ),
]);

// Uses the default OpenAI backend
final a = await ai.generate(
  model: openAI.model('gpt-4o'),
  prompt: 'Hello from OpenAI!',
);

// Uses the OpenRouter backend
final b = await ai.generate(
  model: openAI.model('gpt-4o', namespace: 'openrouter'),
  prompt: 'Hello from OpenRouter!',
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

### Text to Speech

Speech models are referenced with `speechModel()` rather than `model()`, take
`OpenAISpeechOptions`, and answer with a single audio media part whose `url` is
a base64 `data:` URL:

```dart
final response = await ai.generate(
  model: openAI.speechModel('gpt-4o-mini-tts'),
  prompt: 'Genkit is an amazing AI framework.',
  config: OpenAISpeechOptions(
    voice: 'sage',
    instructions: 'Speak in a calm, warm tone.',
  ),
);

final media = response.media!;            // contentType: audio/mpeg
final bytes = base64Decode(media.url.split(',').last);
await File('speech.mp3').writeAsBytes(bytes);
```

`tts-1` and `tts-1-hd` also accept `speed`. `gpt-4o-mini-tts` rejects it, so the
plugin drops the field for that model; `instructions` is only honored there.

Speech models are detected by name (`*tts*`). For an OpenAI-compatible provider
whose speech model is named differently, declare media output when registering
it and the plugin will route it to `/audio/speech`:

```dart
openAI(
  name: 'voicecorp',
  baseUrl: 'https://api.voicecorp.example/v1',
  models: [
    CustomModelDefinition(
      name: 'voicebox-1',
      info: ModelInfo(supports: {'output': ['media']}),
    ),
  ],
)
```

## Options

The `OpenAIChatOptions` class supports the following options:

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

The `OpenAISpeechOptions` class supports the following options:

- `voice` (String?) - Voice name, e.g. `'alloy'`, `'sage'`, `'coral'` (defaults to `'alloy'`). Free-form, so new OpenAI voices work without a plugin update
- `instructions` (String?) - Tone and delivery guidance (`gpt-4o-mini-tts` only)
- `speed` (double?, 0.25-4.0) - Playback speed (not supported by `gpt-4o-mini-tts`)
- `responseFormat` (String?, 'mp3'|'opus'|'aac'|'flac'|'wav'|'pcm') - Audio container (defaults to `'mp3'`)
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
