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
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:http/http.dart' as http;

import 'wire_harness.dart';

/// Hangs every request until its `abortTrigger` fires, as `IOClient` would
/// with a slow server. Streaming requests get [firstChunk] first.
class _HangingClient extends WireClient {
  _HangingClient({this.firstChunk});

  final Map<String, dynamic>? firstChunk;

  final sent = Completer<void>();
  bool aborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(CapturedRequest(request.url, request.headers, const {}));
    final trigger = switch (request) {
      http.Abortable(:final abortTrigger?) => abortTrigger,
      _ => Completer<void>().future,
    };
    final abort = trigger.then<Never>((_) {
      aborted = true;
      throw http.RequestAbortedException(request.url);
    });
    if (!sent.isCompleted) sent.complete();
    if (firstChunk case final chunk?) {
      final body = StreamController<List<int>>();
      body.add(utf8.encode('data: ${jsonEncode(chunk)}\r\n\r\n'));
      unawaited(abort.then<void>((_) {}, onError: body.addError));
      return http.StreamedResponse(body.stream, 200);
    }
    return abort;
  }
}

/// Ignores `abortTrigger`, as any client that is not [http.Abortable]-aware
/// does, and serves as [WireClient] once [onSend] has run.
class _UnabortableClient extends WireClient {
  _UnabortableClient({
    super.response,
    super.streamChunks,
    super.statusCode,
    this.onSend,
  });

  final void Function()? onSend;

  /// The `abortTrigger` of each request.
  final triggers = <Future<void>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request case http.Abortable(:final abortTrigger?)) {
      triggers.add(abortTrigger);
    }
    onSend?.call();
    return super.send(request);
  }
}

void main() {
  setUpAll(setUpFirebaseApp);

  Future<GenerateResult> generate(
    WireClient client,
    CancellationToken cancel, {
    void Function(GenerateResponseChunk)? onChunk,
  }) {
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);
    return ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      prompt: 'hello',
      cancel: cancel,
      onChunk: onChunk,
    );
  }

  test('cancelling aborts the in-flight request', () async {
    final client = _HangingClient();
    final controller = CancellationController();

    final result = generate(client, controller.token);
    await client.sent.future;
    controller.cancel('user pressed stop');

    final response = await result;
    expect(client.aborted, isTrue);
    expect(response.finishReason, FinishReason.aborted);
  });

  test('cancelling aborts an in-flight stream', () async {
    final client = _HangingClient(firstChunk: textResponse('Hel'));
    final controller = CancellationController();
    final chunks = <String>[];

    final result = generate(
      client,
      controller.token,
      onChunk: (chunk) {
        chunks.add(chunk.text);
        controller.cancel();
      },
    );

    final response = await result;
    expect(chunks, ['Hel']);
    expect(client.aborted, isTrue);
    expect(response.finishReason, FinishReason.aborted);
  });

  test('an already-cancelled token sends nothing', () async {
    final client = WireClient();
    final controller = CancellationController()..cancel();

    final response = await generate(client, controller.token);

    expect(client.requests, isEmpty);
    expect(response.finishReason, FinishReason.aborted);
  });

  group('without an abort', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ],
    );
    final isCancelled = throwsA(isA<CancelledException>());

    test('a cancel just before the request sends nothing', () async {
      final client = WireClient();
      final controller = CancellationController();

      await expectLater(
        wireModel(client).run(
          request,
          cancel: controller.token,
          // The last thing that runs after core's own check.
          onTraceStart: ({required traceId, required spanId}) =>
              controller.cancel(),
        ),
        isCancelled,
      );
      expect(client.requests, isEmpty);
    });

    test('a cancel during a request drops the response', () async {
      final controller = CancellationController();
      final client = _UnabortableClient(onSend: controller.cancel);

      await expectLater(
        wireModel(client).run(request, cancel: controller.token),
        isCancelled,
      );
      expect(client.requests, hasLength(1));
    });

    test('a cancel during a stream drops the later chunks', () async {
      final controller = CancellationController();
      final client = _UnabortableClient(
        streamChunks: [textResponse('Hel'), textResponse('lo')],
      );
      final chunks = <String>[];

      await expectLater(
        wireModel(client).run(
          request,
          cancel: controller.token,
          onChunk: (chunk) {
            chunks.add(chunk.text);
            controller.cancel();
          },
        ),
        isCancelled,
      );
      expect(chunks, ['Hel']);
    });

    test('a cancel on the last chunk still cancels', () async {
      final controller = CancellationController();
      final client = _UnabortableClient(streamChunks: [textResponse('Hello')]);

      await expectLater(
        wireModel(client).run(
          request,
          cancel: controller.token,
          onChunk: (_) => controller.cancel(),
        ),
        isCancelled,
      );
    });
  });

  test('an aborted request reports the cancel and its reason', () async {
    final client = _HangingClient();
    final controller = CancellationController();

    final result = wireModel(client).run(
      ModelRequest(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      ),
      cancel: controller.token,
    );
    await client.sent.future;
    controller.cancel('user pressed stop');

    await expectLater(
      result,
      throwsA(
        isA<CancelledException>()
            .having((e) => e.message, 'message', 'user pressed stop')
            .having((e) => e.token, 'token', controller.token),
      ),
    );
  });

  test('a real error that races a cancel keeps its status', () async {
    final controller = CancellationController();
    final client = _UnabortableClient(
      statusCode: 503,
      response: {
        'error': {'code': 503, 'status': 'UNAVAILABLE', 'message': 'Busy'},
      },
      onSend: controller.cancel,
    );

    await expectLater(
      wireModel(client).run(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        ),
        cancel: controller.token,
      ),
      throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCode.unavailable,
        ),
      ),
    );
  });

  test('a finished request leaves nothing on a reused token', () async {
    final client = _UnabortableClient();
    final controller = CancellationController();

    await generate(client, controller.token);
    await generate(client, controller.token);

    var fired = 0;
    for (final trigger in client.triggers) {
      unawaited(trigger.then((_) => fired++));
    }
    expect(client.triggers, hasLength(2));
    controller.cancel();
    await pumpEventQueue();
    expect(fired, 0);
  });

  test('a request without a token still completes', () async {
    final client = WireClient(response: textResponse('hi'));
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(httpClient: client)],
    );
    addTearDown(ai.shutdown);

    final response = await ai.generate(
      model: firebaseAI.gemini('gemini-2.5-flash'),
      prompt: 'hello',
    );

    expect(response.text, 'hi');
  });
}
