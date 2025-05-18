import 'dart:convert';
import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'schemas/my_schemas.dart';
import 'schemas/stream_schemas.dart';
@GenerateMocks([http.Client])
import 'client_test.mocks.dart';

void main() {
  late MockClient mockClient;
  late GenkitClient client;

  setUp(() {
    mockClient = MockClient();
    client = GenkitClient(
      baseUrl: 'http://localhost:3400',
      httpClient: mockClient,
    );
  });

  group('GenkitClient.runFlow (String to String)', () {
    test('should return a string output for a string input', () async {
      // Assumed Genkit Flow Definition for flows/echoString (TypeScript)
      //
      // import { defineFlow, run } from '@genkit-ai/flow';
      // import * as z from 'zod';
      //
      // export const echoStringFlow = defineFlow(
      //   {
      //     name: 'echoString',
      //     inputSchema: z.string(),
      //     outputSchema: z.string(),
      //   },
      //   async (prompt: string) => {
      //     // In a real scenario, this might involve an AI call or other processing.
      //     // For this test, it simply prepends "Genkit says: ".
      //     const reply = `Genkit says: ${prompt}`;
      //     console.log(`echoStringFlow: input="${prompt}", output="${reply}"`);
      //     return reply;
      //   }
      // );

      final inputString = 'Hello Genkit';
      final expectedOutputString = 'Genkit says: Hello Genkit';

      when(
        mockClient.post(
          Uri.parse('http://localhost:3400/echoString'),
          headers: anyNamed('headers'),
          body: jsonEncode({'data': inputString}),
        ),
      ).thenAnswer((invocation) async {
        return http.Response(jsonEncode({'result': expectedOutputString}), 200);
      });

      final response = await client.runFlow<String, String>(
        flowUrlOrPath: '/echoString',
        input: inputString,
      );

      expect(response.runtimeType.toString(), 'String');
      expect(response, expectedOutputString);
    });
  });

  group('GenkitClient.runFlow (Object to Object)', () {
    test('should return a MyOutput object for a MyInput object', () async {
      // Assumed Genkit Flow Definition for flows/processObject (TypeScript)
      //
      // import { defineFlow } from '@genkit-ai/flow';
      // import * as z from 'zod';
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
      // export const processObjectFlow = defineFlow(
      //   {
      //     name: 'processObject',
      //     inputSchema: myInputSchema,
      //     outputSchema: myOutputSchema,
      //   },
      //   async (input) => {
      //     return {
      //       reply: `Processed: ${input.message}`,
      //       newCount: input.count + 1,
      //     };
      //   }
      // );

      final inputObject = MyInput(message: 'Process this', count: 10);
      final expectedOutputObject = MyOutput(
        reply: 'Processed: Process this',
        newCount: 11,
      );

      // mock
      when(
        mockClient.post(
          Uri.parse('http://localhost:3400/processObject'),
          headers: anyNamed('headers'),
          // The GenkitClient will wrap objectConverter.toRequestData(inputObject) with {'data': ...}
          body: jsonEncode({'data': inputObject.toJson()}),
        ),
      ).thenAnswer((invocation) async {
        return http.Response(
          jsonEncode({'result': expectedOutputObject.toJson()}),
          200,
        );
      });

      final actualOutput = await client.runFlow(
        flowUrlOrPath: '/processObject',
        input: inputObject,
        converter: GenkitConverter<MyInput, MyOutput, void>(
          toRequestData: (inputObj) => inputObj.toJson(),
          fromResponseData: (outputJson) => MyOutput.fromJson(outputJson),
        ),
      );

      expect(actualOutput.reply, expectedOutputObject.reply);
      expect(actualOutput.newCount, expectedOutputObject.newCount);

      verify(
        mockClient.post(
          Uri.parse('http://localhost:3400/processObject'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'data': inputObject.toJson()}),
        ),
      ).called(1);
    });
  });

  group('GenkitClient.streamFlow (String to String stream)', () {
    test('should stream string chunks and return a final string response', () async {
      // Assumed Genkit Flow Definition for flows/streamStrings (TypeScript)
      // This flow takes a string, uses ai.generateStream() for content,
      // and sends chunks via streamingCallback as { chunk: string }.
      // The final response is a string.
      //
      // import { defineFlow, ai } from '@genkit-ai/flow'; // Assuming ai is imported or available
      // import * as z from 'zod';
      // import vertexAI from '@genkit-ai/vertexai'; // Or any other model provider
      //
      // export const streamStringsFlow = ai.defineFlow(
      //   {
      //     name: 'streamStrings',
      //     inputSchema: z.string(),
      //     outputSchema: z.string(), // Schema for the final response
      //   },
      //   async (promptInput, streamingCallback) => {
      //     if (!streamingCallback) {
      //       throw new Error(`Streaming callback not provided.`);
      //     }
      //     // const { stream, response } = ai.generateStream({ /* ... model and prompt ... */ });
      //     // for await (const chunk of stream) {
      //     //   if (chunk.text) {
      //     //     streamingCallback({ chunk: chunk.text }); // Matches Dart test expectation
      //     //   }
      //     // }
      //     // const finalResponse = await response;
      //     // return finalResponse.text();
      //     /* ... server logic using ai.generateStream and streamingCallback ... */
      //     // Example direct streaming for test alignment:
      //     streamingCallback({ chunk: 'First chunk' });
      //     streamingCallback({ chunk: 'Second chunk' });
      //     streamingCallback({ chunk: 'Third chunk' });
      //     return 'Stream finished successfully'; // This is the final result
      //   }
      // );

      final inputString = 'Stream me';
      final expectedChunks = ['First chunk', 'Second chunk', 'Third chunk'];
      final expectedFinalResponse = 'Stream finished successfully';

      final streamConverter = GenkitConverter<String, String, String>(
        toRequestData: (input) => input, // Payload is just the string
        fromResponseData: (json) {
          // This json will be the content of what flow sends in "result" field
          // If flow sends data: {"result": {"value": "final_string"}}
          // then _streamFlowInternal will pass {"value": "final_string"} to this converter.
          if (json.containsKey('value') && json['value'] is String) {
            return json['value'] as String;
          }
          throw FormatException(
            'Unexpected final response format for stream: ${jsonEncode(json)}',
          );
        },
        fromStreamChunkData: (json) => json['chunk'] as String,
      );

      // --- Mocking http.Client.send for streaming ---
      final sseStreamController = StreamController<List<int>>();
      final requestCompleter = Completer<http.BaseRequest>();

      when(mockClient.send(any)).thenAnswer((Invocation invocation) {
        final request =
            invocation.positionalArguments.first as http.BaseRequest;
        if (!requestCompleter.isCompleted) {
          requestCompleter.complete(request);
        }
        // Return a StreamedResponse
        return Future.value(
          http.StreamedResponse(
            sseStreamController.stream,
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        );
      });

      // Act
      final (:stream, :response) = client.streamFlow<String, String, String>(
        flowUrlOrPath: 'streamStrings', // Example path
        input: inputString,
        converter: streamConverter,
      );

      // Assert
      final List<String> receivedChunks = [];
      // Don't start sending SSE data until the stream is listened to.
      final streamSubscription = stream.listen(receivedChunks.add);

      List<int> sseChunk(String chunk) {
        // Based on fromStreamChunkData, we expect the converter to receive {"chunk": chunk_string}
        // And _streamFlowInternal passes the content of "message" to the converter.
        // So the flow should send data: {"message": {"chunk": "actual_chunk_value"}}
        return utf8.encode(
          'data: ${jsonEncode({
            "message": {"chunk": chunk},
          })}\n\n',
        );
      }

      List<int> sseFinalResponse(String resultStr) {
        // _streamFlowInternal expects data: {"result": {...map...}}
        // And it passes the content of that map to the fromResponseData converter.
        // So, if converter expects {"value": resultStr}, flow sends data: {"result": {"value": resultStr}}
        return utf8.encode(
          'data: ${jsonEncode({
            "result": {"value": resultStr},
          })}\n\n',
        );
      }

      for (final chunk in expectedChunks) {
        sseStreamController.add(sseChunk(chunk));
        await Future.delayed(Duration.zero); // Allow event loop to process
      }
      sseStreamController.add(sseFinalResponse(expectedFinalResponse));
      await sseStreamController.close();

      await streamSubscription
          .asFuture(); // Wait for stream to complete processing all data

      expect(receivedChunks, expectedChunks);

      final String actualFinalResponse = await response;
      expect(actualFinalResponse, expectedFinalResponse);

      // Verify mockClient.send call
      final capturedRequest = await requestCompleter.future;
      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url.toString(),
        'http://localhost:3400/streamStrings',
      );
      expect(capturedRequest.headers['accept'], 'text/event-stream');
      // Body check for streamFlow
      final requestBodyBytes =
          await (capturedRequest as http.Request).finalize().toBytes();
      expect(jsonDecode(utf8.decode(requestBodyBytes)), {'data': inputString});
    });
  });

  group('GenkitClient.streamFlow (Object to Object stream)', () {
    test(
      'should stream object chunks and return a final object response for object input',
      () async {
        // Assumed Genkit Flow Definition for flows/streamObjects (TypeScript)
        // This flow takes a StreamInput-like object, uses ai.generateStream(),
        // and sends chunks via streamingCallback as StreamOutput-like objects.
        // The final response is a StreamOutput-like object.
        //
        // import { defineFlow, ai } from '@genkit-ai/flow';
        // import * as z from 'zod';
        // import vertexAI from '@genkit-ai/vertexai'; // Or any other model provider
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
        //     name: 'streamObjects',
        //     inputSchema: streamInputSchema,
        //     outputSchema: streamOutputSchema, // Final result type
        //   },
        //   async (input: z.infer<typeof streamInputSchema>, streamingCallback) => {
        //     if (!streamingCallback) {
        //       throw new Error(`Streaming callback not provided.`);
        //     }
        //     // const { stream, response } = ai.generateStream({ /* ... model and prompt ... */ });
        //     // let accumulatedText = '';
        //     // for await (const chunk of stream) {
        //     //   if (chunk.text) {
        //     //     accumulatedText += chunk.text;
        //     //     // Send StreamOutput-like object, matching Dart test expectations
        //     //     streamingCallback({ text: chunk.text, summary: 'intermediate' });
        //     //   }
        //     // }
        //     // const finalModelResponse = await response;
        //     // return { text: accumulatedText, summary: 'final summary' };
        //     /* ... server logic using ai.generateStream and streamingCallback ... */
        //     // Example direct streaming for test alignment:
        //     streamingCallback({ text: 'Response to: ', summary: '' });
        //     streamingCallback({ text: 'Tell', summary: '' });
        //     streamingCallback({ text: 'me', summary: '' });
        //     streamingCallback({ text: 'a', summary: '' });
        //     streamingCallback({ text: 'story', summary: '' });
        //     return { text: 'Response to: Tell me a story', summary: 'Summary of 5 words.' };
        //   }
        // );

        final inputStreamInput = StreamInput(prompt: 'Tell me a story');
        final expectedChunks = [
          StreamOutput(text: 'Response to: ', summary: ''),
          StreamOutput(text: 'Tell', summary: ''),
          StreamOutput(text: 'me', summary: ''),
          StreamOutput(text: 'a', summary: ''),
          StreamOutput(text: 'story', summary: ''),
        ];
        final expectedFinalResponse = StreamOutput(
          text: 'Response to: Tell me a story',
          summary: 'Summary of 5 words.',
        );

        // --- Mocking http.Client.send for streaming ---
        final sseStreamController = StreamController<List<int>>();
        final requestCompleter = Completer<http.BaseRequest>();

        when(mockClient.send(any)).thenAnswer((Invocation invocation) {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          if (!requestCompleter.isCompleted) {
            requestCompleter.complete(request);
          }
          return Future.value(
            http.StreamedResponse(
              sseStreamController.stream,
              200,
              headers: {'content-type': 'text/event-stream'},
            ),
          );
        });

        // Act
        final (:stream, :response) = client.streamFlow(
          flowUrlOrPath: 'streamObjects',
          input: inputStreamInput,
          converter: GenkitConverter<StreamInput, StreamOutput, String>(
            toRequestData: (input) => input.toJson(),
            fromResponseData: (output) => StreamOutput.fromJson(output),
            fromStreamChunkData: (chunk) => StreamOutput.fromJson(chunk).text,
          ),
        );

        // Assert
        final List<String> receivedChunks = [];
        final streamSubscription = stream.listen(receivedChunks.add);

        // Helper to create SSE data lines for object chunks
        List<int> sseObjectChunk(StreamOutput chunk) {
          return utf8.encode('data: ${jsonEncode({"message": chunk})}\n\n');
        }

        // Helper to create SSE data line for final object response
        List<int> sseFinalObjectResponse(StreamOutput finalOutput) {
          return utf8.encode(
            'data: ${jsonEncode({"result": finalOutput.toJson()})}\n\n',
          );
        }

        for (final chunk in expectedChunks) {
          sseStreamController.add(sseObjectChunk(chunk));
          await Future.delayed(Duration.zero);
        }
        sseStreamController.add(sseFinalObjectResponse(expectedFinalResponse));
        await sseStreamController.close();

        await streamSubscription.asFuture().catchError(
          (e) => print('Stream error: $e'),
        );

        for (int i = 0; i < receivedChunks.length; i++) {
          expect(receivedChunks[i], expectedChunks[i].text);
        }

        final actualFinalResponse = await response;
        expect(actualFinalResponse.text, expectedFinalResponse.text);
        expect(actualFinalResponse.summary, expectedFinalResponse.summary);

        // Verify mockClient.send call
        final capturedRequest = await requestCompleter.future;
        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.toString(),
          'http://localhost:3400/streamObjects',
        );
        expect(capturedRequest.headers['accept'], 'text/event-stream');
        final requestBodyBytes =
            await (capturedRequest as http.Request).finalize().toBytes();
        expect(jsonDecode(utf8.decode(requestBodyBytes)), {
          'data': inputStreamInput.toJson(),
        });
      },
    );
  });

  group('GenkitClient.streamFlow (dynamic stream, no converter)', () {
    test(
      'should stream dynamic (Map) chunks and return a dynamic (String) final response for string-like stream',
      () async {
        // Assumed Genkit Flow Definition for flows/streamDynamicStrings (TypeScript)
        // This flow takes a string, could use ai.generateStream(), and sends chunks
        // via streamingCallback as map-like objects (e.g., { "chunk": "..." }).
        // The final response is a string. Client handles everything as dynamic.
        //
        // import { defineFlow, ai } from '@genkit-ai/flow';
        // import * as z from 'zod';
        // import vertexAI from '@genkit-ai/vertexai';
        //
        // export const streamDynamicStrings = ai.defineFlow(
        //   {
        //     name: 'streamDynamicStrings',
        //     inputSchema: z.string(),
        //     outputSchema: z.string(), // Final result type
        //   },
        //   async (input: string, streamingCallback) => {
        //     if (!streamingCallback) throw new Error('Streaming not supported');
        //     /* ... server logic using ai.generateStream and streamingCallback ... */
        //     // Example direct streaming for test alignment:
        //     streamingCallback({ chunk: 'Dynamic chunk 1' });
        //     streamingCallback({ chunk: 'Dynamic chunk 2' });
        //     return 'Dynamic stream finished';
        //   }
        // );

        final inputString = 'Stream me dynamically';
        final expectedRawChunks = [
          {'chunk': 'Dynamic chunk 1'},
          {'chunk': 'Dynamic chunk 2'},
        ];
        final expectedFinalResponse = 'Dynamic stream finished';

        final sseStreamController = StreamController<List<int>>();
        final requestCompleter = Completer<http.BaseRequest>();

        when(mockClient.send(any)).thenAnswer((Invocation invocation) {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          if (!requestCompleter.isCompleted) {
            requestCompleter.complete(request);
          }
          return Future.value(
            http.StreamedResponse(
              sseStreamController.stream,
              200,
              headers: {'content-type': 'text/event-stream'},
            ),
          );
        });

        final (:stream, :response) = client.streamFlow(
          flowUrlOrPath: 'streamDynamicStrings', // Assumed new path for clarity
          input: inputString, // Input is a string
          // No converter provided, expecting dynamic types
        );

        final List<dynamic> receivedChunks = [];
        final streamSubscription = stream.listen(receivedChunks.add);

        // SSE for dynamic chunks (Map<String, dynamic>)
        List<int> sseDynamicChunk(Map<String, dynamic> chunkData) {
          return utf8.encode('data: ${jsonEncode({"message": chunkData})}\n\n');
        }

        // SSE for dynamic final response (String)
        List<int> sseDynamicFinalResponse(String resultStr) {
          return utf8.encode('data: ${jsonEncode({"result": resultStr})}\n\n');
        }

        for (final chunk in expectedRawChunks) {
          sseStreamController.add(sseDynamicChunk(chunk));
          await Future.delayed(Duration.zero);
        }
        sseStreamController.add(sseDynamicFinalResponse(expectedFinalResponse));
        await sseStreamController.close();

        await streamSubscription.asFuture();

        expect(receivedChunks, equals(expectedRawChunks));
        for (int i = 0; i < receivedChunks.length; i++) {
          expect(receivedChunks[i], isA<Map<String, dynamic>>());
          expect(receivedChunks[i]['chunk'], expectedRawChunks[i]['chunk']);
        }

        final dynamic actualFinalResponse = await response;
        expect(actualFinalResponse, isA<String>());
        expect(actualFinalResponse, expectedFinalResponse);

        final capturedRequest = await requestCompleter.future;
        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.toString(),
          'http://localhost:3400/streamDynamicStrings',
        );
        final requestBodyBytes =
            await (capturedRequest as http.Request).finalize().toBytes();
        expect(jsonDecode(utf8.decode(requestBodyBytes)), {
          'data': inputString,
        });
      },
    );

    test(
      'should stream dynamic (Map) chunks and return a dynamic (Map) final response for object-like stream',
      () async {
        // Assumed Genkit Flow Definition for flows/streamDynamicObjects (TypeScript)
        // This flow takes a map-like input, could use ai.generateStream(), and sends chunks
        // via streamingCallback as map-like objects. The final response is also a map-like object.
        // Client handles everything as dynamic.
        //
        // import { defineFlow, ai } from '@genkit-ai/flow';
        // import * as z from 'zod';
        // import vertexAI from '@genkit-ai/vertexai';
        //
        // const dynamicObjectSchema = z.object({
        //   text: z.string(),
        //   source: z.string().optional(),
        // });
        // const finalDynamicObjectSchema = z.object({
        //   fullText: z.string(),
        //   summary: z.string(),
        // });
        //
        // export const streamDynamicObjects = ai.defineFlow(
        //   {
        //     name: 'streamDynamicObjects',
        //     inputSchema: z.object({ prompt: z.string() }), // Or z.any()
        //     outputSchema: finalDynamicObjectSchema, // Final result type
        //   },
        //   async (input: { prompt: string }, streamingCallback) => {
        //     if (!streamingCallback) throw new Error('Streaming not supported');
        //     /* ... server logic using ai.generateStream and streamingCallback ... */
        //     // Example direct streaming for test alignment:
        //     streamingCallback({ text: 'Dynamic obj chunk 1', source: 'A' });
        //     streamingCallback({ text: 'Dynamic obj chunk 2', source: 'B' });
        //     return {
        //       fullText: 'Dynamic obj chunk 1Dynamic obj chunk 2',
        //       summary: 'Summary of dynamic obj stream'
        //     };
        //   }
        // );

        final Map<String, dynamic> inputObject = {
          'prompt': 'Tell me a story dynamically',
        };
        final expectedRawChunks = [
          {'text': 'Dynamic obj chunk 1', 'source': 'A'},
          {'text': 'Dynamic obj chunk 2', 'source': 'B'},
        ];
        final Map<String, dynamic> expectedFinalResponse = {
          'fullText': 'Dynamic obj chunk 1Dynamic obj chunk 2',
          'summary': 'Summary of dynamic obj stream',
        };

        final sseStreamController = StreamController<List<int>>();
        final requestCompleter = Completer<http.BaseRequest>();

        when(mockClient.send(any)).thenAnswer((Invocation invocation) {
          final request =
              invocation.positionalArguments.first as http.BaseRequest;
          if (!requestCompleter.isCompleted) {
            requestCompleter.complete(request);
          }
          return Future.value(
            http.StreamedResponse(
              sseStreamController.stream,
              200,
              headers: {'content-type': 'text/event-stream'},
            ),
          );
        });

        final (:stream, :response) = client.streamFlow(
          flowUrlOrPath: 'streamDynamicObjects', // Assumed new path
          input: inputObject, // Input is a Map<String, dynamic>
          // No converter provided
        );

        final List<dynamic> receivedChunks = [];
        final streamSubscription = stream.listen(receivedChunks.add);

        List<int> sseDynamicObjectChunk(Map<String, dynamic> chunkData) {
          return utf8.encode('data: ${jsonEncode({"message": chunkData})}\n\n');
        }

        List<int> sseDynamicObjectFinalResponse(
          Map<String, dynamic> resultData,
        ) {
          return utf8.encode('data: ${jsonEncode({"result": resultData})}\n\n');
        }

        for (final chunk in expectedRawChunks) {
          sseStreamController.add(sseDynamicObjectChunk(chunk));
          await Future.delayed(Duration.zero);
        }
        sseStreamController.add(
          sseDynamicObjectFinalResponse(expectedFinalResponse),
        );
        await sseStreamController.close();

        await streamSubscription.asFuture();

        expect(receivedChunks.length, expectedRawChunks.length);
        for (int i = 0; i < receivedChunks.length; i++) {
          expect(receivedChunks[i], isA<Map<String, dynamic>>());
          expect(receivedChunks[i], equals(expectedRawChunks[i]));
        }

        final dynamic actualFinalResponse = await response;
        expect(actualFinalResponse, isA<Map<String, dynamic>>());
        expect(actualFinalResponse, equals(expectedFinalResponse));

        final capturedRequest = await requestCompleter.future;
        expect(capturedRequest.method, 'POST');
        expect(
          capturedRequest.url.toString(),
          'http://localhost:3400/streamDynamicObjects',
        );
        final requestBodyBytes =
            await (capturedRequest as http.Request).finalize().toBytes();
        expect(jsonDecode(utf8.decode(requestBodyBytes)), {
          'data': inputObject,
        });
      },
    );
  });
}
