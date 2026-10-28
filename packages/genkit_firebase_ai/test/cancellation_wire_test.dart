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
