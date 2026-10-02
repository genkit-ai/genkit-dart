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

import 'dart:io';

import 'package:genkit/client.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:logging/logging.dart';
import 'package:schemantic/schemantic.dart';

part 'http_server_example.g.dart';

@Schema()
abstract class $HelloInput {
  String get name;
}

@Schema()
abstract class $HelloOutput {
  String get greeting;
}

@Schema()
abstract class $CountChunk {
  int get count;
}

// This example serves Genkit flows over HTTP with nothing but dart:io.
//
// To run this example:
//   dart run example/http_server_example.dart          # GenkitRouter.serve()
//   dart run example/http_server_example.dart --custom # your own HttpServer
//
// To test the endpoints (using curl):
//
// 1. Unary flow (POST request):
// curl -X POST http://localhost:3400/hello -H "Content-Type: application/json" -d '{"data": {"name": "World"}}'
//
// 2. Streaming flow (POST request with stream=true or Accept: text/event-stream):
// curl -X POST http://localhost:3400/count?stream=true -H "Content-Type: application/json" -d '{"data": 5}'
//
// 3. Auth flow (requires Bearer token):
// curl -X POST http://localhost:3400/secure -H "Content-Type: application/json" -H "Authorization: Bearer secret" -d '{"data": "User"}'
//
// 4. Client flow (calls other flows using the client library):
// curl -X POST http://localhost:3400/client -H "Content-Type: application/json" -d '{"data": "start"}'

void main(List<String> args) async {
  // Genkit logs through package:logging, which prints nothing until a listener
  // is attached. `serve()` logs the address it bound this way.
  Logger.root.onRecord.listen(print);

  final ai = Genkit();

  // Define remote actions for the client flow
  final helloAction = defineRemoteAction(
    url: 'http://localhost:3400/hello',
    outputSchema: HelloOutput.$schema,
  );

  final countAction = defineRemoteAction(
    url: 'http://localhost:3400/count',
    streamSchema: CountChunk.$schema,
    outputSchema: .string(),
  );

  // 1. Define a simple unary flow
  final helloFlow = ai.defineFlow(
    name: 'hello',
    fn: (HelloInput input, _) async {
      return HelloOutput(greeting: 'Hello, ${input.name}!');
    },
    inputSchema: HelloInput.$schema,
    outputSchema: HelloOutput.$schema,
  );

  // 2. Define a streaming flow
  final countFlow = ai.defineFlow(
    name: 'count',
    fn: (int count, ctx) async {
      for (var i = 1; i <= count; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        ctx.sendChunk(CountChunk(count: i));
      }
      return 'Done counting to $count';
    },
    inputSchema: .integer(),
    outputSchema: .string(),
    streamSchema: CountChunk.$schema,
  );

  // 3. Define a flow with authentication (context)
  final secureFlow = ai.defineFlow(
    name: 'secure',
    fn: (String input, ctx) async {
      final user = ctx.context?['user'];
      if (user == null) {
        throw GenkitException(
          'Unauthorized access',
          status: StatusCode.unauthenticated,
        );
      }
      return 'Secure data for $user: $input';
    },
    inputSchema: .string(),
    outputSchema: .string(),
  );

  // 4. Define a client flow that acts as a client to call other flows
  final clientFlow = ai.defineFlow(
    name: 'client',
    fn: (String input, _) async {
      final results = <String>[];
      results.add('Triggered client flow with input: $input');

      // Call 'hello' flow
      try {
        final helloRes = await helloAction(input: HelloInput(name: 'Client'));
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
    inputSchema: .string(),
    outputSchema: .string(),
  );

  // 5. Register the flows.
  final genkit = GenkitRouter()
    ..addAction(helloFlow)
    ..addAction(countFlow)
    ..addAction(secureFlow, contextProvider: _bearerAuth)
    ..addAction(clientFlow);

  if (!args.contains('--custom')) {
    // Standalone server, the quickest way to deploy (e.g. to Cloud Run).
    await genkit.serve(
      port: 3400,
      cors: const CorsOptions(), // Allow all origins for development
    );
    return;
  }

  // 6. Or plug Genkit into your own dart:io server, next to your own routes.
  final handleHealth = ioHandler(
    ai.defineFlow(
      name: 'health',
      fn: (_, _) async => 'OK',
      outputSchema: .string(),
    ),
  );
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3400);
  // Your own server, so you report its address yourself.
  print('Listening on http://localhost:${server.port}');
  await for (final request in server) {
    // Every Genkit route, e.g. POST /hello.
    if (await genkit.handleHttpRequest(request)) continue;
    // A single action on a path of your choosing.
    if (request.uri.path == '/healthz') {
      await handleHealth(request);
      continue;
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not found');
    await request.response.close();
  }
}

/// Turns the request's auth header into action context. Returning {} leaves
/// the user unset (so the flow rejects the call); throwing would reject the
/// request before the flow runs.
Map<String, dynamic> _bearerAuth(RequestData request) {
  if (request.headers['authorization'] == 'Bearer secret') {
    return {'user': 'Admin'};
  }
  return {};
}
