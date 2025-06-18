import 'package:genkit/genkit.dart';

import '../test/schemas/my_schemas.dart';
import '../test/schemas/stream_schemas.dart';

void main() async {
  final baseUrl = 'http://localhost:3400';

  // --- 1. String to String flow ---
  final echoStringFlow = defineRemoteAction(
    url: '$baseUrl/echoString',
    fromResponse: (json) => json as String,
  );
  final response1 = await echoStringFlow(
    input: 'Hello Genkit client for Dart!',
  );
  print('Response: $response1');

  // --- 2. Object to Object flow ---
  final processObjectFlow = defineRemoteAction(
    url: '$baseUrl/processObject',
    fromResponse: (json) => MyOutput.fromJson(json),
  );
  final response2 = await processObjectFlow(
    input: MyInput(message: 'Hello Genkit!', count: 20),
  );
  print('Response: ${response2.reply}');

  // --- 3. Object to Object stream flow ---
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
  print('Final Response: ${finalResult.text}');
}
