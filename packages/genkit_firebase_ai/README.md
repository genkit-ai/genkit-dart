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
  provider: FirebaseAiProvider.geminiEnterprise(location: 'us-central1'),
  useLimitedUseAppCheckTokens: true,
);

final ai = Genkit(plugins: [firebasePlugin]);
```

Migrating from earlier versions: `FirebaseAiProvider.vertexAI` is now
`FirebaseAiProvider.geminiEnterprise`. The `appCheck` and `auth` parameters of
`firebaseAI` are removed; configure App Check and Auth on the `FirebaseApp`
instead. `FirebaseAiProvider.geminiEnterprise` defaults `location` to `global`,
not `us-central1`.

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

