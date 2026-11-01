[![Pub](https://img.shields.io/pub/v/genkit_vertexai.svg)](https://pub.dev/packages/genkit_vertexai)

Vertex AI plugin for Genkit Dart.

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

To use Google's Vertex AI models, simply import this package and pass `vertexAI` to the `Genkit` initialization. 

Authentication is handled automatically via Application Default Credentials (e.g. `gcloud auth application-default login`), keeping the implementation clean and avoiding dependencies on `dart:io` in the core components.

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart';

void main() async {
  // Initialize Genkit with the Vertex AI plugin
  // Authentication is handled automatically via Application Default Credentials.
  // Project ID and location can be specified explicitly or inferred from the environment.
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      )
    ],
  );

  // Generate text
  final response = await ai.generate(
    model: vertexAI.gemini('gemini-3.8-flash'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
}
```

### Embeddings

```dart
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart';

void main() async {
  final ai = Genkit(
    plugins: [
      vertexAI(
        projectId: Platform.environment['GCLOUD_PROJECT'],
        location: Platform.environment['GCLOUD_LOCATION'] ?? 'global',
      )
    ],
  );

  final embeddings = await ai.embed(
    embedder: vertexAI.textEmbedding('gemini-embedding-001'),
    documents: [
      DocumentData(content: [TextPart(text: 'Hello world')]),
      DocumentData(content: [TextPart(text: 'Genkit is awesome')]),
    ],
  );

  print(embeddings[0].embedding);
}
```

Both the legacy `text-embedding-*` models and the newer `gemini-embedding-*`
models are supported through the same `textEmbedding` call; the correct request
shape is selected from the model name. `gemini-embedding-2` (and newer Gemini
embedders) use the `:embedContent` method: one request per document, whose
text and media parts are embedded together into one vector (`taskType` and
`title` don't apply and are ignored with a warning).

#### Embedding options

`GoogleGenAiEmbedderOptions` lets you tune a request. `outputDimensionality`
reduces the vector size, while `taskType` and `title` tailor the embedding to
its use case (supported by the Gemini and `text-embedding-*` models).

```dart
final embeddings = await ai.embed(
  embedder: vertexAI.textEmbedding('gemini-embedding-001'),
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
  options: GoogleGenAiEmbedderOptions(
    outputDimensionality: 256,
    taskType: 'RETRIEVAL_DOCUMENT',
  ),
);
```

#### Multimodal embeddings

The `multimodalembedding` model embeds text, images, and video. Provide each
input as a `MediaPart` using either an inline `data:` URI or a `gs://` / `https`
Google Cloud Storage URI (with a `contentType`). Text parts are embedded too.

A single document can produce **more than one embedding**: one per modality (and
one per video segment). The flat result is therefore not 1:1 with the input
documents, so each embedding carries metadata (`documentIndex`, `modality`,
`partIndex`, `segmentIndex`, ...) that you use to map it back to its source.

```dart
final embeddings = await ai.embed(
  embedder: vertexAI.textEmbedding('multimodalembedding'),
  documents: [
    DocumentData(
      content: [
        TextPart(text: 'A photo of a cat.'),
        MediaPart(
          media: Media(
            url: 'gs://my-bucket/cat.jpg',
            contentType: 'image/jpeg',
          ),
        ),
      ],
    ),
  ],
);

for (final e in embeddings) {
  print('${e.metadata?['modality']}: ${e.embedding.length} dims');
}
```

### Image generation

```dart
final response = await ai.generate(
  model: vertexAI.geminiImage('gemini-nano-banana-2.1'),
  prompt: 'A cozy reading nook with a window seat on a rainy afternoon.',
  config: GeminiImageOptions(
    imageConfig: GeminiImageConfig(aspectRatio: '9:16', imageSize: '1K'),
  ),
);
final image = response.media;
```

`gemini-nano-banana-2.1` doesn't support `seed`, `topK`, `logprobs`,
`temperature` or `topP` (the server returns an error).

### Text-to-speech

The `gemini-3.8-flash-tts` and `gemini-3.8-flash-lite-tts` models (available
on the `global` location) return a WAV file by default. The text is read
verbatim; set how it's spoken with `speechMetadata.style`:

```dart
final response = await ai.generate(
  model: vertexAI.geminiTts('gemini-3.8-flash-lite-tts'),
  promptParts: [
    TextPart(
      text: 'Have a wonderful day!',
      metadata: {
        'speechMetadata': {'style': 'cheerful and friendly'},
      },
    ),
  ],
  config: GeminiTtsOptions(
    speechConfig: GeminiSpeechConfig(
      voiceConfig: GeminiVoiceConfig(
        prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: 'Kore'),
      ),
    ),
  ),
);
```

- **Several speakers:** set `multiSpeakerVoiceConfig` with two speakers, and
  make each turn a separate text part naming its speaker
  (`'speechMetadata': {'speaker': 'Joe'}`).
- **Format:** `GeminiTtsOptions(audioFormat: GeminiAudioFormat(mimeType:
  'audio/mulaw'))` (`audio/wav`, `audio/l16`, `audio/mulaw` or `audio/alaw`;
  optionally `sampleRate`).
- **Streaming:** audio chunks arrive while the speech is generated (raw PCM,
  `audio/l16`, by default); the final response joins them into one part.

### Video generation (Gemini Omni)

`gemini-omni-1.1-flash-preview` and `gemini-omni-flash-preview` generate
short videos with audio. `ai.generate()` returns the video directly, as an
inline MP4:

```dart
final response = await ai.generate(
  model: vertexAI.geminiVideo('gemini-omni-1.1-flash-preview'),
  prompt: 'A paper boat floating down a rain-filled gutter.',
  config: GeminiVideoOptions(
    videoFormat: GeminiVideoFormat(aspectRatio: '9:16', resolution: '720p'),
  ),
);
final video = response.media;
```

- `videoFormat`: `aspectRatio` (`16:9` default, or `9:16`), `resolution`
  (`360p`, `720p` default, `1080p`, `4k`), `delivery` (`inline` default, or
  `uri` with `gcsUri` to store the video in Cloud Storage).
- `videoConfig.task`: `text_to_video`, `image_to_video`,
  `reference_to_video`, `edit` or `extend` (inferred when not set).
- `gemini-omni-flash-preview` only supports 720p.

### Music generation (Lyria)

`lyria-3-clip-preview` and `lyria-3-pro-preview` return the music as audio
(`audio/mpeg`) plus its lyrics or caption as text. Lyria is only served on
the `global` location:

```dart
final response = await ai.generate(
  model: vertexAI.lyria('lyria-3-clip-preview'),
  prompt: 'A 30-second cheerful acoustic folk song.',
  config: LyriaOptions(location: 'global'), // if the plugin uses another
);
print(response.text); // lyrics or caption
final music = response.media;
```

### Request options

These options work on every Gemini model, on both APIs:

- **`labels`:** key-value labels for cost tracking:
  `GeminiOptions(labels: {'team': 'genkit'})`.
- **`payGo`:** `priority` or `flex` (spill over to
  [Priority](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/priority-paygo)
  or [Flex](https://docs.cloud.google.com/gemini-enterprise-agent-platform/models/flex-paygo)
  pay-as-you-go), or `priority-only` / `flex-only` (pay-as-you-go only, no
  Provisioned Throughput).
- **`location`:** sends this request to another location than the plugin's.
- **`vertexRetrieval`:** grounding with a Vertex AI Search data store:
  `GeminiOptions(vertexRetrieval: GeminiVertexRetrieval(datastore:
  GeminiVertexDatastore(dataStoreId: 'my-store')))`. The project and
  location default to the plugin's.

## Interactions API and `response.raw`

Newer Gemini models are called through the platform's **Interactions API**
(`.../projects/<project>/locations/<location>/interactions`) instead of
`generateContent`, as in the JS plugin.

### Model routing

Newer Gemini models (for example `gemini-3.8-flash`), Gemini Omni video
models and any Gemini model not listed below use the Interactions API. These
models still use `generateContent`:

- `gemini-3.8-flash-cyber`
- `gemini-3.5-flash`
- `gemini-3.1-flash-lite`
- `gemini-3.1-pro-preview`, `gemini-3.1-pro-preview-customtools`
- `gemini-3-flash-preview`
- `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite`
- image models (`gemini-*-image*`, `gemini-nano-banana-*`) and text-to-speech
  models (`gemini-*-tts*`): the platform's Interactions API doesn't support
  them

The Interactions API is available on the `global` location (the default)
and on the `us` and `eu` multi-regions. A location you set is used as is,
and the server returns an error if the model isn't available there.

### Differences on the Interactions API

- **Stateless by default:** the plugin sends `store: false`. Set
  `GeminiOptions(store: true)` on a request (or `vertexAI(store: true)` for
  every request; a request's own `store` wins) to store interactions and
  continue a conversation from the previous response's messages. On models
  that use `generateContent`, `store: true` is ignored with a warning.
- **Safety settings** are supported (unlike the Gemini API plugin).
- In a stateless conversation, earlier results of server-side tools other
  than code execution (Google Search, URL context, Google Maps, file search,
  MCP servers) are not sent back with the history, because the platform
  rejects them (a warning is logged once). The model may call those tools
  again; set `store: true` to keep the full tool history on the server.
- `vertexRetrieval.disableAttribution` isn't used on the Interactions API
  (ignored with a warning).
- The other differences are the same as for the Gemini API plugin (options
  that aren't sent, `response.raw` shape, streaming, usage): see the
  [genkit_google_genai README](https://pub.dev/packages/genkit_google_genai).
- If your code reads `response.raw`: on `generateContent` it's a
  `GenerateContentResponse` with `candidates[]`; on the Interactions API
  it's an interaction with `id`, `status` and a `steps[]` timeline.
