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
import 'package:schemantic/schemantic.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

part 'shelf_handler_example.schema.g.dart';

@GenkitSchema()
abstract class HandlerInputSchema {
  String get message;
}

@GenkitSchema()
abstract class HandlerOutputSchema {
  String get processedMessage;
}

// This example demonstrates how to use the shelfHandler directly to integrate
// Genkit flows into an existing Shelf application or with custom routing.
//
// To run this example:
// 1. dart run example/shelf_handler_example.dart
//
// To test the endpoint:
// curl -X POST http://localhost:8080/api/custom-flow -H "Content-Type: application/json" -d '{"data": "Dart"}'
//
// To test the client flow:
// curl -X POST http://localhost:8080/api/client -H "Content-Type: application/json" -d '{"data": "start"}'

void main() async {
  configureCollectorExporter();

  final ai = Genkit();

  // Define client action
  final customAction = defineRemoteAction(
    url: 'http://localhost:8080/api/custom-flow',
    outputType: HandlerOutputType,
  );

  // Define a flow
  final customFlow = ai.defineFlow(
    name: 'customFlow',
    fn: (HandlerInput input, _) async => HandlerOutput.from(
      processedMessage: 'Processed by custom handler: ${input.message}',
    ),
    inputType: HandlerInputType,
    outputType: HandlerOutputType,
  );

  // Define client flow
  final clientFlow = ai.defineFlow(
    name: 'client',
    fn: (String input, _) async {
      final result = await customAction(
        input: HandlerInput.from(message: 'Client via $input'),
      );
      return result.processedMessage;
    },
    inputType: StringType,
    outputType: StringType,
  );

  // Create a Shelf Router
  final router = Router();

  // Mount the flow handler at a specific path
  router.post('/api/custom-flow', shelfHandler(customFlow));
  router.post('/api/client', shelfHandler(clientFlow));

  // Add other application routes
  router.get('/health', (Request request) => Response.ok('OK'));

  // Create a handler pipeline (e.g., adding logging)
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  // Start the server
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:${server.port}');
  print('Health check: http://localhost:${server.port}/health');
  print('Flow endpoint: http://localhost:${server.port}/api/custom-flow');
  print('Client endpoint: http://localhost:${server.port}/api/client');
}
