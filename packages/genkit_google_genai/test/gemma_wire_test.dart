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

/// Captures every generateContent request body the plugin puts on the wire
/// and serves a canned response.
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

Future<Map<String, dynamic>> _onTheWire({
  required String model,
  required List<Message> messages,
  Map<String, dynamic>? config,
}) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = _WirePlugin(captured);
  final action = plugin.resolve('model', model)!;
  await action.run(ModelRequest(messages: messages, config: config));
  return captured.single;
}

List<Map<String, dynamic>> _contentsOf(Map<String, dynamic> body) =>
    (body['contents'] as List)
        .map((c) => (c as Map).cast<String, dynamic>())
        .toList();

List<Map<String, dynamic>> _partsOf(Map<String, dynamic> content) =>
    (content['parts'] as List)
        .map((p) => (p as Map).cast<String, dynamic>())
        .toList();

void main() {
  group('gemma requests on the wire', () {
    test('folds the system message into the first user turn and sends no '
        'systemInstruction', () async {
      final body = await _onTheWire(
        model: 'gemma-3-4b-it',
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'be terse')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );
      expect(body, isNot(contains('systemInstruction')));
      final contents = _contentsOf(body);
      expect(contents, hasLength(1));
      expect(contents.first['role'], 'user');
      expect(_partsOf(contents.first).map((p) => p['text']), [
        'be terse',
        'hello',
      ]);
    });

    test('full ai.generate with system prompt folds it on the wire', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [_WirePlugin(captured)],
        promptDir: null,
        isDevEnv: false,
      );
      addTearDown(ai.shutdown);
      await ai.generate(
        model: modelRef('googleai/gemma-3-4b-it'),
        system: 'be terse',
        prompt: 'hello',
      );
      final body = captured.single;
      expect(body, isNot(contains('systemInstruction')));
      final texts = _contentsOf(
        body,
      ).expand(_partsOf).map((p) => p['text']).toList();
      expect(texts, ['be terse', 'hello']);
    });

    test('gemini models keep systemInstruction on the wire', () async {
      final body = await _onTheWire(
        model: 'gemini-2.0-flash',
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'be terse')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );
      expect(body['systemInstruction'], isNotNull);
      expect(_contentsOf(body), hasLength(1));
    });

    test('strips reasoning and thoughtSignature parts from multi-turn '
        'history', () async {
      final body = await _onTheWire(
        model: 'gemma-3-4b-it',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'question')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'thinking...'),
              TextPart(text: 'signed', metadata: {'thoughtSignature': 'sig'}),
              TextPart(text: 'answer'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'follow-up')],
          ),
        ],
      );
      final contents = _contentsOf(body);
      expect(contents, hasLength(3));
      final modelParts = _partsOf(contents[1]);
      expect(modelParts.map((p) => p['text']), ['answer']);
      expect(modelParts.every((p) => p['thought'] == null), isTrue);
      expect(modelParts.every((p) => p['thoughtSignature'] == null), isTrue);
    });

    test('passes in-range temperature through to generationConfig', () async {
      final body = await _onTheWire(
        model: 'gemma-3-4b-it',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        config: {'temperature': 0.9},
      );
      final generationConfig = (body['generationConfig'] as Map)
          .cast<String, dynamic>();
      expect(generationConfig['temperature'], 0.9);
    });

    test('rejects temperature above 1.0 before any request is sent', () async {
      final captured = <Map<String, dynamic>>[];
      final plugin = _WirePlugin(captured);
      final action = plugin.resolve('model', 'gemma-3-4b-it')!;
      await expectLater(
        () => action.run(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
            config: {'temperature': 1.5},
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
      expect(captured, isEmpty);
    });
  });
}
