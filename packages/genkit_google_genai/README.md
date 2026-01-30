[![Pub](https://img.shields.io/pub/v/genkit_google_genai.svg)](https://pub.dev/packages/genkit_google_genai)

Google AI plugin for Genkit Dart.

## Usage

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  // Initialize Genkit with the Google AI plugin
  final ai = Genkit(plugins: [googleAI()]);

  // Generate text
  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
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

@Schematic()
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
      return 'The weather in ${input.location} is 75 and sunny.';
    },
  );

  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: 'What is the weather in Boston?',
    tools: ['getWeather'],
  );
  
  print(response.text);
}
```


