[![Pub](https://img.shields.io/pub/v/genkit_firebase_ai.svg)](https://pub.dev/packages/genkit_firebase_ai)

Firebase AI plugin for Genkit Dart.

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

void main() async {
  // Initialize Genkit with the Firebase AI plugin
  final ai = Genkit(plugins: [firebaseAI()]);

  // Generate text
  final response = await ai.generate(
    model: firebaseAI.gemini('gemini-2.5-flash'),
    prompt: 'Tell me a joke about a developer.',
  );

  print(response.text);
}
```

### Configuration

You can optionally pass in `FirebaseApp`, `FirebaseAppCheck`, `FirebaseAuth` 
instances, and `useLimitedUseAppCheckTokens` flag when initializing the plugin:

```dart
final firebasePlugin = firebaseAI(
  app: Firebase.app('my-app'),
  appCheck: FirebaseAppCheck.instanceFor(app: Firebase.app('my-app')),
  auth: FirebaseAuth.instanceFor(app: Firebase.app('my-app')),
  useLimitedUseAppCheckTokens: true,
);

final ai = Genkit(plugins: [firebasePlugin]);
```

### Tool Calling

```dart
// Define a tool
ai.defineTool(
  name: 'getWeather',
  description: 'Get the weather for a location',
  inputSchema: WeatherToolInput.$schema,
  fn: (input, context) async {
    return 'The weather in ${input.location} is 75 and sunny.';
  },
);

// Generate with tools
final response = await ai.generate(
  model: firebaseAI.gemini('gemini-2.5-flash'),
  prompt: 'What is the weather in Boston?',
  toolNames: ['getWeather'],
);
```

