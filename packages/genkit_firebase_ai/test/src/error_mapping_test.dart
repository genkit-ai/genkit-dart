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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/src/error_mapping.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects to a local server that rejects the handshake with a 403 and
/// returns the error, with an API key in the URI as firebase_ai sends it.
Future<Object> rejectedHandshake() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  server.listen((request) {
    request.response.statusCode = 403;
    request.response.close();
  });
  final channel = IOWebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:${server.port}/ws?key=AIzaSECRET'),
  );
  return channel.ready.then<Object>(
    (_) => 'connected',
    onError: (Object e) => e,
  );
}

void main() {
  test('a failed live WebSocket connect maps to UNAVAILABLE', () {
    final cause = WebSocketChannelException.from(
      const SocketException('Failed host lookup'),
    );

    final e = toGenkitException(cause, StackTrace.current);

    expect(e.status, StatusCode.unavailable);
    expect(e.cause, same(cause));
    expect(e.message, contains('Failed host lookup'));
  });

  test('a live connect error does not leak the API key', () async {
    final e = toGenkitException(await rejectedHandshake(), StackTrace.current);

    expect(e.message, contains('HTTP status code: 403'));
    expect(e.message, contains('key=<redacted>'));
    expect(e.toString(), isNot(contains('AIzaSECRET')));
  });

  test('a rejected live handshake maps its HTTP status', () async {
    final e = toGenkitException(await rejectedHandshake(), StackTrace.current);

    expect(e.status, StatusCode.permissionDenied);
  });
}
