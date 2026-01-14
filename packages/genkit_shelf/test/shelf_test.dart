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
import 'package:genkit_shelf/genkit_shelf.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

part 'shelf_test.schema.g.dart';

@GenkitSchema()
abstract class ShelfTestOutputSchema {
  String get greeting;
}

@GenkitSchema()
abstract class ShelfTestStreamSchema {
  String get chunk;
}

void main() {
  late Genkit ai;
  HttpServer? server;
  late int port;

  setUp(() {
    ai = Genkit();
  });

  tearDown(() async {
    await server?.close(force: true);
  });

  test('Unary flow', () async {
    final echoFlow = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputType: StringType,
      outputType: StringType,
    );

    server = await startFlowServer(flows: [echoFlow], port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/echo',
      fromResponse: (data) => data as String,
    );

    final result = await action(input: 'hello');
    expect(result, 'Echo: hello');
  });

  test('Streaming flow', () async {
    final streamFlow = ai.defineFlow(
      name: 'stream',
      fn: (input, ctx) async {
        ctx.sendChunk('Chunk 1');
        await Future.delayed(const Duration(milliseconds: 10));
        ctx.sendChunk('Chunk 2');
        return 'Done';
      },
      inputType: StringType,
      outputType: StringType,
      streamType: StringType,
    );

    server = await startFlowServer(flows: [streamFlow], port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/stream',
      fromResponse: (data) => data as String,
      fromStreamChunk: (data) => data as String,
    );

    final stream = action.stream(input: 'start');
    final chunks = <String>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    expect(chunks, ['Chunk 1', 'Chunk 2']);
    expect(await stream.onResult, 'Done');
  });

  test('Context provider', () async {
    final authFlow = ai.defineFlow(
      name: 'auth',
      fn: (input, ctx) async {
        final user = ctx.context?['user'];
        if (user == null) throw Exception('Unauthorized');
        return 'Hello $user';
      },
      inputType: StringType,
      outputType: StringType,
    );

    final flowWithContext = FlowWithContextProvider(
      flow: authFlow,
      context: (req) {
        final auth = req.headers['Authorization'];
        if (auth == 'Bearer token') {
          return {'user': 'Admin'};
        }
        return {};
      },
    );

    server = await startFlowServer(flows: [flowWithContext], port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/auth',
      fromResponse: (data) => data as String,
      defaultHeaders: {'Authorization': 'Bearer token'},
    );

    final result = await action(input: 'hi');
    expect(result, 'Hello Admin');

    // Fail case
    final actionFail = defineRemoteAction(
      url: 'http://localhost:$port/auth',
      fromResponse: (data) => data as String,
    );

    try {
      await actionFail(input: 'hi');
      fail('Should have thrown');
    } catch (e) {
      // Expected
      expect(e.toString(), contains('Unauthorized'));
    }
  });

  test('Direct shelfHandler', () async {
    final echoFlow = ai.defineFlow(
      name: 'echo',
      fn: (input, _) async => 'Echo: $input',
      inputType: StringType,
      outputType: StringType,
    );

    final handler = shelfHandler(echoFlow);

    final request = Request(
      'POST',
      Uri.parse('http://localhost/echo'),
      body: '{"data": "direct"}',
      headers: {'content-type': 'application/json'},
    );

    final response = await handler(request);

    expect(response.statusCode, 200);
    final body = await response.readAsString();
    expect(body, contains('"result":"Echo: direct"'));
  });

  test('Client using JsonExtensionType', () async {
    final echoFlow = ai.defineFlow(
      name: 'echoType',
      fn: (input, _) async => 'Echo: $input',
      inputType: StringType,
      outputType: StringType,
    );

    server = await startFlowServer(flows: [echoFlow], port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/echoType',
      outputType: StringType,
    );

    final result = await action(input: 'typed');
    expect(result, 'Echo: typed');
  });

  test('Client using GenkitSchema types and Streaming', () async {
    final complexStreamFlow = ai.defineFlow(
      name: 'complexStream',
      fn: (input, ctx) async {
        ctx.sendChunk(ShelfTestStream.from(chunk: 'chunk1'));
        await Future.delayed(const Duration(milliseconds: 10));
        ctx.sendChunk(ShelfTestStream.from(chunk: 'chunk2'));
        return ShelfTestOutput.from(greeting: 'done');
      },
      inputType: StringType,
      outputType: ShelfTestOutputType,
      streamType: ShelfTestStreamType,
    );

    server = await startFlowServer(flows: [complexStreamFlow], port: 0);
    port = server!.port;

    final action = defineRemoteAction(
      url: 'http://localhost:$port/complexStream',
      outputType: ShelfTestOutputType,
      streamType: ShelfTestStreamType,
    );

    final stream = action.stream(input: 'start');
    final chunks = <ShelfTestStream>[];
    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    final result = await stream.onResult;

    expect(chunks.length, 2);
    expect(chunks[0].chunk, 'chunk1');
    expect(chunks[1].chunk, 'chunk2');

    expect(result.greeting, 'done');
  });

  test('Streaming flow headers and timing', () async {
    final streamFlow = ai.defineFlow(
      name: 'streamHeaders',
      fn: (input, ctx) async {
        ctx.sendChunk('Chunk 1');
        await Future.delayed(const Duration(milliseconds: 100));
        ctx.sendChunk('Chunk 2');
        return 'Done';
      },
      inputType: StringType,
      outputType: StringType,
      streamType: StringType,
    );

    server = await startFlowServer(flows: [streamFlow], port: 0);
    port = server!.port;

    final client = http.Client();
    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:$port/streamHeaders?stream=true'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = '{"data": "start"}';

    final response = await client.send(request);

    final chunks = <int>[];
    final start = DateTime.now();
    await response.stream.listen((chunk) {
      chunks.add(DateTime.now().difference(start).inMilliseconds);
    }).asFuture();

    // First chunk should be fast, next should be after ~100ms
    // We expect at least some delay between chunks if streaming works.
    // If buffering, all chunks might arrive at same time > 100ms.
    // Actually, response.stream gives bytes.
    // Let's decode to ensure we get distinctive data chunks.
    // But raw byte chunks arrival time is enough.

    // If buffered, we likely get one big chunk after 100ms.
    // If streaming, we get one chunk immediately (or very fast), then another.

    expect(chunks.length, greaterThanOrEqualTo(2),
        reason: 'Should receive multiple chunks');
    expect(chunks.last, greaterThan(80),
        reason: 'Total time should be around 100ms');
    // If buffering happened, chunks.first would probably be ~100ms too (depending on implementation).
    // Better check:
    // If we receive multiple chunks, and the first one is fast (< 50ms) and last is slow (> 80ms), then we streamed.
    // If we receive only 1 chunk, or all chunks > 80ms, then we buffered.

    // Note: shelf might send headers immediately, then body.
    // checking first chunk time.
    expect(chunks.first, lessThan(80),
        reason: 'First chunk should arrive quickly');
  });
}
