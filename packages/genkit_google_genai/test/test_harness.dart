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
/// and answered with [response] if given, otherwise a canned single-candidate
/// response whose text is the JSON scalar `"ok"`, so it also parses as
/// JSON-format output.
class WirePlugin extends GoogleGenAiPluginImpl {
  WirePlugin(this.captured, {this.response}) : super(apiKey: 'test-key');

  /// Request bodies seen so far, oldest first.
  final List<Map<String, dynamic>> captured;

  /// Raw `GenerateContentResponse` JSON returned for every request.
  final Map<String, dynamic>? response;

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        return http.Response(
          jsonEncode(
            response ??
                {
                  'candidates': [
                    {
                      'content': {
                        'role': 'model',
                        'parts': [
                          {'text': '"ok"'},
                        ],
                      },
                      'finishReason': 'STOP',
                    },
                  ],
                },
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}

/// A plugin whose Interactions calls are captured rather than sent.
///
/// Every request is appended to [requests] and answered with [response]
/// (the interaction JSON) or, for streamed requests, with [sseEvents] (each
/// sent as one `data:` frame). Without either, a completed interaction with
/// the text `"ok"` is returned (it also parses as JSON output).
class InteractionsWirePlugin extends GoogleGenAiPluginImpl {
  InteractionsWirePlugin({
    List<http.Request>? requests,
    this.response,
    this.sseEvents,
    this.status = 200,
    super.store,
  }) : requests = requests ?? [],
       super(apiKey: 'test-key');

  /// Requests seen so far, oldest first.
  final List<http.Request> requests;

  /// Interaction JSON returned for non-streamed requests.
  final Map<String, dynamic>? response;

  /// SSE events returned for streamed requests.
  final List<Map<String, dynamic>>? sseEvents;

  /// HTTP status of every response.
  final int status;

  /// The JSON body of the last request.
  Map<String, dynamic> get lastBody =>
      (jsonDecode(requests.last.body) as Map).cast<String, dynamic>();

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
    'usage': {'total_input_tokens': 3, 'total_output_tokens': 1},
  };

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        requests.add(request);
        final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        if (body['stream'] == true) {
          final events = sseEvents ?? const [];
          return http.Response(
            events.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
            status,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        return http.Response(
          jsonEncode(response ?? defaultInteraction),
          status,
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

  /// Whether [close] has been called.
  bool closed = false;

  @override
  void close() {
    closed = true;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith(':generateContent')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"candidates": [{"content": {"parts": [{"text": "response"}], '
            '"role": "model"}, "finishReason": "STOP"}]}',
          ),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith(':embedContent')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"embedding": {"values": [0.1, 0.2]}}')),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path != '/v1beta/models') {
      throw StateError('Unexpected request: ${request.url}');
    }
    final body =
        modelsResponse ??
        '{"models": ['
            '{"name": "models/gemini-2.0-flash"}, '
            '{"name": "models/text-embedding-004", '
            '"supportedGenerationMethods": ["embedContent"]}]}';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      listStatus,
      headers: {'content-type': 'application/json'},
    );
  }
}
