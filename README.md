# Dart client library for Genkit

This library provides a Dart client for interacting with Genkit flows, enabling type-safe communication for both unary and streaming operations.

## Getting Started

Import the library and define your remote actions.

```dart
import 'package:genkit/client.dart';
```

## Defining remote actions

Remote actions represent a remote Genkit action (like flows, models and prompts) that can be invoked or streamed.

### Creating a remote action

```dart
// Create a remote action for a flow that takes a String and returns a String
final stringAction = defineRemoteAction(
  url: 'http://localhost:3400/my-flow',
  fromResponse: (data) => data as String,
);

// Create a remote action for custom objects
final customAction = defineRemoteAction(
  url: 'http://localhost:3400/custom-flow',
  fromResponse: (data) => MyOutput.fromJson(data),
);
```

The code assumes that you have `my-flow` and `custom-flow` deployed at those URLs. See https://genkit.dev/docs/deploy-node/ or https://genkit.dev/go/docs/deploy/ for details.

## Calling actions

### Example: String to String

```dart
final action = defineRemoteAction(
  url: 'http://localhost:3400/echo-string',
  fromResponse: (data) => data as String,
);

try {
  final response = await action(input: 'Hello from Dart!');
  print('Flow Response: $response');
} catch (e) {
  print('Error calling flow: $e');
}
```

### Example: Custom Object Input and Output

```dart
class MyInput {
  final String message;
  final int count;
  
  MyInput({required this.message, required this.count});
  
  Map<String, dynamic> toJson() => {
    'message': message,
    'count': count,
  };
}

class MyOutput {
  final String reply;
  final int newCount;
  
  MyOutput({required this.reply, required this.newCount});
  
  factory MyOutput.fromJson(Map<String, dynamic> json) => MyOutput(
    reply: json['reply'] as String,
    newCount: json['newCount'] as int,
  );
}

final action = defineRemoteAction(
  url: 'http://localhost:3400/process-object',
  fromResponse: (data) => MyOutput.fromJson(data),
);

final input = MyInput(message: 'Process this data', count: 10);

try {
  final output = await action(input: input);
  print('Flow Response: ${output.reply}, ${output.newCount}');
} catch (e) {
  print('Error calling flow: $e');
}
```

## Calling Streaming Flows

Use the `stream` method for flows that stream multiple chunks of data and then return a final response. It returns a `FlowStreamResponse` containing both the `stream` and the `response` future. The final response is optional (`Future<O?>`) because the stream may be cancelled before a final response is received, in which case the future will complete with `null`.

### Example: String Input, Streaming String Chunks, String Final Response

```dart
final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-story',
  fromResponse: (data) => data as String,
  fromStreamChunk: (data) => data['chunk'] as String,
);

try {
  final streamResponse = streamAction.stream(
    input: 'Tell me a short story about a Dart developer.',
  );

  print('Streaming chunks:');
  await for (final chunk in streamResponse.stream) {
    print('Chunk: $chunk');
  }

  final finalResult = await streamResponse.response;
  if (finalResult != null) {
    print('\nFinal Response: $finalResult');
  } else {
    print('\nStream was cancelled or finished without a final response.');
  }
} catch (e) {
  print('Error calling streamFlow: $e');
}
```

### Example: Custom Object Streaming

```dart
class StreamChunk {
  final String content;
  
  StreamChunk({required this.content});
  
  factory StreamChunk.fromJson(Map<String, dynamic> json) => StreamChunk(
    content: json['content'] as String,
  );
}

final streamAction = defineRemoteAction(
  url: 'http://localhost:3400/stream-process',
  fromResponse: (data) => MyOutput.fromJson(data),
  fromStreamChunk: (data) => StreamChunk.fromJson(data),
);

final input = MyInput(message: 'Stream this data', count: 5);

try {
  final streamResponse = streamAction.stream(input: input);

  print('Streaming chunks:');
  await for (final chunk in streamResponse.stream) {
    print('Chunk: ${chunk.content}');
  }

  final finalResult = await streamResponse.response;
  if (finalResult != null) {
    print('\nFinal Response: ${finalResult.reply}');
  } else {
    print('\nStream was cancelled or finished without a final response.');
  }
} catch (e) {
  print('Error calling streaming flow: $e');
}
```

## Custom Headers

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
  fromResponse: (data) => data as String,
  defaultHeaders: {'Authorization': 'Bearer your-token'},
);
```

## Error Handling

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

## Type Parameters

- `O`: The type of the output data from the flow's final response
- `S`: The type of the data chunks streamed from the flow (use `void` for non-streaming flows)

## Data Conversion Functions

- `fromResponse`: Converts the JSON response data to your output type `O`
- `fromStreamChunk`: (Optional) Converts JSON chunk data to your stream chunk type `S`

Make sure your custom classes have appropriate `toJson()` and `fromJson()` methods for serialization and deserialization.

## Working with Genkit Data Objects

When interacting with Genkit models, you'll often work with a set of standardized data classes that represent the inputs and outputs of generative models. This library provides these classes to make it easy to construct requests and handle responses in a type-safe way.

Key data classes include:
- `GenerateResponse`: The final response from a model generation call.
- `GenerateResponseChunk`: A streaming chunk from a model generation call.
- `Message`: Represents a message in a conversation, containing a `role` (e.g., `user`, `model`) and `content`.
- `Part`: The content of a message is made up of one or more `Part` objects. Common parts include:
  - `TextPart`: For text content.
  - `MediaPart`: For media content like images.
  - `ToolRequestPart`: A request from the model to invoke a tool.
  - `ToolResponsePart`: The response from a tool invocation.
  - `DataPart`, `CustomPart`, `ReasoningPart`, `ResourcePart`: For other specialized data.

These classes include helpful getters like `.text` to easily extract string content and `.media` to get the first media object from responses and messages.

### Example: Streaming with Genkit Data Objects

Here is an example of how to call a generative model and process the streaming response using the built-in data classes. See `example/genkit_example.dart` for a runnable version.

```dart
import 'package:genkit/client.dart';

// ...

final generateFlow = defineRemoteAction(
  url: 'http://localhost:3400/generate',
  fromResponse: (json) => GenerateResponse.fromJson(json),
  fromStreamChunk: (json) => GenerateResponseChunk.fromJson(json),
);

final (:stream, :response) = generateFlow.stream(
  input: Message(role: Role.user, content: [TextPart(text: "hello")]),
);

print('Streaming chunks:');
await for (final chunk in stream) {
  // Use the .text getter to easily access the text content of the chunk
  print('Chunk: ${chunk.text}');
}

final finalResult = await response;
// The .text getter also works on the final response
if (finalResult != null) {
  print('Final Response: ${finalResult.text}');
} else {
  print('Stream was cancelled or finished without a final response.');
}
```
