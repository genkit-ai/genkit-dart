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

/// Cancellation through a real `IOClient`, against a local server.
///
/// Live is not covered: `dart:io`'s shared WebSocket client does not go through
/// [HttpOverrides], so a test could not keep it off the real endpoint.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:http/io_client.dart';

import 'wire_harness.dart' show setUpFirebaseApp;

/// Sends every connection to the local server on [port], in plain text.
class _LocalOverrides extends HttpOverrides {
  _LocalOverrides(this.port);

  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, port);
}

void main() {
  late HttpServer server;
  late Future<void> Function(HttpRequest) handle;
  HttpOverrides? previous;

  setUpAll(() async {
    await setUpFirebaseApp();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => unawaited(handle(request)));
    previous = HttpOverrides.current;
    HttpOverrides.global = _LocalOverrides(server.port);
  });

  tearDownAll(() async {
    HttpOverrides.global = previous;
    await server.close(force: true);
  });

  final request = ModelRequest(
    messages: [
      Message(
        role: Role.user,
        content: [TextPart(text: 'hello')],
      ),
    ],
  );

  /// Serves requests by holding them open until the client goes away.
  Completer<void> hangRequests({String? firstChunk}) {
    final received = Completer<void>();
    handle = (request) async {
      await request.drain<void>();
      if (firstChunk != null) {
        request.response.write(firstChunk);
        await request.response.flush();
      }
      received.complete();
      await request.response.done;
    };
    return received;
  }

  Model model() =>
      firebaseAI(httpClient: IOClient()).resolve(.model, 'gemini-flash-latest')
          as Model;

  test('cancelling aborts a request in flight', () async {
    final received = hangRequests();
    final controller = CancellationController();

    final result = model().run(request, cancel: controller.token);
    await received.future;
    controller.cancel('user pressed stop');

    await expectLater(
      result.timeout(const Duration(seconds: 5)),
      throwsA(isA<CancelledException>()),
    );
  });

  test('cancelling aborts a stream in flight', () async {
    final received = hangRequests(
      firstChunk:
          'data: ${jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'Hel'},
                  ],
                },
              },
            ],
          })}\r\n\r\n',
    );
    final controller = CancellationController();
    final chunks = <String>[];

    final result = model().run(
      request,
      cancel: controller.token,
      onChunk: (chunk) => chunks.add(chunk.text),
    );
    await received.future;
    await pumpEventQueue(times: 100);
    controller.cancel();

    await expectLater(
      result.timeout(const Duration(seconds: 5)),
      throwsA(isA<CancelledException>()),
    );
  });
}
