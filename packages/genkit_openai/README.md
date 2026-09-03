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
- `jsonMode` (bool?) - Forces `{"type": "json_object"}`. Only consulted when Genkit's own output config does not already imply JSON; see [JSON output](#json-output)
- `visualDetailLevel` (String?, 'auto'|'low'|'high') - Visual detail level for images
- `version` (String?) - Model version override

### JSON output

There are three ways to get JSON back, in order of preference:

```dart
// 1. A schema - the model is constrained to the shape and `output` is typed.
final response = await ai.generate(
  model: openAI.model('gpt-4o'),
  prompt: 'Describe a book.',
  outputSchema: Book.$schema,
);
print(response.output!.title);

// 2. JSON with no particular shape.
final response = await ai.generate(
  model: openAI.model('gpt-4o'),
  prompt: 'Return a JSON object with keys "name" and "age".',
  outputFormat: 'json',
);

// 3. The provider flag directly, for callers not using Genkit's output config.
final response = await ai.generate(
  model: openAI.model('gpt-4o'),
  prompt: 'Reply with a JSON object.',
  config: OpenAIChatOptions(jsonMode: true),
);
```

`outputSchema` sends `response_format: {"type": "json_schema"}`; the other two
send `{"type": "json_object"}`. Output config wins when both are set, so
`jsonMode` never overrides a schema.

OpenAI rejects `json_object` unless the conversation also asks for JSON, so
options 2 and 3 need the prompt to say so. Option 1 does not.

Schemas are sent as authored. The plugin does not set `strict`, because
OpenAI's strict mode requires every property to appear in `required` and
`additionalProperties: false` on every object — which rejects ordinary schemas
that have optional fields.

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
