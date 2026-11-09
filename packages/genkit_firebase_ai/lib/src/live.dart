// Copyright 2025 Google LLC
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
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';

import '../genkit_firebase_ai.dart';
import 'converters.dart';
import 'error_mapping.dart';

final _logger = Logger('genkit_firebase_ai');

/// Runs a connected Live [session] until it ends: sends [history], then
/// the messages of each [input] request in order, and forwards what the
/// session returns to [onChunk].
///
/// Throws a [GenkitException] when sending or receiving fails, or when the
/// server closed the session, and a [CancelledException] once [cancel] is
/// cancelled.
Future<void> runLiveSession(
  fai.LiveSession session, {
  required Iterable<Message> history,
  required Stream<ModelRequest> input,
  required void Function(ModelResponseChunk) onChunk,
  CancellationToken? cancel,
}) async {
  final sender = LiveSender(session);
  // Closing through the sender marks the close as the plugin's, so it is not
  // reported as the server ending the session.
  final disposeCancel = cancel?.onCancel(sender.close);
  // Listen before anything can throw: closing a bidi stream waits for its
  // input to be listened to and cancelled.
  final sub = input.listen(
    (request) => sender.add(request.messages),
    onError: (e) {
      _logger.severe('InputStream error', e);
    },
    onDone: () async {
      _logger.info('InputStream done');
      // Let messages already queued go out before closing.
      await sender.flush();
      await sender.close();
    },
  );

  try {
    // A cancel during connect() closes the session at once; stop here rather
    // than send history to it.
    cancel?.throwIfCancelled();
    sender.add(history);
    await sender.flush();
    await receiveLiveSession(
      session,
      onChunk,
      closedByPlugin: () => sender.closed,
    );
  } finally {
    disposeCancel?.call();
    await sub.cancel();
    _logger.fine('Closing session');
    await sender.close();
  }
  if (sender.failure case (final e, final stack)) {
    throw toGenkitException(e, stack);
  }
  // A cancel closes the session through the sender, which ends the receive
  // loop as if the session finished normally.
  cancel?.throwIfCancelled();
}

/// Builds the Firebase AI Live config from a request's `config`, read through
/// [LiveGenerationConfig] so missing fields fall back to the SDK defaults.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] when a field
/// has the wrong type or an unknown value.
fai.LiveGenerationConfig toLiveGenerationConfig(Map<String, dynamic>? config) {
  try {
    return _toLiveGenerationConfig(config);
  } on GenkitException {
    rethrow;
  } catch (e) {
    throw GenkitException(
      'Invalid Live model config: $e',
      status: StatusCode.invalidArgument,
    );
  }
}

fai.LiveGenerationConfig _toLiveGenerationConfig(Map<String, dynamic>? config) {
  // The JSON round trip types nested maps written as Dart literals (e.g. an
  // empty `{}`) the way the generated getters expect.
  final options = config == null
      ? LiveGenerationConfig()
      : LiveGenerationConfig.$schema.parse(jsonDecode(jsonEncode(config)));
  if (options.stopSequences?.isNotEmpty ?? false) {
    _logger.warning(
      'stopSequences is not supported by Firebase AI Live models and is '
      'ignored.',
    );
  }
  final speechConfig = options.speechConfig;
  return fai.LiveGenerationConfig(
    responseModalities: options.responseModalities
        ?.map((e) => fai.ResponseModalities.values.byName(e.toLowerCase()))
        .toList(),
    speechConfig: toGeminiSpeechConfig(speechConfig),
    maxOutputTokens: options.maxOutputTokens,
    temperature: options.temperature,
    topP: options.topP,
    topK: options.topK,
    presencePenalty: options.presencePenalty,
    frequencyPenalty: options.frequencyPenalty,
  );
}

/// Sends messages to a Live session one at a time, in the order they were
/// added.
///
/// Input chunks arrive faster than they are sent, so without the queue their
/// parts could interleave on the socket. The first failure closes the session
/// and is kept in [failure]; nothing is sent after it, or after [close].
class LiveSender {
  LiveSender(this._session);

  final fai.LiveSession _session;
  Future<void> _pending = Future.value();

  /// The first failure to send, which ended the session.
  (Object, StackTrace)? get failure => _failure;
  (Object, StackTrace)? _failure;

  /// Whether the plugin closed the session.
  bool get closed => _closed;
  bool _closed = false;

  /// Queues [messages] after everything added before.
  void add(Iterable<Message> messages) {
    final batch = messages.toList();
    _pending = _pending.then((_) => _send(batch));
  }

  /// Completes once every message added so far has been sent or dropped.
  Future<void> flush() => _pending;

  /// Closes the session. Messages still queued are dropped.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _session.close();
  }

  Future<void> _send(List<Message> messages) async {
    for (final msg in messages) {
      if (_closed) return;
      try {
        await sendToLiveSession(_session, msg);
      } catch (e, stack) {
        // A write cut short by close() fails too, but that is not an error.
        if (!_closed) _failure ??= (e, stack);
        await close();
        return;
      }
    }
  }
}

/// Forwards [session]'s events to [onChunk] until it ends.
///
/// Throws a [GenkitException] when receiving fails, or when the server closed
/// the session without the plugin asking ([closedByPlugin] false), for
/// example after rejecting the API key. `firebase_ai` ends `receive()`
/// quietly on a server close and reports the reason only on the next call.
Future<void> receiveLiveSession(
  fai.LiveSession session,
  void Function(ModelResponseChunk) onChunk, {
  required bool Function() closedByPlugin,
}) async {
  try {
    await for (final event in session.receive()) {
      _logger.fine('Session receive loop: $event');
      if (_fromGeminiLiveEvent(event) case final chunk?) onChunk(chunk);
    }
    if (!closedByPlugin()) {
      await session.receive().drain<void>();
    }
  } catch (e, stack) {
    throw toGenkitException(e, stack);
  }
}

/// Sends [msg] to a Live [session].
///
/// Only a user's media can be realtime input: audio always goes out as
/// realtime audio, and images or video as realtime video frames when the
/// message has nothing else to say. That is how the Live API takes camera
/// input, so a message with only an image is a frame and does not start a turn
/// on its own; send text with it to ask about it. Media sent alongside text,
/// and media in model messages (history), go inside the turn instead. All tool responses go
/// out together, and the remaining parts as one complete client turn, so the
/// model does not answer before the whole message is in.
///
/// Realtime input has no media resolution, so a `metadata.mediaResolution` on
/// a part sent that way is dropped, with a warning.
///
/// Throws a [GenkitException] with [StatusCode.invalidArgument] for a system
/// message, which a session takes only in its initial request.
Future<void> sendToLiveSession(fai.LiveSession session, Message msg) async {
  _logger.fine('Sending message: ${msg.role} parts: ${msg.content.length}');
  if (msg.role == Role.system) {
    // The system instruction is fixed when the session is set up, and sending
    // the text as a user turn would change what it means.
    throw GenkitException(
      'A Live session takes system messages only in its initial request.',
      status: StatusCode.invalidArgument,
    );
  }

  final parts = msg.content.map(toGeminiPart).toList();
  final toolResponses = parts.whereType<fai.FunctionResponse>().toList();
  final otherParts = parts.where((p) => p is! fai.FunctionResponse).toList();
  final isUser = msg.role == Role.user;
  final framesOnly = otherParts.every(_isRealtimeMedia);
  final turnParts = <fai.Part>[];

  void warnIfResolutionDropped(fai.InlineDataPart part) {
    if (part.mediaResolution != null) {
      _logger.warning(
        'metadata.mediaResolution is not sent with Live realtime input; '
        'ignoring it for ${part.mimeType}.',
      );
    }
  }

  try {
    for (final part in otherParts) {
      switch (part) {
        case fai.InlineDataPart(:final mimeType)
            when isUser && mimeType.startsWith('audio/'):
          warnIfResolutionDropped(part);
          await session.sendAudioRealtime(part);
        case fai.InlineDataPart() when isUser && framesOnly:
          warnIfResolutionDropped(part);
          await session.sendVideoRealtime(part);
        default:
          turnParts.add(part);
      }
    }
    if (toolResponses.isNotEmpty) {
      await session.sendToolResponse(toolResponses);
    }
    if (turnParts.isNotEmpty) {
      await session.send(
        input: fai.Content(toGeminiRole(msg.role), turnParts),
        turnComplete: true,
      );
    }
  } catch (e) {
    _logger.severe('Error sending ${msg.role} message to the Live session', e);
    rethrow;
  }
}

/// Whether [part] is audio, image or video data that can go out as realtime
/// input.
bool _isRealtimeMedia(fai.Part part) =>
    part is fai.InlineDataPart &&
    (part.mimeType.startsWith('audio/') ||
        part.mimeType.startsWith('image/') ||
        part.mimeType.startsWith('video/'));

ModelResponseChunk? _fromGeminiLiveEvent(fai.LiveServerResponse event) {
  final liveParts = event.message is fai.LiveServerContent
      ? (event.message as fai.LiveServerContent).modelTurn?.parts
      : event.message is fai.LiveServerToolCall
      ? (event.message as fai.LiveServerToolCall).functionCalls
            as List<fai.Part>
      : null;
  if (liveParts == null) return null;
  // We only care about content updates for now
  final parts = liveParts.map(fromGeminiPart).toList();

  return ModelResponseChunk(index: 0, content: parts);
}
