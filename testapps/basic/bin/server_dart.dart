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

import 'package:basic_sample/types.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:schemantic/schemantic.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

// Removed local schema definitions in favor of values from types.dart

void main() async {
  final ai = Genkit();

  ai.defineModel(
    name: 'echoModel',
    fn: (request, context) async {
      final input = request;
      for (var i = 0; i < 3; i++) {
        context.sendChunk(
          ModelResponseChunk.from(content: [TextPart.from(text: 'chunk $i')]),
        );
        await Future.delayed(Duration(seconds: 1));
      }

      final text = input.messages.map((m) => m.text).join();
      return ModelResponse.from(
        message: Message.from(
          role: Role.model,
          content: [TextPart.from(text: 'Echo: $text')],
        ),
        finishReason: FinishReason.stop,
      );
    },
  );

  final echoString = ai.defineFlow(
    name: 'echoString',
    inputType: stringType(),
    outputType: stringType(),
    fn: (input, _) async => input,
  );

  final processObject = ai.defineFlow(
    name: 'processObject',
    inputType: ProcessObjectInputType,
    outputType: ProcessObjectOutputType,
    fn: (input, _) async {
      return ProcessObjectOutput.from(
        reply: 'reply: ${input.message}',
        newCount: input.count + 1,
      );
    },
  );

  final streamObjects = ai.defineFlow(
    name: 'streamObjects',
    inputType: StreamObjectsInputType,
    outputType: StreamObjectsOutputType,
    streamType: StreamObjectsOutputType,
    fn: (input, context) async {
      for (var i = 0; i < 5; i++) {
        context.sendChunk(
          StreamObjectsOutput.from(text: 'input: $i', summary: 'summary $i'),
        );
        await Future.delayed(Duration(seconds: 1));
      }
      return StreamObjectsOutput.from(
        text: 'input: ${input.prompt}',
        summary: 'summary is summary',
      );
    },
  );

  final generate = ai.defineFlow(
    name: 'generate',
    // In Dart Genkit, typically we don't need to wrap generate merely for exposure if we expose the model directly,
    // but here we are matching the JS example which defines a flow 'generate'.
    // The JS example takes MessageSchema[] and returns GenerateResponseSchema.
    // In Dart we can just use the ModelRequest/Response types or rely on JSON.
    // However, defining a flow that mocks 'ai.generate' behavior:
    inputType: ModelRequestType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
    fn: (request, context) async {
      // Calling the model directly.
      final response = await ai.generate(
        model: modelRef('echoModel'),
        messages: request.messages,
        config: request.config,
        context: context.context,
        onChunk: (chunk) => context.sendChunk(chunk.rawChunk),
      );
      return response.rawResponse;
    },
  );

  final streamyThrowy = ai.defineFlow(
    name: 'streamyThrowy',
    inputType: intType(),
    outputType: stringType(),
    streamType: StreamyThrowyChunkType,
    fn: (count, context) async {
      var i = 0;
      for (; i < count; i++) {
        if (i == 3) {
          throw GenkitException('whoops', statusCode: 500);
        }
        await Future.delayed(Duration(seconds: 1));
        context.sendChunk(StreamyThrowyChunk.from(count: i));
      }
      return 'done: $count, streamed: $i times';
    },
  );

  final throwy = ai.defineFlow(
    name: 'throwy',
    inputType: stringType(),
    outputType: stringType(),
    fn: (subject, _) async {
      // Mocking 'call-llm' calls as simple runs or strings since we don't have that model.
      final foo = await ai.run('call-llm', () async {
        return 'subject: $subject';
      });

      if (subject.isNotEmpty) {
        throw GenkitException('whoops', statusCode: 500);
      }
      return await ai.run('call-llm', () async {
        return 'foo: $foo';
      });
    },
  );

  // Create a Shelf Router
  final router = Router();

  // Mount flows at the specific paths expected by client_example.dart
  router.post('/echoString', shelfHandler(echoString));
  router.post('/processObject', shelfHandler(processObject));
  router.post('/streamObjects', shelfHandler(streamObjects));
  router.post('/generate', shelfHandler(generate));
  router.post('/streamyThrowy', shelfHandler(streamyThrowy));
  router.post('/throwy', shelfHandler(throwy));

  // Start the server
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders(headers: {'Access-Control-Allow-Origin': '*'}))
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://localhost:${server.port}');
  print('Flow endpoints defined.');
}
