// Copyright 2026 Google LLC
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

import 'package:genkit_google_genai/common.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A plugin whose generateContent calls are captured rather than sent.
///
/// Every request body the plugin puts on the wire is appended to [captured]
/// and answered with a canned single-candidate response.
class WirePlugin extends GoogleGenAiPluginImpl {
  WirePlugin(this.captured) : super(apiKey: 'test-key');

  /// Request bodies seen so far, oldest first.
  final List<Map<String, dynamic>> captured;

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}

/// Serves a canned models listing and rejects any other request.
class ListingClient extends http.BaseClient {
  ListingClient({this.modelsResponse, this.listStatus = 200});

  /// Overrides the JSON body returned for the models listing.
  final String? modelsResponse;

  /// HTTP status returned for the models listing.
  final int listStatus;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path != '/v1beta/models') {
      throw StateError('Unexpected request: ${request.url}');
    }
    final body =
        modelsResponse ??
        '{"models": ['
            '{"name": "models/gemini-2.0-flash"}, '
            '{"name": "models/text-embedding-004"}]}';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      listStatus,
      headers: {'content-type': 'application/json'},
    );
  }
}
