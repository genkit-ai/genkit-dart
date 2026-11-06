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

import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/experimental.dart' show BidiModel;
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:genkit_firebase_ai/src/live.dart';
import 'package:logging/logging.dart';

void main() {
  group('toLiveGenerationConfig', () {
    test('leaves everything unset without a config', () {
      final config = toLiveGenerationConfig(null);

      expect(config.responseModalities, isNull);
      expect(config.speechConfig, isNull);
      expect(config.toJson(), isNot(contains('temperature')));
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
          'languageCode': 'en-GB',
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
      expect(config.speechConfig!.languageCode, 'en-GB');
      expect(config.maxOutputTokens, 256);
      // The sampling getters are deprecated from firebase_ai 5 (#596), so
      // check the wire form instead.
      expect(
        config.toJson(),
        allOf(
          containsPair('temperature', 1.0),
          containsPair('topP', 0.9),
          containsPair('topK', 40),
          containsPair('presencePenalty', 0.1),
          containsPair('frequencyPenalty', 0.2),
        ),
      );
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

    test('reports a bad speechConfig without wrapping it again', () {
      expect(
        () => toLiveGenerationConfig({
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Kore'},
            },
            'multiSpeakerVoiceConfig': {'speakerVoiceConfigs': []},
          },
        }),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            startsWith('speechConfig cannot set both'),
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

    test('a write cut short by close is not a failure', () async {
      final session = _SlowLiveSession();
      final sender = LiveSender(session)..add([text('cut short')]);

      await session.writing.future;
      await sender.close();
      await sender.flush();

      expect(session.sent, isEmpty);
      expect(sender.failure, isNull);
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
          isA<GenkitException>()
              .having(
                (e) => e.message,
                'message',
                contains('API key not valid'),
              )
              // A rejected setup is not retried.
              .having((e) => e.status, 'status', StatusCode.invalidArgument),
        ),
      );
      expect(session.receiveCalls, 2);
    });

    test('a server close for another reason stays INTERNAL', () async {
      final session = _ReceivingLiveSession(
        [],
        closedWith:
            'WebSocket Closed, closeCode: 1011, closeReason: Internal error.',
      );

      await expectLater(
        receiveLiveSession(session, (_) {}, closedByPlugin: () => false),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.internal,
          ),
        ),
      );
    });

    // firebase_ai replaces the whole close message for these two reasons.
    for (final (reason, status) in [
      (
        'The current live session has expired. Please start a new session.',
        StatusCode.deadlineExceeded,
      ),
      (
        'You have exceeded the maximum number of concurrent sessions. '
            'Please close other sessions and try again later.',
        StatusCode.resourceExhausted,
      ),
    ]) {
      test('a server close reported as "$reason" is ${status.name}', () async {
        final session = _ReceivingLiveSession([], closedWith: reason);

        await expectLater(
          receiveLiveSession(session, (_) {}, closedByPlugin: () => false),
          throwsA(
            isA<GenkitException>().having((e) => e.status, 'status', status),
          ),
        );
      });
    }

    test('a receive error is reported, not swallowed', () async {
      final session = _ReceivingLiveSession([], error: StateError('boom'));

      await expectLater(
        receiveLiveSession(session, (_) {}, closedByPlugin: () => true),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('runLiveSession', () {
    Message text(String t) => Message(
      role: Role.user,
      content: [TextPart(text: t)],
    );

    test('sends the history, then the input, before closing', () async {
      final session = _SlowLiveSession();
      final input = StreamController<ModelRequest>()
        ..add(ModelRequest(messages: [text('last')]));
      unawaited(input.close());

      await runLiveSession(
        session,
        history: [text('first')],
        input: input.stream,
        onChunk: (_) {},
      );

      expect(session.sent, ['first', 'last']);
      expect(session.closeCalls, 1);
    });

    test('a send failure ends the session with that error', () async {
      final session = _SlowLiveSession(failOn: 'bad');
      final input = StreamController<ModelRequest>()
        ..add(ModelRequest(messages: [text('bad')]));

      await expectLater(
        runLiveSession(
          session,
          history: const [],
          input: input.stream,
          onChunk: (_) {},
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.cause,
            'cause',
            isA<StateError>(),
          ),
        ),
      );
      expect(session.closeCalls, 1);
      await input.close();
    });

    test(
      'cancelling closes the session and throws CancelledException',
      () async {
        final session = _SlowLiveSession();
        final input = StreamController<ModelRequest>();
        final controller = CancellationController();

        final run = runLiveSession(
          session,
          history: [text('hi')],
          input: input.stream,
          onChunk: (_) {},
          cancel: controller.token,
        );
        await session.writing.future;
        controller.cancel('user pressed stop');

        await expectLater(run, throwsA(isA<CancelledException>()));
        expect(session.closeCalls, 1);
        await input.close();
      },
    );

    test('an already-cancelled token sends nothing', () async {
      final session = _SlowLiveSession();
      final input = StreamController<ModelRequest>();
      final controller = CancellationController()..cancel();

      await expectLater(
        runLiveSession(
          session,
          history: [text('hi')],
          input: input.stream,
          onChunk: (_) {},
          cancel: controller.token,
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(session.sent, isEmpty);
      expect(session.receiveCalls, 0);
      expect(session.closeCalls, 1);
      // Core's BidiActionStream.close() waits on this.
      await input.close().timeout(const Duration(seconds: 1));
    });
  });

  group('sendToLiveSession', () {
    test('rejects a system message', () async {
      final session = _FakeLiveSession();

      await expectLater(
        sendToLiveSession(
          session,
          Message(
            role: Role.system,
            content: [TextPart(text: 'Be terse.')],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
      expect(session.calls, isEmpty);
    });

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

    test('warns that realtime input drops a part mediaResolution', () async {
      final warnings = <String>[];
      final sub = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(sub.cancel);
      final session = _FakeLiveSession();
      Part media(String contentType) => MediaPart(
        media: Media(
          url: 'data:$contentType;base64,AAAA',
          contentType: contentType,
        ),
        metadata: {'mediaResolution': 'MEDIA_RESOLUTION_LOW'},
      );

      await sendToLiveSession(
        session,
        Message(role: Role.user, content: [media('image/jpeg')]),
      );
      await sendToLiveSession(
        session,
        Message(role: Role.user, content: [media('audio/pcm;rate=16000')]),
      );
      await sendToLiveSession(
        session,
        Message(
          role: Role.user,
          content: [
            media('image/jpeg'),
            TextPart(text: 'what?'),
          ],
        ),
      );

      expect(session.calls, [
        'video',
        'audio',
        'turn(parts: 2, turnComplete: true)',
      ]);
      expect(warnings, [
        allOf(
          contains('not sent with Live realtime input'),
          contains('image/jpeg'),
        ),
        allOf(
          contains('not sent with Live realtime input'),
          contains('audio/pcm'),
        ),
      ]);
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

  test('a Live system message with a non-text part fails before '
      'connecting', () async {
    final model =
        firebaseAI().resolve(
              ActionType.bidiModel,
              'gemini-3.1-flash-live-preview',
            )
            as BidiModel;

    final session = model.streamBidi(
      init: ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'Be brief')],
          ),
          Message(
            role: Role.system,
            content: [
              MediaPart(
                media: Media(url: 'gs://b/f.png', contentType: 'image/png'),
              ),
            ],
          ),
        ],
      ),
    );

    await expectLater(
      session,
      emitsError(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.invalidArgument,
        ),
      ),
    );
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
/// can, and throws a [StateError] for the text [failOn] or for a write the
/// session was closed during. Its `receive()` ends once it is closed.
class _SlowLiveSession implements fai.LiveSession {
  _SlowLiveSession({this.failOn});

  final String? failOn;
  final sent = <String>[];
  int closeCalls = 0;
  int receiveCalls = 0;
  final _closed = Completer<void>();

  /// Completes when the first write starts.
  final writing = Completer<void>();

  @override
  Future<void> send({fai.Content? input, bool turnComplete = false}) async {
    if (!writing.isCompleted) writing.complete();
    await Future<void>.delayed(Duration.zero);
    if (closeCalls > 0) {
      throw StateError('Cannot add event after closing.');
    }
    final text = (input!.parts.single as fai.TextPart).text;
    if (text == failOn) throw StateError('socket closed');
    sent.add(text);
  }

  @override
  Stream<fai.LiveServerResponse> receive() async* {
    receiveCalls++;
    await _closed.future;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    if (!_closed.isCompleted) _closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
