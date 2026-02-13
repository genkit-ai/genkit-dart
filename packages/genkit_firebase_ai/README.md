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

