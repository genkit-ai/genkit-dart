[![Pub](https://img.shields.io/pub/v/genkit.svg)](https://pub.dev/packages/genkit)

**AI SDK for Dart • LLM Framework • AI Agent Toolkit**

Build production-ready AI-powered applications in Dart with a unified interface for text generation, structured output, tool calling, and agentic workflows.

[Documentation](https://genkit.dev) • [API Reference](https://pub.dev/packages/genkit) • [Discord](https://discord.gg/qXt5zzQKpc)

---

## Installation

```bash
dart pub add genkit
# For usage with Google AI (Gemini):
dart pub add genkit_google_genai
```

## Quick Start (Framework)

Get up and running in under a minute:

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  final ai = Genkit(plugins: [googleAI()]);

  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: 'Why is Dart a great language for AI applications?',
  );

  print(response.text);
}
```

```bash
export GEMINI_API_KEY="your-api-key"
dart run main.dart
```

---

## Features

Genkit Dart gives you everything you need to build AI applications with confidence.

### Generate Text

Call any model with a simple, unified API:

```dart
final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Explain quantum computing in simple terms.',
);
print(response.text);
```

### Stream Responses

Stream text as it's generated for responsive user experiences:

```dart
final stream = ai.generateStream(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Write a short story about a robot learning to paint.',
);

await for (final chunk in stream) {
  print(chunk.text);
}
```

### Embed Text

Turn text into vector embeddings for search and retrieval tasks:

```dart
final embeddings = await ai.embedMany(
  documents: [
    DocumentData(content: [TextPart(text: 'Hello world')]),
  ],
  embedder: googleAI.textEmbedding('text-embedding-004'),
);

print(embeddings.first.embedding);
```

### Define Tools

Give models the ability to take actions and access external data:

```dart
// Define schemas for tool input
@Schematic()
abstract class $WeatherInput {
  String get location;
}

// ... run build_runner to generate WeatherInputType ...

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
  toolNames: ['getWeather'],
);
print(response.text);
```

### Define Flows

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
    return response.text;
  },
);

final joke = await jokeFlow('programming');
print(joke);
```

### Streaming Flows

Stream data from your flows using `context.sendChunk`:

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
      context.sendChunk(chunk.text);
    }
    return 'Story complete';
  },
);
```

### Middleware

Intercept and modify requests and responses with middleware. Genkit provides built-in middleware like `retry` for robust error handling.

#### Retry Middleware

Automatically retry failed requests with exponential backoff and jitter:

```dart
final ai = Genkit(
  plugins: [
    googleAI(),
    RetryPlugin(), // Required for retry middleware
  ],
);

final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'Reliable request',
  use: [
    retry(
      maxRetries: 3,
      retryModel: true, // Retry model validation errors (default: true)
      retryTools: false, // Retry tool execution errors (default: false)
      statuses: [StatusCodes.UNAVAILABLE], // Retry only on specific errors
    ),
  ],
);
```

---

## Development Tools

### Genkit CLI

Use the Genkit CLI to run your app with tracing and a local development UI:

```bash
curl -sL cli.genkit.dev | bash
genkit start -- dart run main.dart
```

### Developer UI

The local developer UI lets you:

- **Test flows** with different inputs interactively
- **Inspect traces** to debug complex multi-step operations
- **View traces** of your generative AI applications

---

## Client SDK

This package also provides a Dart client for interacting with remote Genkit flows, enabling type-safe communication for both unary and streaming operations.

### Getting Started

Import the client library and define your remote actions.

```dart
import 'package:genkit/client.dart';

### Defining Remote Actions

Remote actions represent a remote Genkit action (like flows, models and prompts) that can be invoked or streamed. You use generated `*Type` classes (from `@Schematic`) to ensure type safety.

#### Creating a remote action
final stringAction = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
);

// Create a remote action for custom objects
final customAction = defineRemoteAction(
  url: 'http://localhost:3400/custom-flow',
  inputSchema: MyInput.$schema,
  outputSchema: MyOutput.$schema,
);
```

The code assumes that you have `my-flow` and `custom-flow` deployed at those URLs. See https://genkit.dev/docs/deploy-node/ or https://genkit.dev/go/docs/deploy/ for details.

### Calling Actions

#### Example: String to String

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/echo-string',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
);

try {
  final response = await action(input: 'Hello from Dart!');
  print('Flow Response: $response');
} catch (e) {
  print('Error calling flow: $e');
}
```

#### Example: Custom Object Input and Output

First, define your schemas and run `build_runner` to generate the types.

```dart
@Schematic()
abstract class $MyInput {
  String get message;
  int get count;
}

@Schematic()
abstract class $MyOutput {
  String get reply;
  int get newCount;
}

// ... run build_runner ...
```

Then define and call the action:

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/process-object',
  inputSchema: MyInput.$schema,
  outputSchema: MyOutput.$schema,
);

final input = MyInput(message: 'Process this data', count: 10);

try {
  final output = await action(input: input);
  print('Flow Response: ${output.reply}, ${output.newCount}');
} catch (e) {
  print('Error calling flow: $e');
}
```

### Calling Streaming Flows

Use the `stream` method for flows that stream multiple chunks of data and then return a final response. Specify `streamSchema` to handle typed chunks.

#### Example 1: Using `onResult` (Recommended)

```dart
final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-story',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
  streamSchema: stringSchema(),
);

try {
  final stream = streamAction.stream(
    input: 'Tell me a short story about a Dart developer.',
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: $chunk'); // chunk is String
  }

  // Use onResult to asynchronously get the final response.
  final finalResult = await stream.onResult;
  print('\nFinal Response: $finalResult');
} catch (e) {
  print('Error calling streamFlow: $e');
}
```

#### Example: Custom Object Streaming

```dart
@Schematic()
abstract class $StreamChunk {
  String get content;
}

// ... generated StreamChunkType ...

final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-process',
  inputSchema: MyInput.$schema,
  outputSchema: MyOutput.$schema,
  streamSchema: StreamChunk.$schema,
);

final input = MyInput(message: 'Stream this data', count: 5);

try {
  final stream = streamAction.stream(input: input);

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.content}');
  }

  final finalResult = await stream.onResult;
  print('\nFinal Response: ${finalResult.reply}');
} catch (e) {
  print('Error calling streaming flow: $e');
}
```

### Custom Headers

You can provide custom headers for individual requests:

```dart
final response = await action(
  input: 'test input',
  headers: {'Authorization': 'Bearer your-token'},
);

// For streaming
final streamResponse = action.stream(
  input: 'test input',
  headers: {'Authorization': 'Bearer your-token'},
);
```

You can also set default headers when creating the remote action:

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  inputSchema: stringSchema(),
  outputSchema: stringSchema(),
  defaultHeaders: {'Authorization': 'Bearer your-token'},
);
```

### Error Handling

The library throws `GenkitException` for various error conditions:

```dart
try {
  final result = await action(input: 'test');
} on GenkitException catch (e) {
  print('Genkit error: ${e.message}');
  print('Status code: ${e.statusCode}');
  print('Details: ${e.details}');
} catch (e) {
  print('Other error: $e');
}
```

### Advanced: Manual Data Conversion

For advanced use cases where generated types are not available, you can still use `fromResponse` and `fromStreamChunk` for manual conversion:

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  fromResponse: (data) => data as String,
);
```

### Working with Genkit Data Objects

When interacting with Genkit models, you'll often work with a set of standardized data classes that represent the inputs and outputs of generative models.

#### Example: Streaming with Genkit Data Objects

```dart
import 'package:genkit/client.dart';

final generateFlow = defineRemoteAction(
  url: 'http://localhost:3400/generate',
  inputSchema: ModelRequest.$schema,
  outputSchema: ModelResponse.$schema,
  streamSchema: ModelResponseChunk.$schema,
);

final stream = generateFlow.stream(
  input: ModelRequest(
    messages: [Message(role: Role.user, content: [TextPart(text: "hello")])],
  ),
);

print('Streaming chunks:');
await for (final chunk in stream) {
  print('Chunk: ${chunk.text}');
}

final finalResult = await stream.onResult;
print('Final Response: ${finalResult.text}');
```

### Remote Models

You can also define and use remotely deployed models as if they were local models using `defineRemoteModel`. This is particularly useful when you have models hosted via `genkit_shelf` or other compatible Genkit servers.

```dart
final remoteModel = ai.defineRemoteModel(
  name: 'my-remote-model',
  url: 'http://localhost:3400/my-model',
  // Optional: Provide custom headers dynamically based on context
  headers: (context) {
    return {'Authorization': 'Bearer ${context['token']}'};
  },
);

final response = await ai.generate(
  model: remoteModel,
  prompt: 'say hello',
  context: {'token': 'my-secret-token'},
);

print(response.text);
```

---

## Genkit Lite API

For lightweight applications or scripts where you only need basic model orchestration without the full Genkit framework (no registries, flows, or Dev UI), you can use the Lite API.

```dart
import 'package:genkit/lite.dart' as lite;
// Need to import genkit for standard components like RetryMiddleware
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main() async {
  // 1. Initialize the plugin directly
  final gemini = googleAI();

  // 2. Direct generation call without a Genkit instance
  final response = await lite.generate(
    model: gemini.model('gemini-2.5-flash'),
    prompt: 'Hello from Lite API!',
    // Middleware objects are used directly in the Lite API
    use: [
      RetryMiddleware(maxRetries: 2),
    ],
  );

  print(response.text);
}
```

---

Built by [Google](https://firebase.google.com/) with contributions from the [Open Source Community](https://github.com/firebase/genkit/graphs/contributors)
