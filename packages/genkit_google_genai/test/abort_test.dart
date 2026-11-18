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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// Holds every request until its abort trigger fires, then fails it the
/// way `http`'s own clients do. Records the requests it saw.
class _HangingClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  final Completer<void> _received = Completer<void>();
  bool closed = false;

  /// Completes once the first request has arrived.
  Future<void> get received => _received.future;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (!_received.isCompleted) _received.complete();
    if (request case http.Abortable(:final abortTrigger?)) {
      await abortTrigger;
      throw http.RequestAbortedException(request.url);
    }
    // A request without a trigger would hang forever: fail the test instead.
    throw StateError('request has no abort trigger: ${request.url}');
  }

  @override
  void close() => closed = true;
}

final _hello = ModelRequest(
  messages: [
    Message(
      role: Role.user,
      content: [TextPart(text: 'hello')],
    ),
  ],
);

void main() {
  group('cancellation aborts the request in flight', () {
    for (final (label, model, stream) in [
      ('generateContent', 'gemini-3.1-flash-lite', false),
      ('streamed generateContent', 'gemini-3.1-flash-lite', true),
      ('Interactions', 'gemini-3.8-flash', false),
      ('streamed Interactions', 'gemini-3.8-flash', true),
    ]) {
      test(label, () async {
        final client = _HangingClient();
        final action = GoogleGenAiPluginImpl(
          apiKey: 'test-key',
          httpClient: client,
        ).resolve(.model, model)!;
        final controller = CancellationController();

        final run = action.run(
          _hello,
          onChunk: stream ? (_) {} : null,
          cancel: controller.token,
        );
        await client.received;
        controller.cancel();

        await expectLater(run, throwsA(isA<CancelledException>()));
        expect(client.requests, hasLength(1));
        // The injected client is the caller's: aborted, never closed.
        expect(client.closed, isFalse);
      });
    }

    test('embedder', () async {
      final client = _HangingClient();
      final embedder =
          GoogleGenAiPluginImpl(
                apiKey: 'test-key',
                httpClient: client,
              ).resolve(.embedder, 'gemini-embedding-001')!
              as Action<EmbedRequest, EmbedResponse, void, void>;
      final controller = CancellationController();

      final run = embedder.run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
          ],
        ),
        cancel: controller.token,
      );
      await client.received;
      controller.cancel();

      await expectLater(run, throwsA(isA<CancelledException>()));
      expect(client.closed, isFalse);
    });
  });
}
