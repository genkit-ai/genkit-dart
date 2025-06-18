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
  late RemoteAction<String, String> remoteAction;

  setUp(() {
    mockClient = MockClient();
    remoteAction = RemoteAction<String, String>(
      url: 'http://localhost:3400/test',
      httpClient: mockClient,
      fromResponse: (data) => data as String,
      fromStreamChunk: (data) => data['chunk'] as String,
    );
  });

  group('RemoteAction - Core Functionality', () {
    group('call method', () {
      test('should handle successful response', () async {
        final input = 'test input';
        final expectedOutput = 'test output';

        when(
          mockClient.post(
            Uri.parse('http://localhost:3400/test'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'data': input}),
          ),
        ).thenAnswer(
          (_) async =>
              http.Response(jsonEncode({'result': expectedOutput}), 200),
        );

        final result = await remoteAction(input: input);
        expect(result, expectedOutput);
      });

      test('should send custom headers', () async {
        final input = 'test input';
        final customHeaders = {'Authorization': 'Bearer token'};

        when(
          mockClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(jsonEncode({'result': 'success'}), 200),
        );

        await remoteAction(input: input, headers: customHeaders);

        verify(
          mockClient.post(
            any,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer token',
            },
            body: anyNamed('body'),
          ),
        ).called(1);
      });
    });

    group('stream method', () {
      test('should handle streaming response', () async {
        final input = 'stream input';
        final expectedChunks = ['chunk1', 'chunk2', 'chunk3'];
        final expectedResponse = 'final response';

        final responseBody =
            '${expectedChunks.map((chunk) => 'data: ${jsonEncode({
              'message': {'chunk': chunk},
            })}').join('\n\n')}\n\ndata: ${jsonEncode({'result': expectedResponse})}\n\n';

        when(mockClient.send(any)).thenAnswer((_) async {
          return http.StreamedResponse(
            Stream.fromIterable([responseBody.codeUnits]),
            200,
          );
        });

        final streamResponse = remoteAction.stream(input: input);
        final chunks = <String>[];

        await for (final chunk in streamResponse.stream) {
          chunks.add(chunk);
        }

        final finalResponse = await streamResponse.response;

        expect(chunks, expectedChunks);
        expect(finalResponse, expectedResponse);
      });
    });
  });

  group('RemoteAction - Error Handling', () {
    test('should throw GenkitException on HTTP error status', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('Server Error', 500));

      expect(
        () => remoteAction(input: 'test'),
        throwsA(
          isA<GenkitException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('should throw GenkitException on invalid JSON response', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('invalid json', 200));

      expect(
        () => remoteAction(input: 'test'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('Failed to decode JSON'),
          ),
        ),
      );
    });

    test('should throw GenkitException on network error', () async {
      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(Exception('Network error'));

      expect(
        () => remoteAction(input: 'test'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('HTTP request failed'),
          ),
        ),
      );
    });

    test('should throw GenkitException on server error response', () async {
      final errorResponse = {
        'error': {'message': 'Flow execution failed'},
      };

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response(jsonEncode(errorResponse), 200));

      expect(
        () => remoteAction(input: 'test'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            'Flow execution failed',
          ),
        ),
      );
    });
  });

  group('RemoteAction - Type Safety', () {
    test('should handle typed objects', () async {
      final typedAction = RemoteAction<MyOutput, TestStreamChunk>(
        url: 'http://localhost:3400/typed',
        httpClient: mockClient,
        fromResponse: (data) => MyOutput.fromJson(data as Map<String, dynamic>),
        fromStreamChunk:
            (data) => TestStreamChunk.fromJson(data as Map<String, dynamic>),
      );

      final input = MyInput(message: 'test', count: 1);
      final expectedOutput = MyOutput(reply: 'processed', newCount: 2);

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: jsonEncode({'data': input.toJson()}),
        ),
      ).thenAnswer(
        (_) async =>
            http.Response(jsonEncode({'result': expectedOutput.toJson()}), 200),
      );

      final result = await typedAction(input: input.toJson());

      expect(result.reply, expectedOutput.reply);
      expect(result.newCount, expectedOutput.newCount);
    });
  });

  group('defineRemoteAction helper function', () {
    test('should create RemoteAction instance', () {
      final action = defineRemoteAction<String, String>(
        url: 'http://localhost:3400/helper',
        fromResponse: (data) => data as String,
      );

      expect(action, isA<RemoteAction<String, String>>());
    });

    test('should set default headers', () {
      final defaultHeaders = {'X-API-Key': 'test-key'};

      final action = defineRemoteAction<String, String>(
        url: 'http://localhost:3400/helper',
        fromResponse: (data) => data as String,
        defaultHeaders: defaultHeaders,
      );

      expect(action, isA<RemoteAction<String, String>>());
    });
  });

  tearDown(() {
    reset(mockClient);
  });
}
