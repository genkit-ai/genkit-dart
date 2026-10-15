[![Pub](https://img.shields.io/pub/v/genkit_firebase_ai.svg)](https://pub.dev/packages/genkit_firebase_ai)

Firebase AI plugin for Genkit Dart.

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

### Configuration

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

Set `location` (for example `'us-central1'`) for Agent Platform Live models
such as `gemini-live-2.5-flash-native-audio`, which are not available on the
default `global` location, or for data residency.

Migrating from earlier versions:

- `FirebaseAiProvider.vertexAI` is now `FirebaseAiProvider.agentPlatform`. It
  defaults `location` to `global`, not `us-central1`. If your app relies on the
  old `us-central1` default (for Agent Platform Live models such as
  `gemini-live-2.5-flash-native-audio`, which are not available on `global`,
  or for data residency), pass `location: 'us-central1'` explicitly.
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

### Tool Calling

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

