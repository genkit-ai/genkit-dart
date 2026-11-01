[![Pub](https://img.shields.io/pub/v/genkit_google_genai.svg)](https://pub.dev/packages/genkit_google_genai)

Google AI plugin for Genkit Dart.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  // Initialize Genkit with the Google AI plugin
  final ai = Genkit(plugins: [googleAI()]);

  // Generate text
  final response = await ai.generate(
    model: googleAI.gemini('gemini-flash-latest'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
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
      return .response('The weather in ${input.location} is 75 and sunny.');
    },
  );

  final response = await ai.generate(
    model: googleAI.gemini('gemini-flash-latest'),
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

  final embeddings = await ai.embed(
    embedder: googleAI.textEmbedding('gemini-embedding-001'),
    documents: [
      DocumentData(content: [TextPart(text: 'Hello world')]),
      DocumentData(content: [TextPart(text: 'Genkit is awesome')]),
    ],
  );

  print(embeddings[0].embedding);
}
```

`gemini-embedding-2` also embeds images and videos (as `MediaPart`s).

### Built-in tools

Google Search, code execution, URL context and file search have their own
options; other built-in tools go in `tools` as maps. For Google Maps, set the
user's location with `retrievalConfig`:

```dart
final response = await ai.generate(
  model: googleAI.gemini('gemini-flash-latest'),
  prompt: 'Describe some sights near me',
  config: GeminiOptions(
    tools: [
      {
        'googleMaps': {'enableWidget': true},
      },
    ],
    retrievalConfig: GeminiRetrievalConfig(
      latLng: GeminiLatLng(latitude: 43.0896, longitude: -79.0849),
    ),
  ),
);
```

```dart
final response = await ai.generate(
  model: googleAI.gemini('gemini-flash-latest'),
  prompt: 'Summarize https://genkit.dev',
  config: GeminiOptions(urlContext: GeminiUrlContext()),
);
```

### Image generation

```dart
final response = await ai.generate(
  model: googleAI.geminiImage('gemini-nano-banana-2.1'),
  prompt: 'A watercolor painting of a castle in the mountains.',
  config: GeminiImageOptions(
    imageConfig: GeminiImageConfig(aspectRatio: '16:9', imageSize: '2K'),
  ),
);

final image = response.media;
```

### Video generation (Gemini Omni)

```dart
final response = await ai.generate(
  model: googleAI.geminiVideo('gemini-omni-1.1-flash'),
  prompt: 'An origami butterfly flaps its wings and flies out of the window.',
  config: GeminiVideoOptions(
    videoFormat: GeminiVideoFormat(aspectRatio: '16:9', resolution: '720p'),
  ),
);

// An MP4 video (video/mp4), returned inline as a data URL.
final video = response.media;
```

- `ai.generate()` returns the video directly (it isn't a long-running
  operation).
- Images and videos in the prompt are used as inputs (image to video, first
  and last frame, subject references, editing or extending a video).
- `videoFormat` sets `aspectRatio` (`16:9`, the default, or `9:16`) and
  `resolution` (`360p`, `720p` (the default), `1080p` or `4k`).
  `delivery: 'uri'` returns a Files API URI instead of inline data, which is
  recommended for large videos; it requires `store: true`.
- `videoConfig.task` (`text_to_video`, `image_to_video`,
  `reference_to_video`, `edit`, `extend`) tells the model which kind of
  generation to do; without it, the model infers it from the prompt.
- To edit a generated video in a follow-up turn, set `store: true` and pass
  the previous response's messages.
- Tools aren't supported.

### Music generation (Lyria)

```dart
final response = await ai.generate(
  model: googleAI.lyria('lyria-3-clip-preview'),
  prompt: 'A cheerful acoustic folk song with guitar and harmonica.',
);

final music = response.media; // the audio
final lyrics = response.text; // the lyrics or a caption
```

`lyria-3.5` and `lyria-3-pro-preview` make full-length songs; images in the
prompt are used as inspiration.

### Antigravity agent

```dart
final response = await ai.generate(
  model: googleAI.antigravity('antigravity-preview-09-2026'),
  prompt: 'Read Hacker News, summarize the top 10 stories.',
  // The sandbox the agent works in.
  config: AntigravityOptions(environment: 'remote'),
);
```

- The agent keeps the conversation on the server. Passing
  `messages: previousResponse.messages` continues it in the same sandbox
  (the plugin sends the interaction and environment IDs from the last
  response).
- Without `tools`, the agent uses its default tools; with
  `tools: [{'type': 'google_search'}]` it uses only those. Your own Genkit
  tools work too.
- `model` picks the Gemini model the agent runs on (e.g. `gemini-4-argon`).
- `store` is only sent when you set it: the agent needs stored interactions,
  so `store: false` is rejected by the server.
- System messages are sent as user messages (the agent has no system
  instruction).

## Interactions API and `response.raw`

Newer Gemini models are called through Google's **Interactions API**
(`/v1beta/interactions`) instead of the older `generateContent` API.

### Model routing

Gemini and Gemma models use the Interactions API, including the `-latest`
aliases and any model not listed below. Only these older models still use
`generateContent`, until they are retired:

- `gemini-3.5-flash`
- `gemini-3.1-flash-lite`
- `gemini-3.1-pro-preview`
- `gemini-3.1-pro-preview-customtools`
- `gemini-3-flash-preview`
- `gemini-2.5-pro`
- `gemini-2.5-flash`
- `gemini-2.5-flash-lite`
- `gemini-3.1-flash-image`
- `gemini-3-pro-image`
- `gemini-2.5-flash-image`
- `gemini-2.5-flash-preview-tts`
- `gemini-2.5-pro-preview-tts`
- `gemini-3.1-flash-tts-preview`
- `gemma-4-26b-a4b-it`
- `gemma-4-31b-it`

### Standard Genkit output vs. `response.raw`

`response.text`, `response.reasoning`, `response.message`, `response.media`,
streaming and tool calling work the same way on both APIs.

If your code reads the provider payload in `response.raw`, it differs:

- **`generateContent`:** a `GenerateContentResponse` with `candidates[]`.
  Grounding metadata is on `candidates[0].groundingMetadata`.
- **Interactions API:** an interaction with `id`, `status` and a `steps[]`
  timeline. Server-side tool calls and results (Google Search, code
  execution, ...) are explicit steps (`google_search_call`,
  `code_execution_call`, ...), and grounding citations are annotations on
  the text content of the `model_output` step.

### Differences on the Interactions API

1. **Safety settings:** these models apply no additional safety filters by
   default ([Gemini API safety settings](https://ai.google.dev/gemini-api/docs/safety-settings));
   built-in protections against core harms always apply. `BLOCK_NONE`
   settings are ignored, since they can't block anything beyond that
   default. Blocking thresholds (`BLOCK_ONLY_HIGH` and stricter) throw an
   `INVALID_ARGUMENT` error, so a requested filter is never silently
   dropped.
2. **Options the Interactions API doesn't use:** `topK`, `presencePenalty`,
   `frequencyPenalty`, `responseMimeType` (other than `application/json`)
   and `thinkingConfig.thinkingBudget` (use `thinkingLevel`) are not sent;
   each is logged once per model as a warning. `candidateCount` above 1 is
   warned about too: one candidate is returned. `temperature` and `topP`
   are still sent, although newer models ignore them.
   `responseMimeType: 'application/json'` asks for JSON output, as on
   `generateContent`.
3. **Stateless by default:** the plugin sends `store: false`, so nothing is
   kept on Google's servers. To store interactions, set
   `GeminiOptions(store: true)` on a request, or `googleAI(store: true)`
   for every request (a request's own `store`, `true` or `false`, wins
   over the plugin option). A stored interaction's ID is in
   `response.message?.metadata?['interactionId']`; passing
   `messages: previousResponse.messages` with `store: true` continues that
   interaction and sends only the new messages. Setting
   `previousInteractionId` yourself also requires `store: true` (otherwise
   it throws `INVALID_ARGUMENT`). On models that use `generateContent`,
   `store` only controls whether the server logs the request for your
   project (viewable in AI Studio's Logs and Datasets): it's sent as is
   when you set it (request config or `googleAI(store: ...)`), and
   otherwise your project's logging setting applies.
4. **Service tier:** `GeminiOptions(serviceTier: 'flex')` (or `standard`,
   `priority`) works on both APIs.
5. **Text-to-speech:** the `gemini-3.8-flash-tts` and
   `gemini-3.8-flash-lite-tts` models return a complete WAV file
   (`audio/wav`). Streamed, they send raw PCM chunks (`audio/l16`, 24 kHz,
   mono, 16-bit), joined into one part in the final response. To choose the
   format, set `GeminiTtsOptions(audioFormat: GeminiAudioFormat(mimeType:
   'audio/wav'))` (`audio/wav`, `audio/l16`, `audio/mulaw` or `audio/alaw`);
   request `audio/wav` when streaming to get a playable file at the end.
   For several speakers, each turn is a separate text part that names its
   speaker:
   `TextPart(text: '...', metadata: {'speechMetadata': {'speaker': 'Joe'}})`
   (an optional `style` sets how it's spoken).
6. **Built-in tools:** `tools` maps and the tool options are sent as
   Interactions tools (e.g. `{'googleMaps': {}}` becomes a `google_maps`
   tool); a map with its own `type` is sent as is. `retrievalConfig.latLng`
   is set on the Google Maps tool (there's no retrieval config on this API);
   other `retrievalConfig` fields are ignored with a warning. `audioFormat`,
   `videoFormat` and `videoConfig` only work on these models (they're
   ignored with a warning on `generateContent`). The vertexAI-only options
   (`location`, `labels`, `vertexRetrieval`, `payGo`, `videoFormat.gcsUri`)
   are ignored with a warning on both APIs.
7. **Streaming:** text, media and thought summaries stream as they arrive.
   A server-side tool step (Google Search, code execution, ...) streams as
   one complete part when the step ends, and a function call streams as a
   complete tool request when the response ends. With structured output,
   `chunk.output` is null for chunks it can't parse yet (or that have no
   JSON text, such as thoughts or tool calls), so check it before use.
8. **Usage:** `response.usage` has the token totals (`inputTokens`,
   `outputTokens`, `thoughtsTokens`, ...). Token counts per modality are in
   `response.usage?.custom` (e.g. `inputTextTokens`, `inputImageTokens`,
   `outputAudioTokens`), and tool-use tokens in
   `response.usage?.custom?['toolUseTokens']` (also on `generateContent`).
   Grounding tool use is counted there too (e.g. `googleSearchCount`).


