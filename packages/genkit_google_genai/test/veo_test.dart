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
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('createVeoModel', () {
    test(
      'does not expose a completed operation as a background operation',
      () async {
        final bytes = utf8.encode('fake video bytes');
        final client = _FakeVeoClient(
          _videoOperation('https://example.com/video.mp4'),
        );

        final model = createVeoModel(
          pluginName: 'googleai',
          modelName: 'veo-3.0-generate-001',
          getApiClient: ([String? _]) async => client,
          downloadClient: MockClient((request) async {
            expect(request.headers, isNot(contains('x-goog-api-key')));
            return http.Response.bytes(
              bytes,
              200,
              headers: {'content-type': 'video/mp4'},
            );
          }),
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

  group('toEmbeddableVeoMediaPart', () {
    test('downloads media without GenAI API key headers', () async {
      final bytes = utf8.encode('fake video bytes');
      final service = _FakeVeoClient(
        _videoOperation('https://example.com/video.mp4'),
        client: _RejectingAuthenticatedClient(),
      );

      final mediaPart = await toEmbeddableVeoMediaPart(
        service,
        service.operation,
        downloadClient: MockClient((request) async {
          expect(request.headers, isNot(contains('x-goog-api-key')));
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'video/mp4'},
          );
        }),
      );

      expect(
        mediaPart.media.url,
        'data:video/mp4;base64,${base64Encode(bytes)}',
      );
      expect(mediaPart.media.contentType, 'video/mp4');
      expect(mediaPart.metadata?['sourceUrl'], 'https://example.com/video.mp4');
    });

    test('uses GenAI client for Google API download URLs', () async {
      final bytes = utf8.encode('fake video bytes');
      final service = _FakeVeoClient(
        _videoOperation(
          'https://generativelanguage.googleapis.com/v1beta/files/abc:download',
        ),
        client: _HeaderAddingClient(
          MockClient((request) async {
            expect(request.headers, containsPair('x-goog-api-key', 'test-key'));
            return http.Response.bytes(
              bytes,
              200,
              headers: {'content-type': 'video/mp4'},
            );
          }),
        ),
      );

      final mediaPart = await toEmbeddableVeoMediaPart(
        service,
        service.operation,
      );

      expect(
        mediaPart.media.url,
        'data:video/mp4;base64,${base64Encode(bytes)}',
      );
      expect(mediaPart.media.contentType, 'video/mp4');
      expect(
        mediaPart.metadata?['sourceUrl'],
        'https://generativelanguage.googleapis.com/v1beta/files/abc:download',
      );
    });
  });
}

gcl.Operation _videoOperation(String uri) {
  return gcl.Operation(
    name: 'operations/123',
    done: true,
    response: {
      'generateVideoResponse': {
        'generatedSamples': [
          {
            'video': {'uri': uri, 'mimeType': 'video/mp4'},
          },
        ],
      },
    },
  );
}

class _FakeVeoClient extends GenerativeLanguageBaseClient {
  final gcl.Operation operation;

  _FakeVeoClient(this.operation, {http.Client? client})
    : super(
        baseUrl: 'https://generativelanguage.googleapis.com/',
        client: client ?? http.Client(),
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

class _HeaderAddingClient extends http.BaseClient {
  final http.Client _inner;

  _HeaderAddingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['x-goog-api-key'] = 'test-key';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

class _RejectingAuthenticatedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    fail('Authenticated GenAI client should not fetch external media URLs.');
  }
}
