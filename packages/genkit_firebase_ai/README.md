[![Pub](https://img.shields.io/pub/v/genkit_firebase_ai.svg)](https://pub.dev/packages/genkit_firebase_ai)

Firebase AI plugin for Genkit Dart. It calls Gemini from Flutter apps through
[Firebase AI Logic](https://firebase.google.com/docs/ai-logic), using the
`firebase_ai` SDK.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Before you start

1. [Set up Firebase AI Logic](https://firebase.google.com/docs/ai-logic/get-started?platform=flutter)
   in your Firebase project, and add Firebase to your app with
   `flutterfire configure`.
2. Set up [App Check](https://firebase.google.com/docs/ai-logic/app-check).

> **App Check is required from November 2, 2026.** From that date Firebase
> enforces App Check for Firebase AI Logic, and requests without a valid App
> Check token are blocked. That includes requests from app versions already
> released without App Check. You can delay enforcement in the Firebase
> console, but not past January 21, 2027.

Activate App Check before the first model call. The plugin reads it from the
`FirebaseApp` (see [Configuration](#configuration)). Use the debug providers
during development and the platform attestation providers in release builds:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
await FirebaseAppCheck.instance.activate(
  providerAndroid: kDebugMode
      ? const AndroidDebugProvider()
      : const AndroidPlayIntegrityProvider(),
  providerApple: kDebugMode
      ? const AppleDebugProvider()
      : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  providerWeb: kDebugMode
      ? WebDebugProvider()
      : ReCaptchaEnterpriseProvider('your-recaptcha-site-key'),
);
```

Never ship the debug providers: anyone with a registered debug token passes
App Check. On first run, each debug provider logs a debug token (in the
browser console on web). Add it in the Firebase console under App Check >
Apps > Manage debug tokens. The release providers need their own setup in the
Firebase console; see
[Get started with App Check](https://firebase.google.com/docs/app-check/flutter/default-providers).

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

void main() async {
  // Initialize Genkit with the Firebase AI plugin
  final ai = Genkit(plugins: [firebaseAI()]);

  // Generate text
  final response = await ai.generate(
    model: firebaseAI.gemini('gemini-flash-latest'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
}
```

## Models

`firebaseAI.gemini(name)` works with any Gemini model that Firebase AI Logic
serves. See [supported models](https://firebase.google.com/docs/ai-logic/models)
for names and shutdown dates. The plugin also registers the models Firebase
AI Logic serves, so they show up in the Genkit Developer UI with their
capabilities:

- Text: `gemini-4-argon`, `gemini-3.8-flash`, `gemini-3.5-flash`,
  `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite` and `gemini-3.1-pro-preview`.
  `gemini-flash-latest`, `gemini-3.7-flash` and `gemini-3.6-flash` are
  registered for the Gemini Developer API only (the last two are deprecated on
  Agent Platform).
- Image: `gemini-nano-banana-2.1`, `gemini-3.1-flash-image`,
  `gemini-3.1-flash-lite-image` and `gemini-3-pro-image`.
- Text-to-speech: `gemini-3.8-flash-tts` and `gemini-3.8-flash-lite-tts`.
- Live (see [Live API](#live-api-experimental)): `gemini-3.8-live` on both
  providers, and `gemini-live-2.5-flash-native-audio` on Agent Platform only.

Gemini models are retired often, and a model name compiled into your app
stops working when its model shuts down. For example, Gemini 2.5 Pro, Flash
and Flash-Lite shut down on Agent Platform on October 20, 2026. Firebase
[recommends](https://firebase.google.com/docs/ai-logic/change-model-name-remotely)
reading the model name from Remote Config, so you can change it without an
app release:

```dart
import 'package:firebase_remote_config/firebase_remote_config.dart';

final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.setDefaults({'model_name': 'gemini-3.8-flash'});
await remoteConfig.fetchAndActivate();

final response = await ai.generate(
  model: firebaseAI.gemini(remoteConfig.getString('model_name')),
  prompt: 'Tell me a joke about a developer.',
);
```

## Configuration

You can optionally pass in `FirebaseApp` and `FirebaseAiProvider` instances,
and the `useLimitedUseAppCheckTokens` flag when initializing the plugin. App
Check and Auth are read from the `FirebaseApp`.

```dart
final firebasePlugin = firebaseAI(
  app: Firebase.app('my-app'),
  provider: FirebaseAiProvider.agentPlatform(),
  useLimitedUseAppCheckTokens: true,
);

final ai = Genkit(plugins: [firebasePlugin]);
```

- `provider`: `FirebaseAiProvider.googleAI()` (the default) uses the Gemini
  Developer API. `FirebaseAiProvider.agentPlatform()` uses the Agent Platform
  (formerly Vertex AI) Gemini API.
- `useLimitedUseAppCheckTokens`: sends a single-use App Check token with each
  request. You need it if you turn on
  [replay protection](https://firebase.google.com/docs/ai-logic/app-check),
  which blocks reusable session tokens.

Set `location` for data residency, or for Agent Platform Live models, which
need a regional location such as `'us-central1'`. Text models may be served
only on the default `global` location, and a regional one fails with
`NOT_FOUND` for them. A plugin instance has one location, so an app that uses
both Live and text models on Agent Platform needs two `Genkit` instances:

```dart
final ai = Genkit(
  plugins: [firebaseAI(provider: const FirebaseAiProvider.agentPlatform())],
);
final live = Genkit(
  plugins: [
    firebaseAI(
      provider: const FirebaseAiProvider.agentPlatform(location: 'us-central1'),
    ),
  ],
);
```

Migrating from earlier versions:

- `FirebaseAiProvider.vertexAI` is now `FirebaseAiProvider.agentPlatform`. It
  defaults `location` to `global`, not `us-central1`. Pass
  `location: 'us-central1'` to keep the old behavior.
- The `appCheck` and `auth` parameters of `firebaseAI` are removed. The
  Firebase AI SDK reads App Check and Auth from the `FirebaseApp` only when it
  first builds its `FirebaseAI` instance, and it caches that instance per app
  (and per location for `agentPlatform`). It only finds services registered
  with `FirebaseAppCheck.instanceFor(app:)` and `FirebaseAuth.instanceFor(app:)`
  (or `.instance` for the default app). So set up App Check and Auth for that
  app before the first model call. Before firebase_ai 5.1, for the same
  reason, `useLimitedUseAppCheckTokens` has no effect if the app already
  created a `FirebaseAI` instance for the same Firebase app and location. From
  5.1 the flag is part of that cache key, so it always applies. Instances
  created for a different app than `app:` are no longer used.
- Tool input schemas are sent unchanged as `parametersJsonSchema`. They used to
  be converted to OpenAPI-style `parameters`, which dropped keywords such as
  `oneOf`, `additionalProperties` and `default`. The model now gets the full
  schema, so a tool can behave differently with the same definition.
- The converter and Live helper functions (`toGemini*`, `fromGemini*`,
  `extractUsage`, `runLiveSession`, `toLiveGenerationConfig` and the like) are
  no longer exported. They were meant for the plugin's own use. Call models
  through `firebaseAI` and `ai.generate` or `ai.generateBidi` instead.

To route requests through your own `http.Client` (a proxy, logging, retries,
or a mock in tests), pass `httpClient`. Live models connect over a WebSocket
and do not use it. The plugin never closes a client you provide, so close it
yourself when you are done:

```dart
import 'package:http/http.dart' as http;

final httpClient = http.Client();
final ai = Genkit(plugins: [firebaseAI(httpClient: httpClient)]);
// ...
httpClient.close();
```

## Model options

Pass `GeminiOptions` as `config`:

```dart
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-3.8-flash'),
  prompt: 'Plan a three-day trip to Lisbon.',
  config: GeminiOptions(
    maxOutputTokens: 2048,
    thinkingConfig: ThinkingConfig(thinkingLevel: 'LOW'),
  ),
);
```

Gemini 3 and newer models ignore `temperature`, `topP` and `topK`, and may
reject `presencePenalty` and `frequencyPenalty` with a 400 error. They don't
support `candidateCount` either. On older models, a non-streaming request with
`candidateCount` above 1 returns the first candidate as `text` and `message`
and the rest in `raw`; streaming with it fails with `INVALID_ARGUMENT`.

### Thinking

Gemini 3 and newer models take a `thinkingLevel`: `MINIMAL`, `LOW`, `MEDIUM`
or `HIGH`. The value must be uppercase. Which levels a model accepts depends on
the model; `gemini-3.8-flash`, for example, rejects `MINIMAL` with
`INVALID_ARGUMENT`. Older models take a `thinkingBudget`
in tokens instead. Setting both fails with `INVALID_ARGUMENT` before any
request is sent. Set `includeThoughts: true` to get the model's thought
summaries back as reasoning parts.

```dart
config: GeminiOptions(
  thinkingConfig: ThinkingConfig(thinkingLevel: 'HIGH', includeThoughts: true),
),
```

Gemini 3 returns thought signatures, which it needs back in later turns, for
example for multi-turn tool calling. The plugin keeps each one in its part's
`metadata['thoughtSignature']` and sends it back when you pass the response
messages into the next request. `firebase_ai` has no public API for setting a
signature, so the plugin uses its `@visibleForTesting` constructors for this
([flutterfire#18917](https://github.com/firebase/flutterfire/issues/18917)). A
`firebase_ai` release that changes them can break the round trip.

### Code execution

`codeExecution: true` lets the model write and run Python. The code and its
result come back as custom parts with the keys `executableCode` and
`codeExecutionResult`.

With `firebase_ai` older than 5.0.0, a file part in a response (for example
a file the model generated) also comes back as a custom part, under
`fileData`, instead of a media part
([flutterfire#18753](https://github.com/firebase/flutterfire/issues/18753)).
Use `firebase_ai` 5.0.0 or later to get it as media.

### Safety settings

`safetySettings` sets a blocking threshold per harm category. The
`HARM_CATEGORY_IMAGE_*` categories and `method` work on Agent Platform only.
With the Gemini Developer API, the plugin rejects them with `INVALID_ARGUMENT`
before sending the request.

```dart
config: GeminiOptions(
  safetySettings: [
    GeminiSafetySettings(
      category: 'HARM_CATEGORY_HARASSMENT',
      threshold: 'BLOCK_ONLY_HIGH',
    ),
  ],
),
```

### Grounding

`googleSearch` grounds answers in Google Search, `urlContext` lets the model
read the URLs in the prompt, and `googleMaps` grounds answers in Google Maps
data. For Maps, pass the user's location in `retrievalConfig`; a `latLng` with
only one coordinate fails with `INVALID_ARGUMENT`.

```dart
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-3.8-flash'),
  prompt: 'Who won the most recent Formula 1 race?',
  config: GeminiOptions(googleSearch: GeminiGoogleSearch()),
);

final grounding = response.custom?['groundingMetadata'] as Map?;
print(grounding?['webSearchQueries']);
for (final chunk in grounding?['groundingChunks'] as List? ?? []) {
  print(chunk['web']?['uri']);
}
```

```dart
config: GeminiOptions(
  googleMaps: GeminiGoogleMaps(),
  retrievalConfig: GeminiRetrievalConfig(
    latLng: GeminiLatLng(latitude: 38.72, longitude: -9.14),
  ),
),
```

The response's `custom` holds `groundingMetadata` (`webSearchQueries`,
`groundingChunks`, `groundingSupports` and `searchEntryPoint`) and, for URL
context, `urlContextMetadata`. Both are rebuilt from what `firebase_ai`
parses, so absent lists come back empty. With `firebase_ai` older than 5.1.0,
`webSearchQueries` is always empty
([flutterfire#18816](https://github.com/firebase/flutterfire/issues/18816)).
If you use Google Search grounding,
you must
[display the search suggestions and sources](https://firebase.google.com/docs/ai-logic/grounding-google-search):
`searchEntryPoint.renderedContent` is HTML to show in your app.

### Images and speech

Image models return images as media parts with a `data:` URL. Set
`responseModalities` and, optionally, `imageConfig`:

```dart
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-3.1-flash-image'),
  prompt: 'A watercolor of a lighthouse at dawn.',
  config: GeminiOptions(
    responseModalities: ['TEXT', 'IMAGE'],
    imageConfig: GeminiImageConfig(aspectRatio: '16:9', imageSize: '2K'),
  ),
);
final image = response.media; // data:image/png;base64,...
```

Text-to-speech models return audio the same way. `speechConfig` takes one
voice, or a `multiSpeakerVoiceConfig` with exactly two speakers whose names
match the prompt:

```dart
config: GeminiOptions(
  responseModalities: ['AUDIO'],
  speechConfig: SpeechConfig(
    multiSpeakerVoiceConfig: MultiSpeakerVoiceConfig(
      speakerVoiceConfigs: [
        SpeakerVoiceConfig(
          speaker: 'Joe',
          voiceConfig: VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Kore'),
          ),
        ),
        SpeakerVoiceConfig(
          speaker: 'Jane',
          voiceConfig: VoiceConfig(
            prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Puck'),
          ),
        ),
      ],
    ),
    languageCode: 'en-US',
  ),
),
```

### Media resolution

`mediaResolution` sets how much detail the model takes from images and video
in the prompt: `MEDIA_RESOLUTION_LOW`, `MEDIA_RESOLUTION_MEDIUM` or
`MEDIA_RESOLUTION_HIGH`. A media part can set its own, which also takes
`MEDIA_RESOLUTION_ULTRA_HIGH`:

```dart
MediaPart(
  media: Media(url: 'gs://my-bucket/scan.png', contentType: 'image/png'),
  metadata: {'mediaResolution': 'MEDIA_RESOLUTION_ULTRA_HIGH'},
)
```

Live realtime audio and video have no media resolution, so it's dropped there
with a warning.

## Structured output

With `outputSchema`, the plugin sends your JSON schema to Gemini unchanged as
`responseJsonSchema`, so `enum`, `anyOf`, `$ref`, `minimum`/`maximum`,
`additionalProperties` and `required` all apply:

```dart
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-flash-latest'),
  prompt: 'List three primary colors.',
  outputSchema: .list(.string()),
);
print(response.output);
```

## Tool Calling

```dart
// Define a tool
ai.defineTool(
  name: 'getWeather',
  description: 'Get the weather for a location',
  inputSchema: WeatherToolInput.$schema,
  fn: (input, context) async {
    return .response('The weather in ${input.location} is 75 and sunny.');
  },
);

// Generate with tools
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-flash-latest'),
  prompt: 'What is the weather in Boston?',
  toolNames: ['getWeather'],
);
```

A tool's input schema goes to Gemini unchanged as `parametersJsonSchema`, so
`enum`, `anyOf`, `$ref`, `minimum`/`maximum` and `additionalProperties` reach
the model.

## Errors

Errors from Firebase AI Logic, the network or the SDK are reported as a
`GenkitException` with a status code. For example, quota errors are
`RESOURCE_EXHAUSTED`, an unavailable service is `UNAVAILABLE`, and a prompt
blocked for safety is `FAILED_PRECONDITION`.

`ai.generate` does not throw for these. It returns a response with
`finishReason: FinishReason.failed`, the status and message in
`response.error`, and the exception in `response.cause`. For a `firebase_ai` or
network error, the original exception is the `cause` of that exception.

```dart
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-flash-latest'),
  prompt: 'Hello',
  use: [retry(maxRetries: 2)],
);
if (response.finishReason == FinishReason.failed) {
  print('${response.error?.status}: ${response.error?.message}');
}
```

`retry` retries statuses that can succeed on a second try, such as
`UNAVAILABLE` and `RESOURCE_EXHAUSTED`. A blocked prompt is not retried.

To stop a request, pass a cancellation token. Cancelling aborts the HTTP
request or stream, and the response ends with `FinishReason.aborted`:

```dart
final controller = CancellationController();
final result = ai.generate(
  model: firebaseAI.gemini('gemini-flash-latest'),
  prompt: 'Write a long story.',
  cancel: controller.token,
);
// Later, for example when the user taps Stop:
controller.cancel('user pressed stop');
```

## Live API (experimental)

Live models stream audio and text both ways over a WebSocket, through
`generateBidi`. This is built on Genkit's experimental API
(`package:genkit/experimental.dart`), which can change in any minor release.

```dart
import 'package:genkit/experimental.dart';

final session = await ai.generateBidi(
  model: 'firebaseai/gemini-3.8-live',
  config: LiveGenerationConfig(
    responseModalities: ['AUDIO'],
    speechConfig: SpeechConfig(
      voiceConfig: VoiceConfig(
        prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: 'Algenib'),
      ),
    ),
  ),
  system: 'You are a friendly assistant.',
);
session.send('Hello');
session.stream.listen((chunk) {
  // Audio media parts (data: URLs).
});
```

`gemini-3.8-live` works with both providers. On Agent Platform, Live models
need a `location` such as `'us-central1'`; with the default `global` location
the server closes the session because it can't find the model. Agent Platform
also serves `gemini-live-2.5-flash-native-audio`.

On web, Live sessions don't work while App Check is enforced: `firebase_ai`
doesn't send the App Check token on the web WebSocket, so the server closes the
session with "Firebase App Check token is invalid"
([flutterfire#18938](https://github.com/firebase/flutterfire/issues/18938)).
On Android, iOS and macOS it sends the token as a header.

A session takes system messages only in its first request (`system:` above);
sending one later fails with `INVALID_ARGUMENT`. If the server closes the
session, for example for a bad setup, the session ends with that error rather
than a normal stop.

See [`testapps/firebase_ai`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/firebase_ai)
for a complete Flutter app with tool calling, grounding and Live audio.
