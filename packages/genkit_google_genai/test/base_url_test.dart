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

/// Sends one generate request through a plugin built with [baseUrl] and
/// returns the URL it went to.
Future<Uri> _requestUrl({String? baseUrl}) async {
  final urls = <Uri>[];
  final plugin = GoogleGenAiPluginImpl(
    apiKey: 'test-key',
    baseUrl: baseUrl,
    httpClient: MockClient((request) async {
      urls.add(request.url);
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
  final model = plugin.resolve(.model, 'gemini-3.5-flash') as Model;
  await model(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ],
    ),
  );
  return urls.single;
}

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
}
