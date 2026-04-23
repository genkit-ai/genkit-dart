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

import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
    as gcl;
import 'package:genkit_google_genai/src/veo.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('createVeoModel', () {
    test(
      'does not expose a completed operation as a background operation',
      () async {
        final bytes = utf8.encode('fake video bytes');
        final client = _FakeVeoClient(
          gcl.Operation(
            name: 'operations/123',
            done: true,
            response: {
              'generateVideoResponse': {
                'generatedSamples': [
                  {
                    'video': {
                      'uri': 'https://example.com/video.mp4',
                      'mimeType': 'video/mp4',
                    },
                  },
                ],
              },
            },
          ),
          videoBytes: bytes,
        );

        final model = createVeoModel(
          pluginName: 'googleai',
          modelName: 'veo-3.0-generate-001',
          getApiClient: ([String? _]) async => client,
          handleException: (e, stack) {
            if (e is GenkitException) return e;
            return GenkitException(
              'Google AI Error: $e',
              status: StatusCodes.INTERNAL,
              underlyingException: e,
              stackTrace: stack,
            );
          },
        );

        final response = await model.run(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'Create a short test video.')],
              ),
            ],
          ),
        );

        expect(response.result.operation, isNull);
        expect(
          response.result.media?.url,
          'data:video/mp4;base64,${base64Encode(bytes)}',
        );
        expect(response.result.media?.contentType, 'video/mp4');
        expect(
          response.result.message?.content.first.metadata?['sourceUrl'],
          'https://example.com/video.mp4',
        );
      },
    );
  });
}

class _FakeVeoClient extends GenerativeLanguageBaseClient {
  final gcl.Operation operation;
  final List<int> videoBytes;

  _FakeVeoClient(this.operation, {required this.videoBytes})
    : super(
        baseUrl: 'https://example.com/',
        client: _FakeDownloadClient(videoBytes),
      );

  @override
  Future<gcl.Operation> predictLongRunning(
    Map<String, dynamic> request, {
    required String model,
  }) async {
    return operation;
  }

  @override
  Future<gcl.Operation> getOperation(String name) async {
    return operation;
  }
}

class _FakeDownloadClient extends http.BaseClient {
  final List<int> videoBytes;

  _FakeDownloadClient(this.videoBytes);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.toString() == 'https://example.com/video.mp4') {
      return http.StreamedResponse(
        Stream.value(videoBytes),
        200,
        headers: {'content-type': 'video/mp4'},
      );
    }

    return http.StreamedResponse(Stream<List<int>>.empty(), 404);
  }
}
