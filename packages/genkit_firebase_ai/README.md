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
`FirebaseApp` (see [Configuration](#configuration)). During development, use
the debug providers:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
await FirebaseAppCheck.instance.activate(
  providerAndroid: const AndroidDebugProvider(),
  providerApple: const AppleDebugProvider(),
);
```

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
for names and shutdown dates. The plugin also registers these models for the
Genkit Developer UI:

- `gemini-flash-latest`
- `gemini-3.1-pro-preview`
- `gemini-2.5-flash-native-audio-preview-12-2025` (Live, see
  [Live API](#live-api-experimental))

Gemini models are retired often, and a model name compiled into your app
stops working when its model shuts down. For example, the Gemini 2.5 models
shut down in October 2026. Firebase
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

Set `location` (for example `'us-central1'`) for Agent Platform Live models
such as `gemini-live-2.5-flash-native-audio`, which are not available on the
default `global` location, or for data residency.

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
  app before the first model call. For the same reason,
  `useLimitedUseAppCheckTokens` has no effect if the app already created a
  `FirebaseAI` instance for the same Firebase app and location. Instances
  created for a different app than `app:` are no longer used.

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
    temperature: 0.7,
    maxOutputTokens: 2048,
    thinkingConfig: ThinkingConfig(thinkingLevel: 'LOW'),
  ),
);
```

### Thinking

Gemini 3 and newer models take a `thinkingLevel`: `MINIMAL`, `LOW`, `MEDIUM`
or `HIGH`. The value must be uppercase. Older models take a `thinkingBudget`
in tokens instead. Setting both fails with `INVALID_ARGUMENT` before any
request is sent. Set `includeThoughts: true` to get the model's thought
summaries back as reasoning parts.

```dart
config: GeminiOptions(
  thinkingConfig: ThinkingConfig(thinkingLevel: 'HIGH', includeThoughts: true),
),
```

### Code execution

`codeExecution: true` lets the model write and run Python. The code and its
result come back as custom parts with the keys `executableCode` and
`codeExecutionResult`.

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

## Errors

Errors from Firebase AI Logic, the network or the SDK are reported as a
`GenkitException` with a status code. For example, quota errors are
`RESOURCE_EXHAUSTED`, an unavailable service is `UNAVAILABLE`, and a prompt
blocked for safety is `FAILED_PRECONDITION`.

`ai.generate` does not throw for these. It returns a response with
`finishReason: FinishReason.failed`, the status and message in
`response.error`, and the exception in `response.cause`. The original
`firebase_ai` exception is the `cause` of that exception.

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

## Live API (experimental)

Live models stream audio and text both ways over a WebSocket, through
`generateBidi`. This is built on Genkit's experimental API
(`package:genkit/experimental.dart`), which can change in any minor release.

```dart
import 'package:genkit/experimental.dart';

final session = await ai.generateBidi(
  model: 'firebaseai/gemini-2.5-flash-native-audio-preview-12-2025',
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
  // Text parts and audio media parts (data: URLs).
});
```

Live model names differ by provider. The Gemini Developer API serves
`gemini-3.1-flash-live-preview` and the `gemini-2.5-flash-native-audio-*`
previews. Agent Platform serves `gemini-live-2.5-flash-native-audio`, which
needs a `location` such as `'us-central1'`.

See [`testapps/firebase_ai`](https://github.com/genkit-ai/genkit-dart/tree/main/testapps/firebase_ai)
for a complete Flutter app with tool calling and Live audio.
