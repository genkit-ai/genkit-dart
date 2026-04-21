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
  Uri? lastUrl;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUrl = request.url;
    if (request is http.Request) {
      lastBody = request.body;
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
    if (request.url.path.endsWith('gemini-embedding-001:embedContent')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"error": {"code": 400, "message": "Publisher Model `projects/my-project/locations/us-central1/publishers/google/models/gemini-embedding-001` is not supported in the embedContent API.", "status": "INVALID_ARGUMENT"}}',
          ),
        ),
        400,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':embedContent')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"embedding": {"values": [0.1, 0.2, 0.3]}}')),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.contains('multimodalembedding') &&
        request.url.path.endsWith(':predict')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode('{"predictions": [{"textEmbedding": [0.7, 0.8, 0.9]}]}'),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':predict')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"predictions": [{"embeddings": {"values": [0.4, 0.5, 0.6]}}]}',
          ),
        ),
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
