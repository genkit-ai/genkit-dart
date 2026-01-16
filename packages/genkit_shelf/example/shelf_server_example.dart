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
import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:genkit_shelf/genkit_shelf.dart';

part 'shelf_server_example.schema.g.dart';

@GenkitSchema()
abstract class HelloInputSchema {
  String get name;
}

@GenkitSchema()
abstract class HelloOutputSchema {
  String get greeting;
}

@GenkitSchema()
abstract class CountChunkSchema {
  int get count;
}

// This example demonstrates how to expose Genkit flows as HTTP endpoints using the Shelf plugin.
//
// To run this example:
// 1. dart run example/shelf_server_example.dart
//
// To test the endpoints (using curl):
//
// 1. Unary flow (POST request):
// curl -X POST http://localhost:3400/hello -H "Content-Type: application/json" -d '{"data": "World"}'
//
// 2. Streaming flow (POST request with stream=true or Accept: text/event-stream):
// curl -X POST http://localhost:3400/count?stream=true -H "Content-Type: application/json" -d '{"data": 5}'
//
// 3. Auth flow (requires Bearer token):
// curl -X POST http://localhost:3400/secure -H "Content-Type: application/json" -H "Authorization: Bearer secret" -d '{"data": "User"}'
//
// 4. Client flow (calls other flows using the client library):
// curl -X POST http://localhost:3400/client -H "Content-Type: application/json" -d '{"data": "start"}'

void main() async {
  configureCollectorExporter();

  final ai = Genkit();

  // Define remote actions for the client flow
  final helloAction = defineRemoteAction(
    url: 'http://localhost:3400/hello',
    outputType: HelloOutputType,
  );

  final countAction = defineRemoteAction(
    url: 'http://localhost:3400/count',
    streamType: CountChunkType,
    outputType: StringType,
  );

  // 1. Define a simple unary flow
  final helloFlow = ai.defineFlow(
    name: 'hello',
    fn: (HelloInput input, _) async {
      return HelloOutput.from(greeting: 'Hello, ${input.name}!');
    },
    inputType: HelloInputType,
    outputType: HelloOutputType,
  );

  // 2. Define a streaming flow
  final countFlow = ai.defineFlow(
    name: 'count',
    fn: (int count, ctx) async {
      for (var i = 1; i <= count; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        ctx.sendChunk(CountChunk.from(count: i));
      }
      return 'Done counting to $count';
    },
    inputType: IntType,
    outputType: StringType,
    streamType: CountChunkType,
  );

  // 3. Define a flow with authentication (context)
  final secureFlow = ai.defineFlow(
    name: 'secure',
    fn: (String input, ctx) async {
      final user = ctx.context?['user'];
      if (user == null) {
        throw GenkitException('Unauthorized access', statusCode: 401);
      }
      return 'Secure data for $user: $input';
    },
    inputType: StringType,
    outputType: StringType,
  );

  // 4. Define a client flow that acts as a client to call other flows
  final clientFlow = ai.defineFlow(
    name: 'client',
    fn: (String input, _) async {
      final results = <String>[];
      results.add('Triggered client flow with input: $input');

      // Call 'hello' flow
      try {
        final helloRes = await helloAction(
          input: HelloInput.from(name: 'Client'),
        );
        results.add('Hello Flow: ${helloRes.greeting}');
      } catch (e) {
        results.add('Hello Flow Error: $e');
      }

      // Call 'count' flow (streaming)
      try {
        final stream = countAction.stream(input: 3);
        final chunks = <CountChunk>[];
        await for (final chunk in stream) {
          chunks.add(chunk);
        }
        final countRes = await stream.onResult;
        final chunkValues = chunks.map((c) => c.count).toList();
        results.add('Count Flow: Result="$countRes", Chunks=$chunkValues');
      } catch (e) {
        results.add('Count Flow Error: $e');
      }

      return results.join('\n');
    },
    inputType: StringType,
    outputType: StringType,
  );

  // 5. Start the flow server
  await startFlowServer(
    flows: [
      helloFlow,
      countFlow,
      // Wrap the secure flow with a context provider to handle auth
      FlowWithContextProvider(
        flow: secureFlow,
        context: (request) {
          final authHeader = request.headers['Authorization'];
          if (authHeader == 'Bearer secret') {
            return {'user': 'Admin'};
          }
          // Returning empty context or throwing here will result in ctx.context being null or the request failing
          return {};
        },
      ),
      clientFlow,
    ],
    port: 3400,
    cors: {
      'origin': '*', // Allow all origins for development
    },
  );
}
