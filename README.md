# Dart client library for Genkit

This library provides a Dart client for interacting with Genkit flows, enabling type-safe communication for both unary and streaming operations.

## Getting Started

Initialize `GenkitClient`.

```dart
import 'package:genkit/genkit.dart';
// Define your data classes for inputs and outputs if needed.
// For example:
// class MyInput { /* ... */ Map<String, dynamic> toJson() => { /* ... */ }; }
// class MyOutput { factory MyOutput.fromJson(Map<String, dynamic> json) { /* ... */ } }
```

```dart
void main() async {
  final client = GenkitClient(
    baseUrl: 'http://localhost:3400', // Your Genkit server base URL

    // Optional: Provide a custom httpClient for testing or specific configurations
    // httpClient: myCustomHttpClient,

    // Optional: Set default headers for all requests (e.g., for authorization)
    // defaultHeaders: {'Authorization': 'Bearer YOUR_TOKEN'},
  );

  client.dispose(); // Dispose the client when no longer needed
}
```

## `runFlow` - Calling Unary Flows

Use `runFlow` to call flows that take an input and return a single output.

### Example: String to String

If your flow takes a `String` and returns a `String`:

```dart
  // Assumes a flow named 'echoString' that takes a String and returns a String.
  try {
    final response = await client.runFlow<String, String>(
      flowUrlOrPath: '/echoString',
      input: 'Hello from Dart!',
    );
    print('Flow Response: $response');
  } catch (e) {
    print('Error calling runFlow: $e');
  }
```

### Example: Custom Object to Custom Object

If your flow handles custom objects, you'll need to provide a `GenkitConverter`.

```dart
  // Assuming MyInput and MyOutput classes are defined with toJson/fromJson
  final myInput = MyInput(message: 'Process this data', count: 10);

  try {
    final myOutput = await client.runFlow(
      flowUrlOrPath: '/processMyObject',
      input: myInput,
      converter: GenkitConverter<MyInput, MyOutput, void>(
        // Convert MyInput instance to a JSON-encodable Map
        toRequestData: (input) => input.toJson(),
        // Convert the JSON Map from the response back to a MyOutput instance
        fromResponseData: (json) => MyOutput.fromJson(json),
      ),
    );
    print('Flow Response (MyOutput): ${myOutput.reply}, ${myOutput.newCount}');
  } catch (e) {
    print('Error calling runFlow with objects: $e');
  }
```

## `streamFlow` - Calling Streaming Flows

Use `streamFlow` for flows that stream multiple chunks of data and then return a final response. It returns a record containing both the `stream` (an `Stream<S>`) and the `response` (a `Future<O>`).

### Example: String Input, Streaming String Chunks, String Final Response

```dart
  // Assumes a flow 'streamStory' that takes a String prompt,
  // streams String chunks, and returns a final String summary.
  try {
    final (:stream, :response) = client.streamFlow<String, String, String>(
      flowUrlOrPath: '/streamStory',
      input: 'Tell me a short story about a Dart developer.',
      converter: GenkitConverter<String, String, String>(
        toRequestData: (input) => input, // Input is already JSON-encodable
        fromResponseData: (data) => data as String, // Final response is a String
        // Convert the JSON Map from each stream chunk to a String.
        // Assumes server sends chunks like: {"message": {"chunk": "once upon a time..."}}
        // and _streamFlowInternal passes the content of "message" to this callback.
        fromStreamChunkData: (chunkData) {
          // Adjust access based on actual chunk structure from your flow
          return chunkData['chunk'] as String;
        }
      ),
    );

    print('Streaming chunks:');
    await for (final chunk in stream) {
      print('Chunk: $chunk');
    }

    final finalResult = await response;
    print('\nFinal Response from stream: $finalResult');
  } catch (e) {
    print('Error calling streamFlow: $e');
  }
```

### Example: Custom Object Input, Streaming Custom Object Chunks, Custom Object Final Response

```dart
  // Assuming MyStreamInput and MyStreamOutput classes are defined
  final myStreamInput = MyStreamInput(topic: 'Genkit Streaming');

  try {
    final (:stream, :response) = client.streamFlow(
      flowUrlOrPath: '/processMyStream',
      input: myStreamInput,
      converter: GenkitConverter<MyStreamInput, MyStreamOutput, String>(
        toRequestData: (input) => input.toJson(),
        fromResponseData: (json) => MyStreamOutput.fromJson(json),
        fromStreamChunkData: (json) => MyStreamChunk.fromJson(json).content,
      ),
    );

    print('Streaming object chunks:');
    await for (final content in stream) {
      print('Chunk (MyStreamChunk): ${content}');
    }

    final finalResult = await response;
    print('\nFinal Stream Response (MyStreamOutput): ${finalResult.summary}');
  } catch (e) {
    print('Error calling streamFlow with objects: $e');
  }

```

## `GenkitConverter<I, O, S>`

The `GenkitConverter` is crucial when dealing with custom Dart objects for your flow's input (`I`), output (`O`), or stream chunks (`S`). It requires three functions:

- `toRequestData: (I input) => dynamic`: Converts your Dart input object `I` into a JSON-encodable `dynamic` type (usually a `Map<String, dynamic>`, `String`, `int`, etc.). This payload is then wrapped in `{'data': payload}` by the client.
- `fromResponseData: (dynamic data) => O`: Converts the `dynamic` data payload from the flow's final response into your Dart output object `O`.
- `fromStreamChunkData: (dynamic json) => S` (Optional): Converts the `dynamic` JSON payload from each stream chunk into your Dart stream chunk object `S`. This is only required if `S` is not `void` and you are expecting typed stream chunks.

Make sure your custom classes have appropriate `toJson()` and `fromJson(Map<String, dynamic> json)` methods (or equivalent logic within the converter functions) for seamless serialization and deserialization.
