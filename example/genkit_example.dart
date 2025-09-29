import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

import '../test/schemas/my_schemas.dart';
import '../test/schemas/stream_schemas.dart';

const baseUrl = 'http://localhost:8080';

// Example 1: A simple flow that takes a string and returns a string.
Future<void> _runStringFlow(http.Client client) async {
  print('--- 1. String to String flow ---');
  final echoStringFlow = defineRemoteAction(
    url: '$baseUrl/echoString',
    httpClient: client,
    fromResponse: (json) => json as String,
  );
  final response = await echoStringFlow(
    input: 'Hello Genkit client for Dart!',
  );
  print('Response: $response');
}

// Example 2: A flow that takes an object and returns an object.
Future<void> _runObjectFlow(http.Client client) async {
  print('\n--- 2. Object to Object flow ---');
  final processObjectFlow = defineRemoteAction(
    url: '$baseUrl/processObject',
    httpClient: client,
    fromResponse: (json) => MyOutput.fromJson(json),
  );
  final response = await processObjectFlow(
    input: MyInput(message: 'Hello Genkit!', count: 20),
  );
  print('Response: ${response.reply}');
}

// Example 3: A streaming flow.
Future<void> _runStreamingFlow(http.Client client) async {
  print('\n--- 3. Stream generate call ---');
  final streamObjectsFlow = defineRemoteAction(
    url: '$baseUrl/streamObjects',
    httpClient: client,
    fromResponse: (json) => StreamOutput.fromJson(json),
    fromStreamChunk: (json) => StreamOutput.fromJson(json),
  );
  final (:stream, :response) = streamObjectsFlow.stream(
    input: StreamInput(prompt: 'What is Genkit?'),
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.text}');
  }
  print('\nStream finished.');
  final finalResult = await response;
  print('Final Response: ${finalResult.text}');
}

// --- 4. Stream generate call ---
Future<void> _runStreamingGenerateFlow(http.Client client) async {
  print('\n--- 4. Stream generate call ---');
  final generateFlow = defineRemoteAction(
    url: '$baseUrl/generate',
    fromResponse: (json) => GenerateResponse.fromJson(json),
    fromStreamChunk: (json) => GenerateResponseChunk.fromJson(json),
  );
  final (:stream, :response) = generateFlow.stream(
    input: Message(role: Role.user, content: [TextPart(text: "hello")]),
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.text}');
  }
  print('\nStream finished.');
  final finalResult = await response;
  print('Final Response: ${finalResult.text}');
}

// Example 4: Manual client management for performance.
// Reusing a single client for multiple calls is more efficient.
Future<void> _runPerformanceExample(http.Client client) async {
  print('\n--- 5. Manual Client Management for Performance ---');
  final echoAction = defineRemoteAction(
    url: '$baseUrl/echoString',
    httpClient: client,
    fromResponse: (json) => json as String,
  );

  final r1 = await echoAction(input: 'First call');
  print('First response: $r1');
  final r2 = await echoAction(input: 'Second call');
  print('Second response: $r2');
}

void main() async {
  // It's recommended to create a single client and reuse it for all requests.
  final client = http.Client();
  try {
    await _runStringFlow(client);
    await _runObjectFlow(client);
    await _runStreamingFlow(client);
    await _runStreamingGenerateFlow(client);
    await _runPerformanceExample(client);
  } finally {
    // Ensure the client is closed when all operations are complete.
    print('\nClosing HTTP client.');
    client.close();
  }
}
