# Dart client library for Genkit

This library provides a Dart client for interacting with Genkit flows, enabling type-safe communication for both unary and streaming operations.

## Getting Started

Import the library and define your remote actions.

```dart
import 'package:genkit/genkit.dart';
```

## `RemoteAction` - Core Class

The `RemoteAction` class represents a remote Genkit flow that can be invoked or streamed.

### Creating a RemoteAction

```dart
// Create a RemoteAction for a flow that takes a String and returns a String
final stringAction = RemoteAction<String, void>(
  url: 'http://localhost:3400/my-flow',
  fromResponse: (data) => data as String,
);

// Create a RemoteAction for custom objects
final customAction = RemoteAction<MyOutput, void>(
  url: 'http://localhost:3400/custom-flow',
  fromResponse: (data) => MyOutput.fromJson(data),
);
```

## Calling Unary Flows

### Example: String to String

```dart
final action = RemoteAction<String, void>(
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

final action = RemoteAction<MyOutput, void>(
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

Use the `stream` method for flows that stream multiple chunks of data and then return a final response. It returns a `FlowStreamResponse` containing both the `stream` and the `response` future.

### Example: String Input, Streaming String Chunks, String Final Response

```dart
final streamAction = RemoteAction<String, String>(
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
  print('\nFinal Response: $finalResult');
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

final streamAction = RemoteAction<MyOutput, StreamChunk>(
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
  print('\nFinal Response: ${finalResult.reply}');
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

You can also set default headers when creating the RemoteAction:

```dart
final action = RemoteAction<String, void>(
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
