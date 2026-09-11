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
models plus any `models:` you registered. Each curated model carries per-model
capability metadata; see [Available Models](#available-models). Models outside
that catalog still work when named explicitly, so newly released ids need no
plugin update.

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

The plugin curates capability metadata (vision, tool calling, structured
outputs, system vs. developer role, lifecycle stage) for the well-known OpenAI
chat models, and exposes a typed reference for each one via `OpenAIModels`:

```dart
final response = await ai.generate(
  model: OpenAIModels.gpt4o,
  prompt: 'Hello',
);
```

`KnownOpenAIModel` enumerates the catalog and `knownOpenAIModels` maps each
bare model name to its `ModelInfo`. Listing falls back to this catalog when
discovery is unavailable, minus the models OpenAI has retired: those still
resolve by name, but are never offered in a listing.

The catalog is not the set of usable models. Any OpenAI-compatible model works
by passing its name to `model()`; a name that is not curated takes the current
multimodal defaults, and a dated snapshot resolves to the capabilities of the
alias it belongs to:

```dart
final response = await ai.generate(
  // Resolves to the curated gpt-4o capabilities.
  model: openAI.model('gpt-4o-2024-08-06'),
  prompt: 'Hello',
);
```

To correct or extend what the plugin knows about a model — most often for a
model released after this version of the plugin, or one served by a proxy that
supports less than OpenAI does — pass a `CustomModelDefinition` with explicit
`info`.

Behind a custom `baseUrl`, a curated model keeps its capabilities — a gateway
serving `gpt-3.5-turbo` is serving that model — but not OpenAI's deployment
details, since the label, lifecycle stage and snapshot list all describe
OpenAI's own hosting. The catalog is also not added to that host's listing:
what a compatible provider lists is whatever its `/models` reports plus the
models you register.

## Reasoning

The o-series and the GPT-5 family take a `reasoningEffort`, which trades latency
and tokens against answer quality:

```dart
final response = await ai.generate(
  model: OpenAIModels.o4Mini,
  prompt: 'Prove it.',
  config: OpenAIChatOptions(reasoningEffort: 'high'),
);
```

Which of these levels a model accepts moves with the generation — `minimal`
arrived with GPT-5, `none` replaced it in GPT-5.1, `xhigh` came later — so
every level is offered to every reasoning model and OpenAI decides whether the
pair makes sense. The set of levels itself is fixed by `openai_dart`, which
models the parameter as an enum: a level OpenAI ships after this release needs
an SDK bump to reach. What the plugin does check is the model:
sending an effort to one that does not reason is rejected before the request
goes out, naming the model rather than the parameter. Behind a custom `baseUrl`
that check is skipped, since the catalog describes OpenAI's models and not that
host's.

`verbosity` is a separate GPT-5-family knob, controlling how much the model says
rather than how hard it thinks.

When a model returns its chain of thought, it arrives as a `ReasoningPart`
ahead of the answer, and streams as it is produced:

```dart
await for (final chunk in ai.generateStream(model: ..., prompt: ...)) {
  for (final part in chunk.content) {
    if (part.isReasoning) stdout.write(part.reasoning);
  }
}
```

OpenAI's own models never return reasoning on the chat API — they bill it as
reasoning tokens and keep it — so in practice this is a compatible-backend
path: DeepSeek R1 and vLLM send `reasoning_content`, OpenRouter sends
`reasoning`, and both are read.

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
- `reasoningEffort` (String?, 'none'|'minimal'|'low'|'medium'|'high'|'xhigh'|'max') -
  How hard a reasoning model thinks before answering
- `verbosity` (String?, 'low'|'medium'|'high') - How much the model says in its answer

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
