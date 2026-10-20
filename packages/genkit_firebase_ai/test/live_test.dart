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

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/experimental.dart' show BidiModel;
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

void main() {
  group('toLiveGenerationConfig', () {
    test('leaves everything unset without a config', () {
      final config = toLiveGenerationConfig(null);

      expect(config.responseModalities, isNull);
      expect(config.speechConfig, isNull);
      expect(config.temperature, isNull);
    });

    test('does not throw when speechConfig has no voiceConfig', () {
      final config = toLiveGenerationConfig({'speechConfig': {}});

      expect(config.speechConfig, isNotNull);
      expect(_speechJson(config), isNot(contains('voice')));
    });

    test('maps every field', () {
      final config = toLiveGenerationConfig({
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': 'Kore'},
          },
        },
        'maxOutputTokens': 256,
        'temperature': 1,
        'topP': 0.9,
        'topK': 40,
        'presencePenalty': 0.1,
        'frequencyPenalty': 0.2,
      });

      expect(config.responseModalities, [fai.ResponseModalities.audio]);
      expect(_speechJson(config), contains('"Kore"'));
      expect(config.maxOutputTokens, 256);
      expect(config.temperature, 1.0);
      expect(config.topP, 0.9);
      expect(config.topK, 40);
      expect(config.presencePenalty, 0.1);
      expect(config.frequencyPenalty, 0.2);
    });
  });

  group('sendToLiveSession', () {
    Part media(String contentType) => MediaPart(
      media: Media(
        url: 'data:$contentType;base64,AAAA',
        contentType: contentType,
      ),
    );

    Future<List<String>> send(List<Part> content) async {
      final session = _FakeLiveSession();
      await sendToLiveSession(
        session,
        Message(role: Role.user, content: content),
      );
      return session.calls;
    }

    test('sends audio as realtime audio', () async {
      expect(await send([media('audio/pcm;rate=16000')]), ['audio']);
    });

    test('sends images and video as realtime video', () async {
      expect(await send([media('image/jpeg'), media('video/mp4')]), [
        'video',
        'video',
      ]);
    });

    test('sends other inline data and text as a client turn', () async {
      expect(await send([media('application/pdf'), TextPart(text: 'hi')]), [
        'send',
        'send',
      ]);
    });

    test('sends tool responses as tool responses', () async {
      final calls = await send([
        ToolResponsePart(
          toolResponse: ToolResponse(name: 'getWeather', output: 'sunny'),
        ),
      ]);

      expect(calls, ['toolResponse']);
    });
  });

  test('live models expose LiveGenerationConfig as their options', () {
    final model =
        firebaseAI().resolve(
              ActionType.bidiModel,
              'gemini-2.5-flash-native-audio-preview-12-2025',
            )
            as BidiModel;

    expect(model.customOptions, same(LiveGenerationConfig.$schema));
    expect(
      (model.metadata['model'] as Map)['customOptions'],
      isA<Map<String, dynamic>>(),
    );
  });
}

/// The encoded speech config of [config].
///
/// firebase_ai 3.8 only exposes the voice through `toJson`, which 3.13+ marks
/// `@internal` while adding a `voiceName` getter that 3.8 lacks.
String _speechJson(fai.LiveGenerationConfig config) =>
    // ignore: invalid_use_of_internal_member
    jsonEncode(config.speechConfig!.toJson());

/// Records which [fai.LiveSession] method each part was sent through.
class _FakeLiveSession implements fai.LiveSession {
  final calls = <String>[];

  @override
  Future<void> sendAudioRealtime(fai.InlineDataPart audio) async =>
      calls.add('audio');

  @override
  Future<void> sendVideoRealtime(fai.InlineDataPart video) async =>
      calls.add('video');

  @override
  Future<void> sendToolResponse(
    List<fai.FunctionResponse>? functionResponses,
  ) async => calls.add('toolResponse');

  @override
  Future<void> send({fai.Content? input, bool turnComplete = false}) async =>
      calls.add('send');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
