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
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

@GenerateMocks([http.Client])
import 'remote_model_test.mocks.dart';

void main() {
  group('Remote Model', () {
    late Genkit ai;
    late MockClient mockClient;
    const remoteUrl = 'http://localhost:3400/remote-model';

    setUp(() {
      ai = Genkit(isDevEnv: false);
      mockClient = MockClient();
    });

    test('should handle unary response', () async {
      final remoteModel = ai.defineRemoteModel(
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

      final response = await ai.generate(
        model: remoteModel,
        prompt: 'say hello',
      );

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
      final remoteModel = ai.defineRemoteModel(
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
      final response = await ai.generate(
        model: remoteModel,
        prompt: 'stream it',
        onChunk: (c) => receivedChunks.add(c.text),
      );

      expect(receivedChunks, ['Part 1 ', 'Part 2']);
      expect(response.text, 'Part 1 Part 2');
    });

    test('should include custom headers', () async {
      final remoteModel = ai.defineRemoteModel(
        name: 'my-remote-model',
        url: remoteUrl,
        httpClient: mockClient,
        headers: (context) {
          return {'X-User-ID': context['userId']};
        },
      );

      when(
        mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'result': ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(role: Role.model, content: []),
            ).toJson(),
          }),
          200,
        ),
      );

      await ai.generate(
        model: remoteModel,
        prompt: 'test headers',
        context: {'userId': '123'},
      );

      verify(
        mockClient.post(
          any,
          headers: argThat(containsPair('X-User-ID', '123'), named: 'headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });
  });
}
