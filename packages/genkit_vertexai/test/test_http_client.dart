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
  });

  final bool returnEmptyPredictions;
  final bool returnInvalidTextPrediction;
  final bool returnMissingMultimodalEmbedding;
  final List<Uri> requestUrls = [];
  final List<String> requestBodies = [];
  Uri? lastUrl;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestUrls.add(request.url);
    lastUrl = request.url;
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
    if (request.url.path == '/v1beta1/publishers/google/models') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"publisherModels": [{"name": "publishers/google/models/gemini-1.5-pro"}, {"name": "publishers/google/models/text-embedding-005"}, {"name": "publishers/google/models/multimodalembedding"}]}',
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
