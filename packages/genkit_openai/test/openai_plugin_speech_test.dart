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
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/speech.dart'
    show isSpeechModel, speechModelInfo, speechModelRejectsSpeed;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Audio bytes the fake `/audio/speech` endpoint hands back. Kept tiny and
/// fixed so tests can assert on the exact base64 in the resulting data URL.
final Uint8List fakeAudio = Uint8List.fromList([1, 2, 3, 4]);

/// Captures every `/audio/speech` request body the plugin puts on the wire and
/// replies with raw audio bytes, so tests assert on the actual JSON sent
/// rather than on plugin internals.
MockClient speechWireClient(
  List<Map<String, dynamic>> capturedBodies, {
  String contentType = 'audio/mpeg',
}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            {
              'id': 'gpt-4o',
              'object': 'model',
              'created': 0,
              'owned_by': 'openai',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path.endsWith('/audio/speech')) {
      capturedBodies.add(
        (jsonDecode(request.body) as Map).cast<String, dynamic>(),
      );
      return http.Response.bytes(
        fakeAudio,
        200,
        headers: {'content-type': contentType},
      );
    }
    return http.Response('not found', 404);
  });
}

Genkit speechGenkit(List<Map<String, dynamic>> captured) => Genkit(
  plugins: [openAI(apiKey: 'test-key', httpClient: speechWireClient(captured))],
);

void main() {
  group('speech model classification', () {
    test('recognizes text-to-speech models', () {
      expect(isSpeechModel('tts-1'), isTrue);
      expect(isSpeechModel('tts-1-hd'), isTrue);
      expect(isSpeechModel('gpt-4o-mini-tts'), isTrue);
    });

    test('does not claim other audio models', () {
      // These all classify as 'audio' too, so the tts check is what keeps
      // transcription and realtime models out of the speech path.
      expect(getModelType('whisper-1'), 'audio');
      expect(isSpeechModel('whisper-1'), isFalse);
      expect(isSpeechModel('gpt-4o-transcribe'), isFalse);
      expect(isSpeechModel('gpt-4o-realtime-preview'), isFalse);
      expect(isSpeechModel('gpt-audio-1.5'), isFalse);
      expect(isSpeechModel('gpt-4o'), isFalse);
    });

    test('only gpt-4o-mini-tts rejects speed', () {
      expect(speechModelRejectsSpeed('gpt-4o-mini-tts'), isTrue);
      expect(speechModelRejectsSpeed('tts-1'), isFalse);
      expect(speechModelRejectsSpeed('tts-1-hd'), isFalse);
    });

    test('advertises media output and nothing conversational', () {
      final supports = speechModelInfo('tts-1').supports!;
      expect(supports['output'], ['media']);
      expect(supports['media'], isFalse);
      expect(supports['multiturn'], isFalse);
      expect(supports['systemRole'], isFalse);
      expect(supports['tools'], isFalse);
    });
  });

  group('speech wire-level request assembly', () {
    test('sends only model, input and voice by default', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await ai.generate(model: openAI.speechModel('tts-1'), prompt: 'Hello');

      expect(captured, hasLength(1));
      expect(captured.single, {
        'model': 'tts-1',
        'input': 'Hello',
        'voice': 'alloy',
      });

      await ai.shutdown();
    });

    test('voice and instructions reach the wire', () async {
      // The SDK's SpeechRequest caps voice at six legacy values and has no
      // instructions field at all; this asserts the toJson override that
      // works around both.
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await ai.generate(
        model: openAI.speechModel('gpt-4o-mini-tts'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(
          voice: 'sage',
          instructions: 'Speak in a calm, warm tone.',
        ),
      );

      final body = captured.single;
      expect(body['voice'], 'sage');
      expect(body['instructions'], 'Speak in a calm, warm tone.');

      await ai.shutdown();
    });

    test('speed is sent for tts-1 but dropped for gpt-4o-mini-tts', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(speed: 1.5),
      );
      expect(captured.single['speed'], 1.5);

      captured.clear();
      await ai.generate(
        model: openAI.speechModel('gpt-4o-mini-tts'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(speed: 1.5),
      );
      expect(
        captured.single.containsKey('speed'),
        isFalse,
        reason: 'gpt-4o-mini-tts rejects the speed parameter outright',
      );

      await ai.shutdown();
    });

    test('version overrides the model id on the wire', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(version: 'tts-1-1106'),
      );

      expect(captured.single['model'], 'tts-1-1106');

      await ai.shutdown();
    });

    test('response_format is omitted unless requested', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await ai.generate(model: openAI.speechModel('tts-1'), prompt: 'Hello');
      expect(captured.single.containsKey('response_format'), isFalse);

      captured.clear();
      await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(responseFormat: 'wav'),
      );
      expect(captured.single['response_format'], 'wav');

      await ai.shutdown();
    });
  });

  group('speech response conversion', () {
    test('returns a single audio media part as a base64 data URL', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      final response = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Hello',
      );

      final content = response.message!.content;
      expect(content, hasLength(1));
      final media = response.media!;
      expect(media.contentType, 'audio/mpeg');
      expect(media.url, 'data:audio/mpeg;base64,${base64Encode(fakeAudio)}');
      expect(media.url, 'data:audio/mpeg;base64,AQIDBA==');
      expect(response.finishReason, FinishReason.stop);

      await ai.shutdown();
    });

    test('content type follows the requested response format', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      final response = await ai.generate(
        model: openAI.speechModel('tts-1'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(responseFormat: 'wav'),
      );

      expect(response.media!.contentType, 'audio/wav');
      expect(response.media!.url, startsWith('data:audio/wav;base64,'));

      await ai.shutdown();
    });
  });

  group('speech model registration', () {
    test('known speech models register even when /models omits them', () async {
      // The fake /models endpoint only advertises gpt-4o, mirroring the fact
      // that OpenAI does not reliably list TTS models.
      final ai = speechGenkit([]);

      final actions = await ai.registry.listActions();
      final names = actions
          .where((a) => a.actionType == .model)
          .map((a) => a.name)
          .toSet();

      expect(
        names,
        containsAll([
          'openai/tts-1',
          'openai/tts-1-hd',
          'openai/gpt-4o-mini-tts',
        ]),
      );

      await ai.shutdown();
    });

    test('registered speech models carry media-output metadata', () async {
      final ai = speechGenkit([]);

      final action = await ai.registry.lookupAction(
        .model,
        'openai/gpt-4o-mini-tts',
      );

      expect(action, isNotNull);
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      final supports = (info['supports'] as Map).cast<String, dynamic>();
      expect(supports['output'], ['media']);
      expect(supports['multiturn'], isFalse);

      await ai.shutdown();
    });

    test('an unlisted tts model still resolves as a speech model', () async {
      // resolve() must route by name, so a future model works without a
      // plugin release.
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      final response = await ai.generate(
        model: openAI.speechModel('tts-9-ultra'),
        prompt: 'Hello',
      );

      expect(captured.single['model'], 'tts-9-ultra');
      expect(response.media, isNotNull);

      await ai.shutdown();
    });

    test('chat models are untouched by speech routing', () async {
      final ai = speechGenkit([]);

      final action = await ai.registry.lookupAction(.model, 'openai/gpt-4o');
      expect(action, isNotNull);
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      final supports = (info['supports'] as Map).cast<String, dynamic>();
      expect(supports['multiturn'], isTrue);
      expect(supports.containsKey('output'), isFalse);

      await ai.shutdown();
    });
  });

  group('custom speech models from compatible providers', () {
    test('a custom model declaring media output is routed to speech', () async {
      // A provider whose speech model is not named '*tts*'. The declared
      // supports.output is the only signal that it generates audio.
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'voicecorp',
            apiKey: 'test-key',
            baseUrl: 'https://api.voicecorp.test/v1',
            httpClient: speechWireClient(captured),
            models: [
              CustomModelDefinition(
                name: 'voicebox-1',
                info: ModelInfo(
                  label: 'Voicebox 1',
                  supports: {
                    'output': ['media'],
                  },
                ),
              ),
            ],
          ),
        ],
      );

      final response = await ai.generate(
        model: openAI.speechModel('voicebox-1', namespace: 'voicecorp'),
        prompt: 'Hello',
        config: OpenAISpeechOptions(voice: 'sage'),
      );

      expect(
        captured,
        hasLength(1),
        reason: 'must hit /audio/speech, not /chat/completions',
      );
      expect(captured.single['model'], 'voicebox-1');
      expect(response.media, isNotNull);

      await ai.shutdown();
    });

    test('a custom text model is still routed to chat', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'textcorp',
            apiKey: 'test-key',
            baseUrl: 'https://api.textcorp.test/v1',
            httpClient: speechWireClient(captured),
            models: [
              CustomModelDefinition(
                name: 'chatbox-1',
                info: ModelInfo(
                  label: 'Chatbox 1',
                  supports: {
                    'output': ['text'],
                  },
                ),
              ),
            ],
          ),
        ],
      );

      final action = await ai.registry.lookupAction(
        .model,
        'textcorp/chatbox-1',
      );
      final info = (action!.metadata['model'] as Map).cast<String, dynamic>();
      expect((info['supports'] as Map)['output'], ['text']);
      expect(captured, isEmpty);

      await ai.shutdown();
    });
  });

  group('speech input validation', () {
    test('rejects a blank prompt before hitting the network', () async {
      final captured = <Map<String, dynamic>>[];
      final ai = speechGenkit(captured);

      await expectLater(
        ai.generate(model: openAI.speechModel('tts-1'), prompt: '   '),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
      expect(captured, isEmpty);

      await ai.shutdown();
    });
  });
}
