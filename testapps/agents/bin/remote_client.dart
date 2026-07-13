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

/// Standalone script that exercises the [remoteAgent] client against the agents
/// shelf server (see `bin/server.dart`). Validates the client ergonomics end to
/// end over real HTTP.
///
/// Ported from the JS `src/remote-client.ts`.
///
/// Usage:
///   1. In one terminal: `dart run bin/server.dart` (starts the server on :8080).
///   2. In another:      `dart run bin/remote_client.dart`
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:genkit/client.dart';

String get _base =>
    Platform.environment['AGENT_BASE_URL'] ?? 'http://localhost:8080';

Future<void> main() async {
  // ── A server-managed agent (weatherAgent has a session store). ───────────
  final weather = remoteAgent(
    url: '$_base/api/weatherAgent',
    // The Dart server mounts the snapshot action under `/state`.
    getSnapshotUrl: '$_base/api/weatherAgent/state',
    abortUrl: '$_base/api/weatherAgent/abort',
  );

  stdout.writeln('\n=== weatherAgent: streaming turn ===');

  final chat = weather.chat(sessionId: _randomUuid());
  final turn = chat.sendTextStream('What is the weather like in Tokyo?');
  await for (final chunk in turn.stream) {
    if (chunk.text.isNotEmpty) stdout.write(chunk.text);
  }
  final res = await turn.response;
  stdout.writeln('\n--- response ---');
  stdout.writeln('text: ${res.text}');
  stdout.writeln('finishReason: ${res.finishReason.value}');
  stdout.writeln('snapshotId: ${res.snapshotId}');
  stdout.writeln('chat.snapshotId: ${chat.snapshotId}');

  stdout.writeln('\n=== weatherAgent: multi-turn (state auto-carried) ===');
  final res2 = await chat.sendText('What about Paris?'); // non-streaming send
  stdout.writeln('text: ${res2.text}');
  stdout.writeln('chat.snapshotId: ${chat.snapshotId}');
  stdout.writeln('chat.state: ${_pretty(chat.state)}');

  // ── Load a chat from the latest snapshot. ────────────────────────────────
  if (chat.snapshotId != null) {
    stdout.writeln('\n=== weatherAgent: load chat from snapshot ===');
    final loaded = await weather.loadChat(snapshotId: chat.snapshotId);
    stdout.writeln('restored messages: ${loaded.messages.length}');
    stdout.writeln('loaded.state: ${_pretty(loaded.state)}');
    final res3 = await loaded.sendText('And London?');
    stdout.writeln('text: ${res3.text}');
  }

  // ── Error handling demonstration. ────────────────────────────────────────
  stdout.writeln('\n=== error handling ===');
  try {
    final bad = remoteAgent(url: '$_base/api/does-not-exist');

    await bad.chat().sendText('hello');
  } catch (err) {
    if (err is AgentError) {
      stdout.writeln('caught AgentError, status: ${err.status}');
    } else {
      stdout.writeln('caught error: $err');
    }
  }

  stdout.writeln('\nDone.');
}

String _pretty(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// Minimal RFC-4122 v4 UUID generator (avoids an extra dependency).
String _randomUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
