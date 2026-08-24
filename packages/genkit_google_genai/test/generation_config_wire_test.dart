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
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// TODO(#366): consolidate with the shared wire harness once it lands.
/// Captures every generateContent request body the plugin puts on the wire
/// and serves a canned Gemini response.
class _WirePlugin extends GoogleGenAiPluginImpl {
  final List<Map<String, dynamic>> captured;

  _WirePlugin(this.captured) : super(apiKey: 'test-key');

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

const _schema = {
  'type': 'object',
  'properties': {
    'answer': {'type': 'string'},
  },
};

Future<Map<String, dynamic>> _generationConfigOnTheWire({
  OutputConfig? output,
  String model = 'gemini-2.0-flash',
}) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = _WirePlugin(captured);
  final action = plugin.resolve('model', model) as Model;
  await action(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ],
      output: output,
    ),
  );
  return (captured.single['generationConfig'] as Map).cast<String, dynamic>();
}

void main() {
  group('generationConfig on the wire', () {
    test('text-mode request with an output schema sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'text',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('request without output omits responseMimeType entirely', () async {
      final config = await _generationConfigOnTheWire();
      expect(config, isNot(contains('responseMimeType')));
    });

    test('JSON-mode unconstrained request sends mime type but no '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: false,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('JSON-mode constrained request sends application/json and the '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config['responseJsonSchema'], _schema);
    });

    test('TTS model text-mode request with an output schema sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'text',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('TTS model JSON-mode unconstrained request sends no '
        'responseJsonSchema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: false,
        ),
      );
      expect(config['responseMimeType'], 'application/json');
      expect(config, isNot(contains('responseJsonSchema')));
    });

    test('TTS model JSON-mode constrained request sends the '
        'schema', () async {
      final config = await _generationConfigOnTheWire(
        model: 'gemini-2.5-flash-preview-tts',
        output: OutputConfig(
          format: 'json',
          schema: _schema,
          constrained: true,
        ),
      );
      expect(config['responseJsonSchema'], _schema);
    });
  });
}
