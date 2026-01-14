# Genkit Dart

[![Pub](https://img.shields.io/pub/v/genkit.svg)](https://pub.dev/packages/genkit)
[![Dart SDK](https://img.shields.io/badge/Dart-SDK-blue.svg)](https://github.com/firebase/genkit/tree/main/dart)

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

### Define Tools

Give models the ability to take actions and access external data:

```dart
// Define schemas for tool input
@GenkitSchema()
abstract class WeatherInput {
  String get location;
}

// ... run build_runner to generate WeatherInputType ...

final weatherTool = ai.defineTool(
  name: 'getWeather',
  description: 'Gets the current weather for a location',
  inputType: WeatherInputType,
  fn: (input, _) async {
    // Call your weather API here
    return 'Weather in ${input.location}: 72°F and sunny';
  },
);

final response = await ai.generate(
  model: googleAI.gemini('gemini-2.5-flash'),
  prompt: 'What\'s the weather like in San Francisco?',
  tools: ['getWeather'],
);
print(response.text);
```

### Define Flows

Wrap your AI logic in flows for better observability, testing, and deployment:

```dart
final jokeFlow = ai.defineFlow(
  name: 'tellJoke',
  inputType: StringType,
  outputType: StringType,
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
  inputType: StringType,
  outputType: StringType,
  streamType: StringType,
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
import 'package:genkit/schema.dart';
```

### Defining Remote Actions

Remote actions represent a remote Genkit action (like flows, models and prompts) that can be invoked or streamed. You use generated `*Type` classes (from `@GenkitSchema`) to ensure type safety.

#### Creating a remote action

```dart
// Create a remote action for a flow that takes a String and returns a String
final stringAction = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  inputType: StringType,
  outputType: StringType,
);

// Create a remote action for custom objects
final customAction = defineRemoteAction(
  url: 'http://localhost:3400/custom-flow',
  inputType: MyInputType,
  outputType: MyOutputType,
);
```

The code assumes that you have `my-flow` and `custom-flow` deployed at those URLs. See https://genkit.dev/docs/deploy-node/ or https://genkit.dev/go/docs/deploy/ for details.

### Calling Actions

#### Example: String to String

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/echo-string',
  inputType: StringType,
  outputType: StringType,
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
@GenkitSchema()
abstract class MyInput {
  String get message;
  int get count;
}

@GenkitSchema()
abstract class MyOutput {
  String get reply;
  int get newCount;
}

// ... run build_runner ...
```

Then define and call the action:

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/process-object',
  inputType: MyInputType,
  outputType: MyOutputType,
);

final input = MyInput.from(message: 'Process this data', count: 10);

try {
  final output = await action(input: input);
  print('Flow Response: ${output.reply}, ${output.newCount}');
} catch (e) {
  print('Error calling flow: $e');
}
```

### Calling Streaming Flows

Use the `stream` method for flows that stream multiple chunks of data and then return a final response. Specify `streamType` to handle typed chunks.

#### Example 1: Using `onResult` (Recommended)

```dart
final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-story',
  inputType: StringType,
  outputType: StringType,
  streamType: StringType,
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
@GenkitSchema()
abstract class StreamChunk {
  String get content;
}

// ... generated StreamChunkType ...

final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-process',
  inputType: MyInputType,
  outputType: MyOutputType,
  streamType: StreamChunkType,
);

final input = MyInput.from(message: 'Stream this data', count: 5);

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
  inputType: StringType,
  outputType: StringType,
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
  inputType: ModelRequestType,
  outputType: ModelResponseType,
  streamType: ModelResponseChunkType,
);

final stream = generateFlow.stream(
  input: ModelRequest.from(
    messages: [Message.from(role: Role.user, content: [TextPart.from(text: "hello")])],
  ),
);

print('Streaming chunks:');
await for (final chunk in stream) {
  print('Chunk: ${chunk.text}');
}

final finalResult = await stream.onResult;
print('Final Response: ${finalResult.text}');
```

---

Built by [Google](https://firebase.google.com/) with contributions from the [Open Source Community](https://github.com/firebase/genkit/graphs/contributors)
