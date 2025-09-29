// Copyright 2024 Google LLC
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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';

import 'client_test.mocks.dart';
import 'schemas/stream_schemas.dart';

void main() {
  late MockClient mockClient;
  late RemoteAction<String, String> stringStreamAction;
  late RemoteAction<Map<String, dynamic>, TestStreamChunk> objectStreamAction;

  setUp(() {
    mockClient = MockClient();

    stringStreamAction = RemoteAction<String, String>(
      url: 'http://localhost:3400/string-stream',
      httpClient: mockClient,
      fromResponse: (data) => data as String,
      fromStreamChunk: (data) => data['chunk'] as String,
    );

    objectStreamAction = RemoteAction<Map<String, dynamic>, TestStreamChunk>(
      url: 'http://localhost:3400/object-stream',
      httpClient: mockClient,
      fromResponse: (data) => data as Map<String, dynamic>,
      fromStreamChunk:
          (data) => TestStreamChunk.fromJson(data as Map<String, dynamic>),
    );
  });

  group('Streaming - Core Functionality', () {
    test('should handle string stream chunks correctly', () async {
      final input = 'test stream input';
      final expectedChunks = ['chunk1', 'chunk2', 'chunk3'];
      final expectedResponse = 'final response';

      final streamData =
          '${expectedChunks.map((chunk) => 'data: ${jsonEncode({
            'message': {'chunk': chunk},
          })}\n\n').join()}data: ${jsonEncode({'result': expectedResponse})}\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode(streamData)]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final streamResponse = stringStreamAction.stream(input: input);
      final chunks = <String>[];

      await for (final chunk in streamResponse.stream) {
        chunks.add(chunk);
      }

      final finalResponse = await streamResponse.response;

      expect(chunks, expectedChunks);
      expect(finalResponse, expectedResponse);
    });

    test('should handle object stream chunks correctly', () async {
      final input = {'prompt': 'test'};
      final expectedChunks = [
        TestStreamChunk(chunk: 'first'),
        TestStreamChunk(chunk: 'second'),
      ];
      final expectedResponse = {'result': 'completed'};

      final streamData =
          '${expectedChunks.map((chunk) => 'data: ${jsonEncode({'message': chunk.toJson()})}\n\n').join()}data: ${jsonEncode({'result': expectedResponse})}\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode(streamData)]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final streamResponse = objectStreamAction.stream(input: input);
      final chunks = <TestStreamChunk>[];

      await for (final chunk in streamResponse.stream) {
        chunks.add(chunk);
      }

      final finalResponse = await streamResponse.response;

      expect(chunks.length, expectedChunks.length);
      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].chunk, expectedChunks[i].chunk);
      }
      expect(finalResponse, expectedResponse);
    });
  });

  group('Streaming - Error Handling', () {
    test('should handle HTTP errors during streaming', () async {
      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable(['Server Error'.codeUnits]),
          500,
        );
      });

      final streamResponse = stringStreamAction.stream(input: 'test');

      expect(
        () => streamResponse.stream.toList(),
        throwsA(
          isA<GenkitException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );

      expect(() => streamResponse.response, throwsA(isA<GenkitException>()));
    });

    test('should throw error on invalid SSE data', () async {
      final invalidStreamData = 'invalid sse data\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode(invalidStreamData)]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final streamResponse = stringStreamAction.stream(input: 'test');

      await expectLater(
        Future.wait([streamResponse.stream.toList(), streamResponse.response]),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('Stream finished without a final result or error chunk'),
          ),
        ),
      );
    });

    test('should throw error when fromStreamChunk is undefined', () {
      final actionWithoutStreamChunk = RemoteAction<String, String>(
        url: 'http://localhost:3400/no-stream',
        httpClient: mockClient,
        fromResponse: (data) => data as String,
        // fromStreamChunk is not provided
      );

      final streamResponse = actionWithoutStreamChunk.stream(input: 'test');

      expect(
        () => streamResponse.stream.toList(),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('fromStreamChunk must be provided'),
          ),
        ),
      );

      expect(() => streamResponse.response, throwsA(isA<GenkitException>()));
    });
  });

  group('Streaming - Lifecycle', () {
    test('should process multiple chunks progressively', () async {
      final chunks = ['chunk1', 'chunk2', 'chunk3'];
      final streamController = StreamController<List<int>>();

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          streamController.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final streamResponse = stringStreamAction.stream(input: 'test');
      final receivedChunks = <String>[];

      final subscription = streamResponse.stream.listen((chunk) {
        receivedChunks.add(chunk);
      });

      // Send chunks progressively
      for (final chunk in chunks) {
        final data =
            'data: ${jsonEncode({
              'message': {'chunk': chunk},
            })}\n\n';
        streamController.add(utf8.encode(data));
        await Future.delayed(Duration(milliseconds: 10));
      }

      // Send final response
      final finalData = 'data: ${jsonEncode({'result': 'done'})}\n\n';
      streamController.add(utf8.encode(finalData));
      await streamController.close();

      await subscription.asFuture();

      expect(receivedChunks, chunks);
      expect(await streamResponse.response, 'done');
    });
  });

  group('Streaming - Custom Headers', () {
    test('should send custom headers', () async {
      final customHeaders = {'Authorization': 'Bearer token123'};
      final streamData = 'data: ${jsonEncode({
            'message': {'chunk': 'test'},
          })}\n\n'
          'data: ${jsonEncode({'result': 'success'})}\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([utf8.encode(streamData)]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      await stringStreamAction
          .stream(input: 'test', headers: customHeaders)
          .stream
          .toList();

      final captured =
          verify(mockClient.send(captureAny)).captured.single
              as http.BaseRequest;
      expect(captured.headers['authorization'], 'Bearer token123');
      expect(captured.headers['accept'], 'text/event-stream');
    });
  });

  tearDown(() {
    reset(mockClient);
  });
}
