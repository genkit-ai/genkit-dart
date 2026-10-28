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

import 'package:http/http.dart' as http;

class MockHttpClient extends http.BaseClient {
  MockHttpClient({
    this.returnEmptyPredictions = false,
    this.returnInvalidTextPrediction = false,
    this.returnMissingMultimodalEmbedding = false,
    this.publisherModelsResponse,
    this.publisherModelsStatus = 200,
    this.interactionResponse = defaultInteraction,
  });

  /// A completed interaction with the text `"ok"` (it also parses as JSON).
  static const defaultInteraction = {
    'status': 'completed',
    'steps': [
      {
        'type': 'model_output',
        'content': [
          {'type': 'text', 'text': '"ok"'},
        ],
      },
    ],
  };

  /// The JSON returned for Interactions API requests.
  final Map<String, Object?> interactionResponse;

  final bool returnEmptyPredictions;
  final bool returnInvalidTextPrediction;
  final bool returnMissingMultimodalEmbedding;

  /// Overrides the JSON body returned for the publisher-models listing.
  final String? publisherModelsResponse;

  /// HTTP status returned for the publisher-models listing.
  final int publisherModelsStatus;
  final List<Uri> requestUrls = [];
  final List<String> requestBodies = [];
  Uri? lastUrl;
  String? lastBody;
  Map<String, String>? lastHeaders;

  /// The streamed generateContent response (SSE `data:` lines), for
  /// `:streamGenerateContent` requests. Null = a single default chunk.
  List<Map<String, Object?>>? streamChunks;
  bool closed = false;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestUrls.add(request.url);
    lastUrl = request.url;
    if (request.url.host.contains('aiplatform')) {
      lastHeaders = Map.of(request.headers);
    }
    final requestBody = request is http.Request ? request.body : null;
    if (request is http.Request) {
      lastBody = requestBody;
      requestBodies.add(requestBody!);
    }
    if (request.url.host == 'metadata.google.internal' ||
        request.url.host == 'oauth2.googleapis.com') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"access_token": "ya29.mock", "expires_in": 3600, "token_type": "Bearer"}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':streamGenerateContent')) {
      final chunks =
          streamChunks ??
          [
            {
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'response'},
                    ],
                    'role': 'model',
                  },
                  'finishReason': 'STOP',
                },
              ],
            },
          ];
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(chunks.map((c) => 'data: ${jsonEncode(c)}\n\n').join()),
        ),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    if (request.url.path.endsWith('/interactions')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(interactionResponse))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/v1beta1/publishers/google/models') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            publisherModelsResponse ??
                '{"publisherModels": [{"name": "publishers/google/models/gemini-2.5-pro"}, {"name": "publishers/google/models/text-embedding-005"}, {"name": "publishers/google/models/multimodalembedding"}]}',
          ),
        ),
        publisherModelsStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':embedContent')) {
      // One content per request; the embedding encodes the number of
      // parts, so tests can tell the documents apart.
      final body = jsonDecode(requestBody!) as Map<String, dynamic>;
      final parts = (body['content'] as Map)['parts'] as List;
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode({
              'embedding': {
                'values': [parts.length + 0.1, parts.length + 0.2],
              },
            }),
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.contains('multimodalembedding') &&
        request.url.path.endsWith(':predict')) {
      final body = jsonDecode(requestBody!) as Map<String, dynamic>;
      final instances = body['instances'] as List;
      final predictions = returnEmptyPredictions
          ? const []
          : List.generate(instances.length, (index) {
              if (returnMissingMultimodalEmbedding) {
                return <String, dynamic>{};
              }

              final instance = instances[index] as Map<String, dynamic>;
              return {
                if (instance.containsKey('text'))
                  'textEmbedding': [index + 0.7, index + 0.8, index + 0.9],
                if (instance.containsKey('image'))
                  'imageEmbedding': [index + 1.7, index + 1.8, index + 1.9],
                if (instance.containsKey('video'))
                  'videoEmbeddings': [
                    {
                      'embedding': [index + 2.7, index + 2.8, index + 2.9],
                      'startOffsetSec': 0,
                      'endOffsetSec': 16,
                    },
                  ],
              };
            });
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'predictions': predictions}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':predict')) {
      final body = jsonDecode(requestBody!) as Map<String, dynamic>;
      final instances = body['instances'] as List;
      final predictions = returnEmptyPredictions
          ? const []
          : List.generate(
              instances.length,
              (index) => returnInvalidTextPrediction
                  ? <String, dynamic>{'embeddings': <String, dynamic>{}}
                  : {
                      'embeddings': {
                        'values': [index + 0.4, index + 0.5, index + 0.6],
                      },
                    },
            );
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'predictions': predictions}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"candidates": [{"content": {"parts": [{"text": "response"}], "role": "model"}, "finishReason": "STOP"}]} ',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
