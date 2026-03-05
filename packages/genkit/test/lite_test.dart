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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit/lite.dart' as lite;
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'remote_model_test.mocks.dart';

void main() {
  test('lite generate with outputSchema does not throw', () async {
    // Defines a dummy model
    final model = Model<void>(
      name: 'testModel',
      fn: (request, context) async {
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    // Tests that lite.dart's generate passes outputSchema correctly
    // without throwing "type 'Function' is not a subtype of type 'Map<String, dynamic>' in type cast"
    final response = await lite.generate(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    expect(response.text, '{"result": "success"}');
  });

  test('lite generateStream with outputSchema does not throw', () async {
    final model = Model<void>(
      name: 'testModelStream',
      fn: (request, context) async {
        context.sendChunk(
          ModelResponseChunk(index: 0, content: [TextPart(text: '{"res')]),
        );
        context.sendChunk(
          ModelResponseChunk(
            index: 0,
            content: [TextPart(text: 'ult": "success"}')],
          ),
        );
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [TextPart(text: '{"result": "success"}')],
          ),
        );
      },
    );

    final stream = lite.generateStream(
      model: model,
      prompt: 'Hello',
      outputSchema: .string(),
    );

    final chunks = await stream.toList();
    expect(chunks.length, 2);
    expect(chunks[0].text, '{"res');
    expect(chunks[1].text, 'ult": "success"}');

    final response = await stream.onResult;
    expect(response.text, '{"result": "success"}');
  });

  group('remoteModel', () {
    late MockClient mockClient;
    const remoteUrl = 'http://localhost:3400/remote-model';

    setUp(() {
      mockClient = MockClient();
    });

    test('should handle unary response', () async {
      final model = lite.remoteModel(
        name: 'my-remote-model',
        url: remoteUrl,
        httpClient: mockClient,
      );

      final expectedResponse = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Hello from remote!')],
        ),
      );

      when(
        mockClient.post(
          Uri.parse(remoteUrl),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'result': expectedResponse.toJson()}),
          200,
        ),
      );

      final response = await lite.generate(model: model, prompt: 'say hello');

      expect(response.text, 'Hello from remote!');

      verify(
        mockClient.post(
          Uri.parse(remoteUrl),
          headers: anyNamed('headers'),
          body: argThat(contains('say hello'), named: 'body'),
        ),
      ).called(1);
    });

    test('should handle streaming response', () async {
      final model = lite.remoteModel(
        name: 'my-remote-model',
        url: remoteUrl,
        httpClient: mockClient,
      );

      final chunks = [
        ModelResponseChunk(content: [TextPart(text: 'Part 1 ')]),
        ModelResponseChunk(content: [TextPart(text: 'Part 2')]),
      ];

      final finalResponse = ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'Part 1 Part 2')],
        ),
      );

      final sseData =
          '${chunks.map((c) => 'data: ${jsonEncode({'message': c.toJson()})}').join('\n\n')}\n\ndata: ${jsonEncode({'result': finalResponse.toJson()})}\n\n';

      when(mockClient.send(any)).thenAnswer((_) async {
        return http.StreamedResponse(
          Stream.fromIterable([sseData.codeUnits]),
          200,
        );
      });

      final receivedChunks = <String>[];
      final stream = lite.generateStream(model: model, prompt: 'stream it');

      final chunksList = await stream.toList();
      for (final c in chunksList) {
        receivedChunks.add(c.text);
      }
      final response = await stream.onResult;

      expect(response.text, 'Part 1 Part 2');
    });
  });
}
