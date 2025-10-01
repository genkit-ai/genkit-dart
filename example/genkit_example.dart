import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

import '../test/schemas/my_schemas.dart';
import '../test/schemas/stream_schemas.dart';

const baseUrl = 'http://localhost:8080';

/*
  Before running these examples, make sure the sample server is running.
  In a separate terminal window run:

  cd example/server
  npm i
  npx genkit start -- npx tsx --watch index.ts
*/

// A simple flow that takes a string and returns a string.
Future<void> _runStringFlow() async {
  print('--- String to String flow ---');
  final echoStringFlow = defineRemoteAction(
    url: '$baseUrl/echoString',
    fromResponse: (json) => json as String,
  );
  final response = await echoStringFlow(input: 'Hello Genkit client for Dart!');
  print('Response: $response');
}

// Error handling when calling remote flows.
Future<void> _runThrowingFlow() async {
  print('\n--- Flow error handling ---');
  final throwy = defineRemoteAction(
    url: '$baseUrl/throwy',
    fromResponse: (json) => json as String,
  );
  try {
    await throwy(input: 'Hello Genkit client for Dart!');
  } on GenkitException catch (e) {
    if (e.underlyingException is http.ClientException) {
      print('Client error: ${e.underlyingException}');
      print('Make sure the server is running.');
    } else {
      print('Excepted flow error: ${e.details}');
    }
  }
}

// Error handling when calling remote flows.
Future<void> _runThrowingStreamingFlow() async {
  print('\n--- Streaming Flow error handling ---');
  final streamyThrowy = defineRemoteAction(
    url: '$baseUrl/streamyThrowy',
    fromResponse: (json) => json as String,
    fromStreamChunk: (json) => json,
  );
  try {
    final (:stream, :response) = streamyThrowy.stream(input: 5);

    await for (final chunk in stream) {
      print('Chunk: $chunk');
    }

  } on GenkitException catch (e) {
    if (e.underlyingException is http.ClientException) {
      print('Client error: ${e.underlyingException}');
      print('Make sure the server is running.');
    } else {
      print('Excepted flow error: ${e.details}');
    }
  } catch (e, st) {
    print('Caught error: $e $st');
  }
}

// A flow that takes an object and returns an object.
Future<void> _runObjectFlow() async {
  print('\n--- Object to Object flow ---');
  final processObjectFlow = defineRemoteAction(
    url: '$baseUrl/processObject',
    fromResponse: (json) => MyOutput.fromJson(json),
  );
  final response = await processObjectFlow(
    input: MyInput(message: 'Hello Genkit!', count: 20),
  );
  print('Response: ${response.reply}');
}

// A streaming flow.
Future<void> _runStreamingFlow() async {
  print('\n--- Stream generate call ---');
  final streamObjectsFlow = defineRemoteAction(
    url: '$baseUrl/streamObjects',
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
  print('Final Response: ${finalResult?.text}');
}

// --- Stream generate call ---
Future<void> _runStreamingGenerateFlow() async {
  print('\n--- Stream generate call ---');
  final generateFlow = defineRemoteAction(
    url: '$baseUrl/generate',
    fromResponse: (json) => GenerateResponse.fromJson(json),
    fromStreamChunk: (json) => GenerateResponseChunk.fromJson(json),
  );
  final (:stream, :response) = generateFlow.stream(
    input: [
      Message(
        role: Role.user,
        content: [TextPart(text: "hello")],
      ),
      Message(
        role: Role.model,
        content: [TextPart(text: "Hello, how can I help you?")],
      ),
      Message(
        role: Role.user,
        content: [TextPart(text: "Sing me a song.")],
      ),
    ],
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.text}');
  }
  print('\nStream finished.');
  final finalResult = await response;
  print('Final Response: ${finalResult?.text}');
}

// Manual client management for performance.
// Reusing a single client for multiple calls is more efficient.
Future<void> _runPerformanceExample() async {
  final client = http.Client();
  try {
    print('\n--- Manual Client Management for Performance ---');
    final echoAction = defineRemoteAction(
      url: '$baseUrl/echoString',
      httpClient: client,
      fromResponse: (json) => json as String,
    );

    final r1 = await echoAction(input: 'First call');
    print('First response: $r1');
    final r2 = await echoAction(input: 'Second call');
    print('Second response: $r2');
  } finally {
    print('\nClosing HTTP client.');
    client.close();
  }
}

void main() async {
  await _runStringFlow();
  await _runThrowingFlow();
  await _runThrowingStreamingFlow();
  await _runObjectFlow();
  await _runStreamingFlow();
  await _runStreamingGenerateFlow();
  await _runPerformanceExample();
}
