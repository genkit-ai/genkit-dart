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
      expect(config.speechConfig!.voiceName, isNull);
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
      expect(config.speechConfig!.voiceName, 'Kore');
      expect(config.maxOutputTokens, 256);
      expect(config.temperature, 1.0);
      expect(config.topP, 0.9);
      expect(config.topK, 40);
      expect(config.presencePenalty, 0.1);
      expect(config.frequencyPenalty, 0.2);
    });

    test('reports a field of the wrong type as an invalid argument', () {
      expect(
        () => toLiveGenerationConfig({'temperature': '0.7'}),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
    });

    test('reports an unknown response modality as an invalid argument', () {
      expect(
        () => toLiveGenerationConfig({
          'responseModalities': ['SMELL'],
        }),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('LiveSender', () {
    Message text(String t) => Message(
      role: Role.user,
      content: [TextPart(text: t)],
    );

    test('sends messages in the order they were added', () async {
      final session = _SlowLiveSession();
      final sender = LiveSender(session)
        ..add([text('one'), text('two')])
        ..add([text('three')]);

      await sender.flush();

      expect(session.sent, ['one', 'two', 'three']);
    });

    test('flushing before close sends what was queued', () async {
      final session = _SlowLiveSession();
      final sender = LiveSender(session)..add([text('last')]);

      await sender.flush();
      await sender.close();

      expect(session.sent, ['last']);
      expect(session.closeCalls, 1);
      expect(sender.closed, isTrue);
    });

    test('a failure closes the session and stops later sends', () async {
      final session = _SlowLiveSession(failOn: 'bad');
      final sender = LiveSender(session)
        ..add([text('ok'), text('bad'), text('never')])
        ..add([text('also never')]);

      await sender.flush();

      expect(session.sent, ['ok']);
      expect(sender.failure?.$1, isA<StateError>());
      expect(sender.closed, isTrue);
      expect(session.closeCalls, 1);
    });

    test('nothing is sent after close', () async {
      final session = _SlowLiveSession();
      final sender = LiveSender(session);

      await sender.close();
      sender.add([text('late')]);
      await sender.flush();
      await sender.close();

      expect(session.sent, isEmpty);
      expect(session.closeCalls, 1);
    });
  });

  group('receiveLiveSession', () {
    final text = fai.LiveServerContent(
      modelTurn: fai.Content.model([fai.TextPart('hi')]),
    );

    test('forwards events until the plugin closes the session', () async {
      final session = _ReceivingLiveSession([
        fai.LiveServerResponse(message: text),
      ]);
      final chunks = <ModelResponseChunk>[];

      await receiveLiveSession(session, chunks.add, closedByPlugin: () => true);

      expect(chunks.single.content.single.text, 'hi');
      expect(session.receiveCalls, 1);
    });

    test('a server close the plugin did not ask for is an error', () async {
      final session = _ReceivingLiveSession(
        [],
        closedWith:
            'WebSocket Closed, closeCode: 1007, closeReason: '
            'API key not valid. Please pass a valid API key.',
      );

      await expectLater(
        receiveLiveSession(session, (_) {}, closedByPlugin: () => false),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('API key not valid'),
          ),
        ),
      );
      expect(session.receiveCalls, 2);
    });

    test('a receive error is reported, not swallowed', () async {
      final session = _ReceivingLiveSession([], error: StateError('boom'));

      await expectLater(
        receiveLiveSession(session, (_) {}, closedByPlugin: () => true),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('sendToLiveSession', () {
    Part media(String contentType) => MediaPart(
      media: Media(
        url: 'data:$contentType;base64,AAAA',
        contentType: contentType,
      ),
    );

    Future<List<String>> send(
      List<Part> content, {
      Role role = Role.user,
    }) async {
      final session = _FakeLiveSession();
      await sendToLiveSession(session, Message(role: role, content: content));
      return session.calls;
    }

    test('sends audio as realtime audio', () async {
      expect(await send([media('audio/pcm;rate=16000')]), ['audio']);
    });

    test(
      'reads the media type from the data URL without a content type',
      () async {
        final session = _FakeLiveSession();
        final part = MediaPart(
          media: Media(url: 'data:audio/pcm;rate=16000;base64,AAAA'),
        );

        await sendToLiveSession(
          session,
          Message(role: Role.user, content: [part]),
        );

        expect(session.calls, ['audio']);
        expect(session.lastAudio!.mimeType, 'audio/pcm;rate=16000');
      },
    );

    test('sends images and video as realtime video', () async {
      expect(await send([media('image/jpeg'), media('video/mp4')]), [
        'video',
        'video',
      ]);
    });

    test('sends other inline data and text as one complete turn', () async {
      expect(await send([media('application/pdf'), TextPart(text: 'hi')]), [
        'turn(parts: 2, turnComplete: true)',
      ]);
    });

    test('sends an image that comes with text inside the turn', () async {
      expect(
        await send([TextPart(text: 'what is this?'), media('image/jpeg')]),
        ['turn(parts: 2, turnComplete: true)'],
      );
    });

    test('keeps audio realtime next to text', () async {
      expect(await send([media('audio/pcm'), TextPart(text: 'hi')]), [
        'audio',
        'turn(parts: 1, turnComplete: true)',
      ]);
    });

    test('sends media in model messages inside the turn', () async {
      expect(
        await send([media('audio/pcm'), media('image/jpeg')], role: Role.model),
        ['turn(parts: 2, turnComplete: true)'],
      );
    });

    test('sends no turn when every part is realtime', () async {
      expect(await send([media('audio/pcm')]), ['audio']);
    });

    test('sends tool responses as tool responses', () async {
      final calls = await send([
        ToolResponsePart(
          toolResponse: ToolResponse(name: 'getWeather', output: 'sunny'),
        ),
      ]);

      expect(calls, ['toolResponses(1)']);
    });

    test('sends parallel tool responses together', () async {
      final calls = await send([
        ToolResponsePart(
          toolResponse: ToolResponse(name: 'getWeather', output: 'sunny'),
        ),
        ToolResponsePart(
          toolResponse: ToolResponse(name: 'getTime', output: 'noon'),
        ),
      ]);

      expect(calls, ['toolResponses(2)']);
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

/// Records which [fai.LiveSession] method each part was sent through.
class _FakeLiveSession implements fai.LiveSession {
  final calls = <String>[];
  fai.InlineDataPart? lastAudio;

  @override
  Future<void> sendAudioRealtime(fai.InlineDataPart audio) async {
    lastAudio = audio;
    calls.add('audio');
  }

  @override
  Future<void> sendVideoRealtime(fai.InlineDataPart video) async =>
      calls.add('video');

  @override
  Future<void> sendToolResponse(
    List<fai.FunctionResponse>? functionResponses,
  ) async => calls.add('toolResponses(${functionResponses?.length})');

  @override
  Future<void> send({fai.Content? input, bool turnComplete = false}) async =>
      calls.add(
        'turn(parts: ${input?.parts.length}, turnComplete: $turnComplete)',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A session whose first `receive()` yields [events] (then [error], if set),
/// and whose later calls throw [closedWith], as firebase_ai does once the
/// server has closed the socket.
class _ReceivingLiveSession implements fai.LiveSession {
  _ReceivingLiveSession(this.events, {this.error, this.closedWith});

  final List<fai.LiveServerResponse> events;
  final Error? error;
  final String? closedWith;
  int receiveCalls = 0;

  @override
  Stream<fai.LiveServerResponse> receive() async* {
    receiveCalls++;
    if (receiveCalls > 1) {
      if (closedWith case final reason?) throw Exception(reason);
      return;
    }
    yield* Stream.fromIterable(events);
    if (error case final error?) throw error;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records sent turn text, yielding between sends as a real socket write
/// can, and throws a [StateError] for the text [failOn].
class _SlowLiveSession implements fai.LiveSession {
  _SlowLiveSession({this.failOn});

  final String? failOn;
  final sent = <String>[];
  int closeCalls = 0;

  @override
  Future<void> send({fai.Content? input, bool turnComplete = false}) async {
    await Future<void>.delayed(Duration.zero);
    final text = (input!.parts.single as fai.TextPart).text;
    if (text == failOn) throw StateError('socket closed');
    sent.add(text);
  }

  @override
  Future<void> close() async => closeCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
