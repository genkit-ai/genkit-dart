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

import 'package:genkit/plugin.dart'
    show genkitVersion, getPlatformLanguageVersion;
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/common_plugin.dart' show resolveApiKey;
import 'package:genkit_google_genai/src/generated/generativelanguage.dart';
import 'package:genkit_google_genai/src/interaction_types.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// The `X-Goog-Api-Client` value (the same as before the client built it).
final _apiClientHeader =
    'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}';

/// A completed interaction, as one SSE event for streamed requests.
const _completedEvent =
    'data: {"event_type":"interaction.completed",'
    '"interaction":{"status":"completed"}}\n\n';

/// A client that records every request and answers with 200: [body], or for
/// a streamed interaction a completed SSE event.
GenerativeLanguageBaseClient _client(
  List<http.Request> requests, {
  String body = '{}',
  String? apiKey,
  String Function()? accessToken,
  Map<String, String> headers = const {},
}) => GenerativeLanguageBaseClient(
  baseUrl: 'https://example.test/',
  client: MockClient((request) async {
    requests.add(request);
    final streamed = request.body.contains('"stream":true');
    return http.Response(streamed ? _completedEvent : body, 200);
  }),
  apiKey: apiKey,
  accessToken: accessToken,
  headers: headers,
);

void main() {
  group('request headers', () {
    late List<http.Request> requests;
    setUp(() => requests = []);

    test('generateContent: API key, api client and content type', () async {
      await _client(
        requests,
        apiKey: 'test-key',
      ).generateContent(GenerateContentRequest(), model: 'models/m');
      final headers = requests.single.headers;
      expect(headers['x-goog-api-key'], 'test-key');
      expect(headers['X-Goog-Api-Client'], _apiClientHeader);
      expect(headers['Content-Type'], startsWith('application/json'));
      expect(headers, isNot(contains('Authorization')));
      expect(headers, isNot(contains('Api-Revision')));
    });

    test('streamGenerateContent sends the same headers', () async {
      await _client(requests, apiKey: 'test-key', body: 'data: {}\n\n')
          .streamGenerateContent(GenerateContentRequest(), model: 'models/m')
          .drain<void>();
      final headers = requests.single.headers;
      expect(headers['x-goog-api-key'], 'test-key');
      expect(headers['X-Goog-Api-Client'], _apiClientHeader);
      expect(headers, isNot(contains('Api-Revision')));
    });

    test('a GET has no content type or body', () async {
      await _client(requests, apiKey: 'test-key').listModels();
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.headers['x-goog-api-key'], 'test-key');
      expect(request.headers['X-Goog-Api-Client'], _apiClientHeader);
      expect(request.headers, isNot(contains('Content-Type')));
      expect(request.body, isEmpty);
    });

    test('createInteraction and its stream add Api-Revision', () async {
      final client = _client(
        requests,
        apiKey: 'test-key',
        body: jsonEncode({'status': 'completed'}),
      );
      final request = CreateInteractionRequest(model: 'm', input: 'Hi');
      await client.createInteraction(request);
      await client.createInteractionStream(request).drain<void>();
      expect(requests, hasLength(2));
      for (final sent in requests) {
        expect(sent.headers['Api-Revision'], interactionsApiRevision);
        expect(sent.headers['x-goog-api-key'], 'test-key');
        expect(sent.headers['X-Goog-Api-Client'], _apiClientHeader);
      }
      expect(jsonDecode(requests.last.body), containsPair('stream', true));
    });

    test('an access token is sent as a bearer token, asked for per '
        'request', () async {
      var calls = 0;
      final client = _client(requests, accessToken: () => 'token-${++calls} ');
      await client.generateContent(GenerateContentRequest(), model: 'models/m');
      await client.generateContent(GenerateContentRequest(), model: 'models/m');
      expect(requests.map((r) => r.headers['Authorization']), [
        'Bearer token-1',
        'Bearer token-2',
      ]);
      expect(requests.first.headers, isNot(contains('x-goog-api-key')));
    });

    test("extra headers are sent but can't replace the client's", () async {
      await _client(
        requests,
        apiKey: 'test-key',
        accessToken: () => 'token',
        headers: {
          'X-Vertex-AI-LLM-Shared-Request-Type': 'flex',
          'x-goog-api-key': 'other-key',
          'Authorization': 'Bearer other',
          'X-Goog-Api-Client': 'other',
          'Api-Revision': 'other',
        },
      ).createInteraction(CreateInteractionRequest(model: 'm', input: 'Hi'));
      final headers = requests.single.headers;
      expect(headers['X-Vertex-AI-LLM-Shared-Request-Type'], 'flex');
      expect(headers['x-goog-api-key'], 'test-key');
      expect(headers['Authorization'], 'Bearer token');
      expect(headers['X-Goog-Api-Client'], _apiClientHeader);
      expect(headers['Api-Revision'], interactionsApiRevision);
    });

    test('no API key and no token: no auth headers', () async {
      await _client(requests).listModels();
      expect(requests.single.headers, isNot(contains('x-goog-api-key')));
      expect(requests.single.headers, isNot(contains('Authorization')));
    });
  });

  test('resolveApiKey returns the given key', () {
    expect(resolveApiKey('given-key'), 'given-key');
  });
}
