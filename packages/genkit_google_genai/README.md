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
    embedder: googleAI.textEmbedding('text-embedding-004'),
    documents: [
      DocumentData(content: [TextPart(text: 'Hello world')]),
      DocumentData(content: [TextPart(text: 'Genkit is awesome')]),
    ],
  );

  print(embeddings[0].embedding);
}
```

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
   for every request. A stored interaction's ID is in
   `response.message?.metadata?['interactionId']`; passing
   `messages: previousResponse.messages` with `store: true` continues that
   interaction and sends only the new messages. Setting
   `previousInteractionId` yourself also requires `store: true` (otherwise
   it throws `INVALID_ARGUMENT`).
4. **Service tier:** `GeminiOptions(serviceTier: 'flex')` (or `standard`,
   `priority`) works on both APIs.
5. **Text-to-speech:** the `gemini-3.8-flash-tts` and
   `gemini-3.8-flash-lite-tts` models return a complete WAV file
   (`audio/wav`). Streamed, they send raw PCM chunks (`audio/l16`, 24 kHz,
   mono, 16-bit), joined into one part in the final response. For several
   speakers, each turn is a separate text part that names its speaker:
   `TextPart(text: '...', metadata: {'speechMetadata': {'speaker': 'Joe'}})`
   (an optional `style` sets how it's spoken).
6. **Streaming:** text, media and thought summaries stream as they arrive.
   A server-side tool step (Google Search, code execution, ...) streams as
   one complete part when the step ends, and a function call streams as a
   complete tool request when the response ends. With structured output,
   `chunk.output` is null for chunks it can't parse yet (or that have no
   JSON text, such as thoughts or tool calls), so check it before use.


