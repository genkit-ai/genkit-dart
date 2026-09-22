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

All three accept `speed` (0.25-4.0). `instructions` is honored only by
`gpt-4o-mini-tts`; the older two ignore it.

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

### Speech to Text

Transcription models take audio in and return text. The audio goes in through
`promptParts` as a `MediaPart` holding a base64 `data:` URL:

```dart
final response = await ai.generate(
  model: openAI.transcriptionModel('whisper-1'),
  promptParts: [
    MediaPart(
      media: Media(contentType: 'audio/mpeg', url: 'data:audio/mpeg;base64,...'),
    ),
  ],
  config: OpenAITranscriptionOptions(language: 'en'),
);

print(response.text); // 'The quick brown fox jumps over the lazy dog.'
```

`whisper-1`, `gpt-4o-transcribe` and `gpt-4o-mini-transcribe` are supported.
Set `responseFormat: 'srt'` or `'vtt'` to get subtitle markup instead of a
plain transcript, and `'verbose_json'` (with `timestampGranularities`) for
timing metadata. `response.text` is the transcript either way; the decoded
response — segments, timestamps, logprobs — is on `response.raw`. Ask for
`outputFormat: 'json'` and the JSON object comes through whole instead, so
`response.output` parses.

`whisper-1` can also translate: `translate: true` routes the request to
OpenAI's translation endpoint, which returns English text for audio in any
language.

```dart
final response = await ai.generate(
  model: openAI.transcriptionModel('whisper-1'),
  promptParts: [MediaPart(media: spanishAudio)],
  config: OpenAITranscriptionOptions(translate: true),
);
```

A compatible provider whose transcription model is not named `*whisper*` or
`*transcribe*` names the API it is served by:

```dart
CustomModelDefinition(
  name: 'earbox-1',
  kind: OpenAIModelKind.transcription,
)
```

`kind` and not `info`: `supports: {'media': true}` describes a vision chat
model just as well as a transcription one, so it cannot be the signal. Speech
models are the exception — `output: ['media']` says the model returns audio and
nothing else — and are still recognised from `info` as well as by name.

## Embeddings

Embedders resolve the same way models do, and `OpenAIEmbedders` exposes a typed
reference for each curated one:

```dart
final vectors = await ai.embed(
  embedder: OpenAIEmbedders.textEmbedding3Small,
  document: DocumentData(content: [TextPart(text: 'The cat sat on the mat.')]),
);

print(vectors.single.embedding.length); // 1536
```

`embedMany` takes a list of documents and returns one vector per document, in
order. A corpus larger than the 2048 inputs OpenAI accepts per request is split
across requests rather than rejected.

Each document's text parts are joined with newlines; media parts are dropped,
since OpenAI has no multimodal embedder. A document carrying no text at all is
rejected before the request goes out.

`KnownOpenAIEmbedder` carries the catalog, including the vector length each
model returns. The `text-embedding-3-*` models will also return a shorter
vector on request:

```dart
final vectors = await ai.embed(
  embedder: OpenAIEmbedders.textEmbedding3Small,
  document: DocumentData(content: [TextPart(text: 'hello')]),
  options: OpenAIEmbedderOptions(dimensions: 256),
);
```

As with models, the catalog is not the set of usable embedders: any name works
by passing it to `openAI.embedder()`, it is just described without a vector
length, and behind a custom `baseUrl` only what that host's `/models` reports
is listed.

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
- `jsonMode` (bool?) - Forces `{"type": "json_object"}`. Only consulted when Genkit's own output config says nothing about the format; any explicit `outputFormat` wins, `'text'` included. See [JSON output](#json-output)
- `visualDetailLevel` (String?, 'auto'|'low'|'high') - Visual detail level for images
- `version` (String?) - Model version override

The `OpenAISpeechOptions` class supports the following options:

- `voice` (String?) - Voice name, e.g. `'alloy'`, `'sage'`, `'coral'` (defaults to `'alloy'`). Free-form, so new OpenAI voices work without a plugin update
- `instructions` (String?) - Tone and delivery guidance (`gpt-4o-mini-tts` only)
- `speed` (double?, 0.25-4.0) - Playback speed
- `responseFormat` (String?, 'mp3'|'opus'|'aac'|'flac'|'wav'|'pcm') - Audio container (defaults to `'mp3'`)
- `version` (String?) - Model version override

The `OpenAITranscriptionOptions` class supports the following options:

- `language` (String?) - ISO-639-1 code of the spoken language; improves accuracy and latency
- `prompt` (String?) - Decoding hint (vocabulary, names, style). Defaults to the request's text content
- `temperature` (double?, 0.0-1.0) - Sampling temperature
- `responseFormat` (String?, 'json'|'text'|'srt'|'verbose_json'|'vtt') - Transcript format (defaults to `'json'`)
- `timestampGranularities` (List<String>?) - `'word'` and/or `'segment'`; needs `verbose_json`, `whisper-1` only
- `chunkingStrategy` (Object?) - `'auto'` or a server-VAD map; `gpt-4o-transcribe` family only
- `include` (List<String>?) - Extra response fields, e.g. `['logprobs']`
- `translate` (bool?) - Translate to English instead of transcribing; `whisper-1` only
- `version` (String?) - Model version override

The `OpenAIEmbedderOptions` class supports:

- `dimensions` (int?, >= 1) - Length of the returned vector, for the models
  that accept a shorter one
- `user` (String?) - User identifier for abuse detection

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

The plugin sends `strict: false`. Schemas are flattened (`$ref`/`$defs`
resolved) but otherwise unmodified. Strict mode is off because it requires
every property to appear in `required` and `additionalProperties: false` on
every object — which rejects ordinary schemas that have optional fields.

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
