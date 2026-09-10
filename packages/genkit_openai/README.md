[![Pub](https://img.shields.io/pub/v/genkit_openai.svg)](https://pub.dev/packages/genkit_openai)

OpenAI plugin for Genkit Dart. Talks the OpenAI Chat Completions API, so it
drives OpenAI's own models and any host that implements the same API — Groq,
xAI/Grok, DeepSeek, Together AI, OpenRouter and friends — by pointing it at a
different [`baseUrl`](#openai-compatible-apis).

## Installation

```bash
dart pub add genkit genkit_openai
```

## Usage

### Basic Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

void main() async {
  // Initialize Genkit with the OpenAI plugin. The API key is read from the
  // OPENAI_API_KEY environment variable when not passed explicitly.
  final ai = Genkit(plugins: [openAI()]);

  // Generate text
  final response = await ai.generate(
    model: openAI.model('gpt-4o'),
    prompt: 'Tell me a joke.',
  );

  print(response.text);
}
```

### API Key

The key is resolved in this order:

1. `apiKeyProvider`, if given
2. `apiKey`, if given
3. the `OPENAI_API_KEY` environment variable

Creating the plugin does no network I/O and does not require a key, so an app
starts up (and the Dev UI connects) offline. A missing or invalid key surfaces
when a model is actually called.

This is deliberately more permissive than the other Genkit SDKs, not parity
with them: the JS plugin throws when constructed without a key and Go panics
in `Init`. Dart defers the requirement to call time so the Dev UI stays
usable before a key is exported, matching `genkit_anthropic`.

Model discovery via `GET /models` happens only when listing actions, and is
best-effort: if it fails, the plugin falls back to a curated catalog of common
models plus any `models:` you registered. Models outside that catalog still
work when named explicitly, so newly released ids need no plugin update.

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

Point the plugin at any OpenAI-compatible host with `baseUrl`. Use `name` to
give each backend a unique identity — this is required when registering
multiple backends in the same `Genkit` instance, and it becomes the namespace
prefix for that backend's models.

Two things to know before pointing this at a non-OpenAI host:

- **Model discovery is optional.** `GET /models` is only called when listing
  actions, and a host that does not serve it degrades to a warning. Name any
  model explicitly and it resolves whether or not the host advertises it — but
  what the Dev UI *lists* for a custom `baseUrl` is only what discovery
  returned plus your `models:`. The curated OpenAI catalog is deliberately
  withheld, so a Groq backend does not offer you `groq/gpt-4o`. Declare the
  models you care about in `models:` to see them listed.
- **Streaming always sends `stream_options.include_usage`.** Hosts that reject
  unknown stream options will refuse streaming calls.

Compatibility is verified against a local fake host
(`test/openai_plugin_compat_test.dart`) covering `baseUrl` routing, auth,
custom headers, custom models, streaming and error mapping — not against each
provider's live API, so treat the providers named above as examples of the
shape rather than a certified list.

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
