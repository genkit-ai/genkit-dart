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

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// A minimal mock HTTP client that routes requests to registered handlers by
/// URL path, supporting both unary (POST) and streamed (send) responses.
class _MockClient extends http.BaseClient {
  _MockClient(this.handler);

  /// Returns either a `String` body (unary) or a `List<String>` of SSE lines.
  final Object Function(String url, Map<String, dynamic> body) handler;

  final List<({String url, Map<String, dynamic> body})> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    requests.add((url: req.url.toString(), body: body));
    final result = handler(req.url.toString(), body);

    if (result is List<String>) {
      // SSE stream: join lines with the flow delimiter.
      final payload = result.map((l) => '$l\n\n').join();
      return http.StreamedResponse(
        Stream.value(utf8.encode(payload)),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }

    final str = result as String;
    return http.StreamedResponse(
      Stream.value(utf8.encode(str)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('remoteAgent', () {
    test('send() drives the streaming path and parses the output', () async {
      final client = _MockClient((url, body) {
        expect(url, 'http://host/agent');
        expect(body['data'], isNotNull);
        // `send()` always runs over the streaming transport (no unary fast
        // path), so respond with an SSE stream carrying the final result.
        return <String>[
          'data: ${jsonEncode({
            'result': AgentOutput(
              snapshotId: 's_x',
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'hi there')],
              ),
              finishReason: AgentFinishReason.stop,
            ).toJson(),
          })}',
        ];
      });

      final agent = remoteAgent(
        RemoteAgentOptions(url: 'http://host/agent', httpClient: client),
      );
      final chat = agent.chat();
      final res = await chat.send(agentInputFromText('hi'));
      expect(res.text, 'hi there');
      expect(res.snapshotId, 's_x');
      expect(res.finishReason, AgentFinishReason.stop);
    });

    test('sendStream() parses SSE chunks and the final result', () async {
      final client = _MockClient((url, body) {
        return <String>[
          'data: ${jsonEncode({
            'message': AgentStreamChunk(
              modelChunk: ModelResponseChunk(content: [TextPart(text: 'Hello ')]),
            ).toJson(),
          })}',
          'data: ${jsonEncode({
            'message': AgentStreamChunk(
              modelChunk: ModelResponseChunk(content: [TextPart(text: 'world')]),
            ).toJson(),
          })}',
          'data: ${jsonEncode({
            'result': AgentOutput(
              snapshotId: 's_y',
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Hello world')],
              ),
              finishReason: AgentFinishReason.stop,
            ).toJson(),
          })}',
        ];
      });

      final agent = remoteAgent(
        RemoteAgentOptions(url: 'http://host/agent', httpClient: client),
      );
      final chat = agent.chat();
      final turn = chat.sendStream(agentInputFromText('hi'));

      final texts = <String>[];
      await for (final c in turn.stream) {
        if (c.text.isNotEmpty) texts.add(c.text);
      }
      expect(texts, ['Hello ', 'world']);

      final res = await turn.response;
      expect(res.text, 'Hello world');
      expect(res.snapshotId, 's_y');
    });

    test('getSnapshot() posts to the getSnapshot URL', () async {
      late String seenUrl;
      final client = _MockClient((url, body) {
        seenUrl = url;
        return jsonEncode({
          'result': SessionSnapshot(
            snapshotId: 's_z',
            createdAt: '2026-01-01T00:00:00.000Z',
            state: SessionState(custom: {'k': 'v'}),
          ).toJson(),
        });
      });

      final agent = remoteAgent(
        RemoteAgentOptions(url: 'http://host/agent', httpClient: client),
      );
      final snap = await agent.getSnapshot(snapshotId: 's_z');
      expect(seenUrl, 'http://host/agent/getSnapshot');
      expect(snap, isNotNull);
      expect(snap!.state?.custom, {'k': 'v'});
    });

    test('abort() posts to the abort URL and returns prior status', () async {
      late String seenUrl;
      final client = _MockClient((url, body) {
        seenUrl = url;
        expect(body['data'], 's_z');
        return jsonEncode({'result': 'done'});
      });

      final agent = remoteAgent(
        RemoteAgentOptions(url: 'http://host/agent', httpClient: client),
      );
      final status = await agent.abort('s_z');
      expect(seenUrl, 'http://host/agent/abort');
      expect(status, 'done');
    });

    test('resolves headers per request', () async {
      Map<String, dynamic>? captured;
      final client = _MockClient((url, body) {
        captured = body;
        // `send()` streams, so respond with an SSE final-result chunk.
        return <String>[
          'data: ${jsonEncode({
            'result': AgentOutput(
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'ok')],
              ),
            ).toJson(),
          })}',
        ];
      });

      var calls = 0;
      final agent = remoteAgent(
        RemoteAgentOptions(
          url: 'http://host/agent',
          httpClient: client,
          headers: () {
            calls++;
            return {'authorization': 'Bearer token'};
          },
        ),
      );
      await agent.chat().send(agentInputFromText('hi'));
      expect(calls, greaterThan(0));
      expect(captured, isNotNull);
    });
  });
}
