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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A model pinned to generateContent.
const _generateContentModel = 'gemini-3.5-flash';

/// A model called through the Interactions API.
const _interactionsModel = 'gemini-flash-latest';

/// Sends one generate request for [model] through a plugin built with
/// [baseUrl] and returns the URL it went to and its JSON body. With [stream],
/// the request is streamed.
Future<({Uri url, Map<String, dynamic> body})> _send({
  String model = _generateContentModel,
  String? baseUrl,
  bool stream = false,
}) async {
  final requests = <http.Request>[];
  final plugin = GoogleGenAiPluginImpl(
    apiKey: 'test-key',
    baseUrl: baseUrl,
    httpClient: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/interactions')) {
        return _interactionResponse(request);
      }
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
  final action = plugin.resolve(.model, model) as Model;
  await action.run(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ],
    ),
    onChunk: stream ? (_) {} : null,
  );
  final request = requests.single;
  return (
    url: request.url,
    body: (jsonDecode(request.body) as Map).cast<String, dynamic>(),
  );
}

/// A completed interaction: SSE events for a streamed request, JSON
/// otherwise.
http.Response _interactionResponse(http.Request request) {
  const interaction = {
    'status': 'completed',
    'steps': [
      {
        'type': 'model_output',
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      },
    ],
  };
  final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
  if (body['stream'] == true) {
    final events = [
      {
        'event_type': 'step.delta',
        'index': 0,
        'delta': {'type': 'text', 'text': 'ok'},
      },
      {'event_type': 'step.stop', 'index': 0},
      {'event_type': 'interaction.completed', 'interaction': interaction},
    ];
    return http.Response(
      '${events.map((e) => 'data: ${jsonEncode(e)}\n\n').join()}'
      'data: [DONE]\n\n',
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
  return http.Response(
    jsonEncode(interaction),
    200,
    headers: {'content-type': 'application/json'},
  );
}

/// The URL of one generate request through a plugin built with [baseUrl].
Future<Uri> _requestUrl({String? baseUrl}) async =>
    (await _send(baseUrl: baseUrl)).url;

void main() {
  test('sends requests to the Gemini API by default', () async {
    expect(
      '${await _requestUrl()}',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
    );
  });

  test('sends requests to a custom baseUrl', () async {
    expect(
      '${await _requestUrl(baseUrl: 'https://proxy.test/genai')}',
      'https://proxy.test/genai/v1beta/models/gemini-3.5-flash:generateContent',
    );
  });

  group('Interactions API', () {
    test('sends requests to the Gemini API by default', () async {
      final sent = await _send(model: _interactionsModel);
      expect(
        '${sent.url}',
        'https://generativelanguage.googleapis.com/v1beta/interactions',
      );
      expect(sent.body['model'], _interactionsModel);
    });

    test('sends requests to a custom baseUrl', () async {
      final sent = await _send(
        model: _interactionsModel,
        baseUrl: 'https://proxy.test/genai',
      );
      expect('${sent.url}', 'https://proxy.test/genai/v1beta/interactions');
      expect(sent.body, isNot(contains('stream')));
    });

    test('sends streamed requests to a custom baseUrl', () async {
      // The streamed call builds its URL apart from the other requests.
      final sent = await _send(
        model: _interactionsModel,
        baseUrl: 'https://proxy.test/genai',
        stream: true,
      );
      expect('${sent.url}', 'https://proxy.test/genai/v1beta/interactions');
      expect(sent.body['stream'], true);
    });
  });
}
