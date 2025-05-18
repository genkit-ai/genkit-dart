import 'package:genkit/genkit.dart';

import '../test/schemas/my_schemas.dart';
import '../test/schemas/stream_schemas.dart';

void main() async {
  // Initialize Genkit client.
  final client = GenkitClient(
    baseUrl: 'http://localhost:3400',

    // Optional: Set default HTTP headers for all requests made by this client.
    // This is useful for scenarios like passing an authentication token (e.g., Bearer token)
    // defaultHeaders: {'Authorization': 'Bearer YOUR_TOKEN'},

    // Optional: Provide a custom HTTP client.
    // This is particularly useful for testing purposes, allowing you to mock HTTP requests.
    // httpClient: MockClient(),
  );

  // --- 1. Calling echoStringFlow (String to String) ---
  // This flow is defined on the Genkit server as:
  //
  // export const echoStringFlow = ai.defineFlow(
  //   {
  //     name: `echo-string`,
  //     inputSchema: z.string(),
  //     outputSchema: z.string(),
  //   },
  //   async (prompt) => `Genkit says: ${prompt}`
  // );
  print('--- 1. Calling echoStringFlow (String to String) ---');
  try {
    final echoResponse = await client.runFlow<String, String>(
      flowUrlOrPath: '/echoString',
      input: 'Hello Dart!',
    );
    print('Response: $echoResponse');
  } catch (e) {
    print('Error: $e');
  }
  print('----------------------------------------------------\n');

  // --- 2. Calling processObjectFlow (Object to Object) ---
  // This flow is defined on the Genkit server as:
  //
  // const myInputSchema = z.object({
  //   message: z.string(),
  //   count: z.number(),
  // });
  // const myOutputSchema = z.object({
  //   reply: z.string(),
  //   newCount: z.number(),
  // });
  //
  // export const processObjectFlow = ai.defineFlow(
  //   {
  //     name: `process-object`,
  //     inputSchema: myInputSchema,
  //     outputSchema: myOutputSchema,
  //   },
  //   async (input) => ({
  //     reply: `Processed: ${input.message}`,
  //     newCount: input.count + 1,
  //   })
  // );
  print('--- 2. Calling processObjectFlow (Object to Object) ---');
  try {
    final myInput = MyInput(message: 'Dart calling', count: 5);
    final processObjResponse = await client.runFlow(
      flowUrlOrPath: '/processObject',
      input: myInput,
      converter: GenkitConverter<MyInput, MyOutput, void>(
        toRequestData: (input) => input.toJson(),
        fromResponseData: (json) => MyOutput.fromJson(json),
      ),
    );
    print('Response: $processObjResponse');
  } catch (e) {
    print('Error: $e');
  }
  print('-----------------------------------------------------\n');

  // --- 3. Calling streamStringsFlow (String to String stream) ---
  // This flow is defined on the Genkit server as:
  //
  // export const streamStringsFlow = ai.defineFlow(
  //   {
  //     name: `stream-strings`,
  //     inputSchema: z.string(),
  //     outputSchema: z.string(),
  //   },
  //   async (promptInput, streamingCallback) => { /* ... server logic ... */ }
  // );
  print('--- 3. Calling streamStringsFlow (String to String stream) ---');
  try {
    final (:stream, :response) = client.streamFlow(
      flowUrlOrPath: '/streamStrings',
      input: 'Tell me a story about a Dart developer.',
      converter: GenkitConverter<String, String, String>(
        toRequestData: (input) => input,
        fromResponseData: (data) => data as String,
        fromStreamChunkData: (chunkData) => chunkData['chunk'] as String,
      ),
    );

    print('Streaming chunks:');
    await for (final chunk in stream) {
      print('Chunk: $chunk');
    }
    final finalStringResult = await response;
    print('Final Response: $finalStringResult');
  } catch (e) {
    print('Error: $e');
  }
  print('---------------------------------------------------------\n');

  // --- 4. Calling streamObjectsFlow (Object to Object stream) ---
  // This flow is defined on the Genkit server as:
  //
  // const streamInputSchema = z.object({
  //   prompt: z.string(),
  // });
  // const streamOutputSchema = z.object({
  //   text: z.string(),
  //   summary: z.string(),
  // });
  //
  // export const streamObjectsFlow = ai.defineFlow(
  //   {
  //     name: `stream-objects`,
  //     inputSchema: streamInputSchema,
  //     outputSchema: streamOutputSchema,
  //   },
  //   async (input, streamingCallback) => { /* ... server logic ... */ }
  // );
  print('--- 4. Calling streamObjectsFlow (Object to Object stream) ---');
  try {
    final streamObjInput = StreamInput(
      prompt: 'Explain Genkit streaming in Dart.',
    );
    final (:stream, :response) = client.streamFlow(
      flowUrlOrPath: '/streamObjects',
      input: streamObjInput,
      converter: GenkitConverter<StreamInput, StreamOutput, String>(
        toRequestData: (input) => input.toJson(),
        fromResponseData: (json) => StreamOutput.fromJson(json),
        fromStreamChunkData: (json) => StreamOutput.fromJson(json).text,
      ),
    );

    print('Streaming object chunks:');
    await for (final chunk in stream) {
      print('Chunk: $chunk');
    }
    final finalObjectResult = await response;
    print('Final Object Response: ${finalObjectResult.text}');
  } catch (e) {
    print('Error: $e');
  }
  print('----------------------------------------------------------\n');

  client.dispose();
}
