// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:genkit/client.dart';
import 'package:genkit/schema.dart';
import 'package:http/http.dart' as http;

import 'types.dart';

const baseUrl = 'http://localhost:8080';

// A simple flow that takes a string and returns a string.
void printServerInstructions() {
  print(
    '-------------------------------------------------------------------\n'
    '| Before running these examples, make sure the server is running. |\n'
    '| The server is using a fake model, so does not require API keys. |\n'
    '| In a separate terminal run:                                     |\n'
    '|                                                                 |\n'
    '| \$ cd packages/testapps                                          |\n'
    '| \$ dart run example/server_dart.dart                             |\n'
    '-------------------------------------------------------------------\n',
  );
}

Future<void> _runStringFlow() async {
  print('--- String to String flow ---');
  final echoStringFlow = remoteAction(
    name: 'echoString',
    url: '$baseUrl/echoString',
    inputType: StringType,
    outputType: StringType,
  );
  final response = await echoStringFlow('Hello Genkit client for Dart!');
  print('Response: $response');
}

// Error handling when calling remote flows.
Future<void> _runThrowingFlow() async {
  print('\n--- Flow error handling ---');
  final throwy = remoteAction(
    name: 'throwy',
    url: '$baseUrl/throwy',
    inputType: StringType,
    outputType: StringType,
  );
  try {
    await throwy('Hello Genkit client for Dart!');
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
  final streamyThrowy = remoteAction(
    name: 'streamyThrowy',
    url: '$baseUrl/streamyThrowy',
    inputType: IntType,
    outputType: StringType,
    streamType: StreamyThrowyChunkType,
  );
  try {
    final stream = streamyThrowy.stream(5);
    await for (final chunk in stream) {
      print('Chunk: ${chunk.count}');
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
  final processObjectFlow = remoteAction(
    name: 'processObject',
    url: '$baseUrl/processObject',
    inputType: ProcessObjectInputType,
    outputType: ProcessObjectOutputType,
  );
  final response = await processObjectFlow(
    ProcessObjectInput.from(message: 'Hello Genkit!', count: 20),
  );
  print('Response: ${response.reply}');
}

// A streaming flow.
Future<void> _runStreamingFlow() async {
  print('\n--- Stream Objects ---');
  final streamObjectsFlow = remoteAction(
    name: 'streamObjects',
    url: '$baseUrl/streamObjects',
    inputType: StreamObjectsInputType,
    outputType: StreamObjectsOutputType,
    streamType: StreamObjectsOutputType,
  );
  final stream = streamObjectsFlow.stream(
    StreamObjectsInput.from(prompt: 'What is Genkit?'),
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.text}');
  }
  print('\nStream finished.');
  final finalResult = stream.result;
  print('Final Response: ${finalResult.text}');
}

// --- Stream generate call ---
Future<void> _runStreamingGenerateFlow() async {
  print('\n--- Stream generate call ---');
  final generateFlow = remoteAction(
    name: 'generate',
    url: '$baseUrl/generate',
    inputType: ModelRequestType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
  );
  final stream = generateFlow.stream(
    ModelRequest.from(
      messages: [
        Message.from(
          role: Role.user,
          content: [TextPart.from(text: "hello")],
        ),
        Message.from(
          role: Role.model,
          content: [TextPart.from(text: "Hello, how can I help you?")],
        ),
        Message.from(
          role: Role.user,
          content: [TextPart.from(text: "Sing me a song.")],
        ),
      ],
    ),
  );

  print('Streaming chunks:');
  await for (final chunk in stream) {
    print('Chunk: ${chunk.text}');
  }
  print('\nStream finished.');
  final finalResult = stream.result;
  print('Final Response: ${finalResult.text}');
}

// Manual client management for performance.
// Reusing a single client for multiple calls is more efficient.
Future<void> _runPerformanceExample() async {
  final client = http.Client();
  try {
    print('\n--- Manual Client Management for Performance ---');
    final echoAction = remoteAction(
      name: 'echoStringPerf', // Different name just to be safe/clear
      url: '$baseUrl/echoString',
      httpClient: client,
      inputType: StringType,
      outputType: StringType,
    );

    final r1 = await echoAction('First call');
    print('First response: $r1');
    final r2 = await echoAction('Second call');
    print('Second response: $r2');
  } finally {
    print('\nClosing HTTP client.');
    client.close();
  }
}

void main() async {
  try {
    await _runStringFlow();
    await _runObjectFlow();
    await _runStreamingFlow();
    await _runStreamingGenerateFlow();
    await _runPerformanceExample();
    await _runThrowingFlow();
    await _runThrowingStreamingFlow();
  } catch (e, st) {
    print('$e\n$st\n');
    printServerInstructions();
  }
}
