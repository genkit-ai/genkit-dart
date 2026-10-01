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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/experimental.dart';
import 'package:genkit/experimental_io.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// A custom agent that replies with the caller's `user` context value.
Agent<dynamic> _defineGreeter(Genkit ai, String name, {SessionStore? store}) =>
    ai.defineCustomAgent(
      name: name,
      store: store,
      fn: (sess, options) async {
        await sess.run((input, ctx) async => null);
        return AgentResult(
          message: Message(
            role: Role.model,
            content: [TextPart(text: 'hello ${options.context?['user']}')],
          ),
        );
      },
    );

/// A persistent store without [SnapshotChangeNotifier], so an abort written to
/// it can't reach the running turn and the agent reports `abortable: false`.
final class _NonNotifyingStore implements SessionStore {
  _NonNotifyingStore(this._inner);

  final SessionStore _inner;

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) => _inner.getSnapshot(
    snapshotId: snapshotId,
    sessionId: sessionId,
    context: context,
  );

  @override
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator, {
    Map<String, dynamic>? context,
  }) => _inner.saveSnapshot(snapshotId, mutator, context: context);
}

Map<String, dynamic> _bearerAuth(RequestData request) {
  final auth = request.headers['authorization'];
  if (auth != 'Bearer secret') throw Exception('unauthorized');
  return {'user': 'alice'};
}

void main() {
  late Genkit ai;
  HttpServer? server;

  setUp(() => ai = Genkit());
  tearDown(() async => server?.close(force: true));

  Future<String> serve(GenkitRouter router) async {
    server = await router.serve(port: 0);
    return 'http://localhost:${server!.port}';
  }

  Future<http.Response> post(String url, Object? data, {String? auth}) =>
      http.post(
        Uri.parse(url),
        headers: {'content-type': 'application/json', 'authorization': ?auth},
        body: jsonEncode({'data': data}),
      );

  test('serves turn, getSnapshot and abort for remoteAgent', () async {
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: InMemorySessionStore(),
    );
    final base = await serve(GenkitRouter()..addAgent(greeter));

    final agent = remoteAgent(url: '$base/greeter');
    final chat = agent.chat();
    final res = await chat.send(text: 'hi');
    expect(res.text, 'hello null');
    expect(res.snapshotId, isNotNull);

    final snapshot = await agent.getSnapshot(snapshotId: res.snapshotId);
    expect(snapshot, isNotNull);
    expect(snapshot!.snapshotId, res.snapshotId);
    expect(snapshot.status, SnapshotStatus.completed);
    expect(snapshot.messages.first.text, 'hi');

    // The turn already completed, so abort reports the settled status.
    expect(await agent.abort(res.snapshotId!), SnapshotStatus.completed);
  });

  test('serves at a custom path', () async {
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: InMemorySessionStore(),
    );
    final base = await serve(GenkitRouter()..addAgent(greeter, path: '/chat'));

    final agent = remoteAgent(url: '$base/chat');
    final res = await agent.chat().send(text: 'hi');
    expect(await agent.getSnapshot(snapshotId: res.snapshotId), isNotNull);
    expect((await post('$base/greeter', null)).statusCode, 404);
  });

  test('applies the context provider to every agent route', () async {
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: InMemorySessionStore(),
    );
    final base = await serve(
      GenkitRouter()..addAgent(greeter, contextProvider: _bearerAuth),
    );

    final agent = remoteAgent(
      url: '$base/greeter',
      headers: () => {'authorization': 'Bearer secret'},
    );
    final res = await agent.chat().send(text: 'hi');
    expect(res.text, 'hello alice');

    for (final path in ['', '/getSnapshot', '/abort']) {
      final response = await post('$base/greeter$path', {
        'snapshotId': res.snapshotId,
      });
      expect(response.statusCode, 403, reason: 'POST /greeter$path');
    }
  });

  test('hideGetSnapshot and hideAbort skip the companion routes', () async {
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: InMemorySessionStore(),
    );
    final base = await serve(
      GenkitRouter()..addAgent(greeter, hideGetSnapshot: true, hideAbort: true),
    );

    final res = await remoteAgent(url: '$base/greeter').chat().send(text: 'hi');
    expect(res.text, 'hello null');

    final body = {'snapshotId': res.snapshotId};
    expect((await post('$base/greeter/getSnapshot', body)).statusCode, 404);
    expect((await post('$base/greeter/abort', body)).statusCode, 404);
  });

  test('client-managed agent gets only its turn route', () async {
    final stateless = _defineGreeter(ai, 'stateless');
    final base = await serve(GenkitRouter()..addAgent(stateless));

    final res = await remoteAgent(
      url: '$base/stateless',
    ).chat().send(text: 'hi');
    expect(res.text, 'hello null');

    final body = {'snapshotId': 'x'};
    expect((await post('$base/stateless/getSnapshot', body)).statusCode, 404);
    expect((await post('$base/stateless/abort', body)).statusCode, 404);
  });

  test('store that cannot signal the turn gets no abort route', () async {
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: _NonNotifyingStore(InMemorySessionStore()),
    );
    final base = await serve(GenkitRouter()..addAgent(greeter));

    final agent = remoteAgent(url: '$base/greeter');
    final res = await agent.chat().send(text: 'hi');
    expect(await agent.getSnapshot(snapshotId: res.snapshotId), isNotNull);
    final abort = await post('$base/greeter/abort', {
      'snapshotId': res.snapshotId,
    });
    expect(abort.statusCode, 404);
  });

  test('throws on a custom path with a trailing slash or at the root', () {
    final greeter = _defineGreeter(ai, 'greeter');
    final router = GenkitRouter();

    expect(() => router.addAgent(greeter, path: '/chat/'), throwsArgumentError);
    expect(() => router.addAgent(greeter, path: '/'), throwsArgumentError);
    // Nothing was registered by the failed calls.
    router.addAgent(greeter, path: '/chat');
  });

  test('throws when an agent route collides with an existing path', () async {
    // Needs a store: a client-managed agent has no `/abort` route to collide.
    final greeter = _defineGreeter(
      ai,
      'greeter',
      store: InMemorySessionStore(),
    );
    final echo = ai.defineFlow(
      name: 'echo',
      fn: (String input, _) async => input,
      inputSchema: .string(),
      outputSchema: .string(),
    );
    final router = GenkitRouter()..addAction(echo, path: '/greeter/abort');

    expect(() => router.addAgent(greeter), throwsArgumentError);

    // All or nothing: the turn and getSnapshot routes weren't added either,
    // so the agent can be mounted elsewhere.
    expect(await router.handle(_request('/greeter')), isNull);
    expect(await router.handle(_request('/greeter/getSnapshot')), isNull);
    router.addAgent(greeter, path: '/chat');
    expect(await router.handle(_request('/chat/abort')), isNotNull);
  });

  test(
    'mounts only the turn route when the metadata is unrecognized',
    () async {
      final greeter = _defineGreeter(
        ai,
        'greeter',
        store: InMemorySessionStore(),
      );
      // Simulate metadata from a different (e.g. future) shape.
      greeter.action.metadata['agent'] = {'kind': 'something-else'};
      final router = GenkitRouter()..addAgent(greeter);

      expect(await router.handle(_request('/greeter')), isNotNull);
      expect(await router.handle(_request('/greeter/getSnapshot')), isNull);
      expect(await router.handle(_request('/greeter/abort')), isNull);

      // The escape hatch: mount the companions explicitly.
      router
        ..addAction(greeter.getSnapshotDataAction, path: '/greeter/getSnapshot')
        ..addAction(greeter.abortAgentAction, path: '/greeter/abort');
      expect(await router.handle(_request('/greeter/abort')), isNotNull);
    },
  );
}

/// A request for [GenkitRouter.handle]; only used to probe which routes exist.
GenkitHttpRequest _request(String path) =>
    GenkitHttpRequest(method: 'GET', path: path);
