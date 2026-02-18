# Genkit Core Framework

Genkit Dart is an AI SDK for Dart that provides a unified interface for text generation, structured output, tool calling, and agentic workflows.

## Initialization

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart'; // Or any other plugin

void main() async {
  // Pass plugins to use into the Genkit constructor
  final ai = Genkit(plugins: [googleAI()]);
}
```

## Generate Text

```dart
final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'), // Needs a model reference from a plugin
  prompt: 'Explain quantum computing in simple terms.',
);

print(response.text);
```

## Stream Responses
```dart
final stream = ai.generateStream(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Write a short story about a robot learning to paint.',
);

await for (final chunk in stream) {
  print(chunk.text);
}
```

## Embed Text
```dart
final embeddings = await ai.embedMany(
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
  embedder: googleAI.textEmbedding('text-embedding-004'),
);

print(embeddings.first.embedding);
```

## Define Tools
Models can use define actions and access external data via custom defined tools.
Requires the [Schemantic](schemantic) library for schema definitions.

```dart
@Schematic()
abstract class $WeatherInput {
  String get location;
}

final weatherTool = ai.defineTool(
  name: 'getWeather',
  description: 'Gets the current weather for a location',
  inputSchema: WeatherInput.$schema,
  fn: (input, _) async {
    // Call your weather API here
    return 'Weather in ${input.location}: 72°F and sunny';
  },
);

final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'What\'s the weather like in San Francisco?',
  toolNames: ['getWeather'], // Use the tools
);
```

## Structured Output

You can ensure the generative model returns a typed JSON object by providing an `outputSchema`.

```dart
@Schematic()
abstract class $Person {
  String get name;
  int get age;
}

// ... inside main ...

final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Generate a person named John Doe, age 30',
  outputSchema: Person.$schema, // Force the model to return this schema
);

final person = response.output; // Typed Person object
print('Name: ${person.name}, Age: ${person.age}');
```

## Define Flows
Wrap your AI logic in flows for better observability, testing, and deployment:

```dart
final jokeFlow = ai.defineFlow(
  name: 'tellJoke',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
  fn: (topic, _) async {
    final response = await ai.generate(
      model: googleAI.gemini('gemini-2.5-flash'),
      prompt: 'Tell me a joke about $topic',
    );
    return response.text; // Value return
  },
);

final joke = await jokeFlow('programming');
print(joke);
```

### Streaming Flows
Stream data from your flows using `context.sendChunk(...)` and returning the final value:

```dart
final streamStory = ai.defineFlow(
  name: 'streamStory',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
  streamSchema: stringSchema(),
  fn: (topic, context) async {
    final stream = ai.generateStream(
      model: googleAI.gemini('gemini-2.5-flash'),
      prompt: 'Write a story about $topic',
    );

    await for (final chunk in stream) {
      context.sendChunk(chunk.text); // Stream the chunks
    }
    return 'Story complete'; // Value return
  },
);
```

## Calling Flows on Flow Servers
The `genkit` package provides `package:genkit/client.dart` representing remote Genkit actions that can be invoked or streamed using type-safe definitions.

1. Defines a remote action
```dart
import 'package:genkit/client.dart';

final stringAction = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
);
```

2. Call the Remote Action (Non-streaming)
```dart
final response = await action(input: 'Hello from Dart!');
print('Flow Response: $response');
```

3. Call the Remote Action (Streaming)
Use the `.stream()` method on the action flow, and access `stream.onResult` to wait on the async return value.
```dart
final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-story',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
  streamSchema: stringSchema(),
);

final stream = streamAction.stream(
  input: 'Tell me a short story about a Dart developer.',
);

await for (final chunk in stream) {
  print('Chunk: $chunk'); 
}

final finalResult = await stream.onResult;
print('\nFinal Response: $finalResult');
```
