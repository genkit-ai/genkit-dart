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

import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/agents/session.dart';
import 'package:test/test.dart';

Message _user(String text) => Message(
  role: Role.user,
  content: [TextPart(text: text)],
);

SessionSnapshot _snapshot({
  required String snapshotId,
  String? parentId,
  required String sessionId,
}) => SessionSnapshot(
  snapshotId: snapshotId,
  parentId: parentId,
  createdAt: DateTime.now().toIso8601String(),
  state: SessionState(sessionId: sessionId, messages: [], artifacts: []),
);

void main() {
  group('snapshotId helpers', () {
    test('generateUuidV4 produces a valid v4 UUID', () {
      final id = generateUuidV4();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
            r'[0-9a-f]{12}$',
          ),
        ),
      );
      // assertValidSessionId accepts it.
      expect(() => assertValidSessionId(id), returnsNormally);
    });

    test('reserveSnapshotId embeds the sessionId as convoId', () {
      final sessionId = generateUuidV4();
      final id = reserveSnapshotId(sessionId: sessionId);
      expect(isSnapshotId(id), isTrue);
      expect(id, startsWith('s_${sessionId}_'));
    });

    test('reserveSnapshotId inherits convoId from parent', () {
      final sessionId = generateUuidV4();
      final parent = reserveSnapshotId(sessionId: sessionId);
      final child = reserveSnapshotId(parentId: parent);
      expect(child, startsWith('s_${sessionId}_'));
    });

    test('isSnapshotId distinguishes snapshot ids from session ids', () {
      expect(isSnapshotId(generateUuidV4()), isFalse);
      expect(
        isSnapshotId(reserveSnapshotId(sessionId: generateUuidV4())),
        isTrue,
      );
    });

    test('assertValidSessionId rejects non-UUIDs', () {
      expect(
        () => assertValidSessionId('not-a-uuid'),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('Session', () {
    test('assigns a sessionId when none provided', () {
      final session = Session(SessionState());
      expect(session.sessionId, isNotEmpty);
      expect(session.getState().sessionId, session.sessionId);
    });

    test('addMessages appends and bumps version', () {
      final session = Session(SessionState(messages: []));
      expect(session.getVersion(), 0);
      session.addMessages([_user('hi')]);
      expect(session.getMessages().length, 1);
      expect(session.getVersion(), 1);
    });

    test('updateCustom mutates custom state and emits', () {
      final session = Session(SessionState(custom: {'count': 0}));
      var emitted = false;
      session.on('customChanged', (_) => emitted = true);
      session.updateCustom((c) => {'count': ((c as Map)['count'] as int) + 1});
      expect(session.getCustom(), {'count': 1});
      expect(emitted, isTrue);
    });

    test('addArtifacts dedupes by name (update vs add)', () {
      final session = Session(SessionState(artifacts: []));
      session.addArtifacts([
        Artifact(
          name: 'a',
          parts: [TextPart(text: 'v1')],
        ),
      ]);
      session.addArtifacts([
        Artifact(
          name: 'a',
          parts: [TextPart(text: 'v2')],
        ),
        Artifact(
          name: 'b',
          parts: [TextPart(text: 'b1')],
        ),
      ]);
      final artifacts = session.getArtifacts();
      expect(artifacts.length, 2);
      expect(artifacts.firstWhere((a) => a.name == 'a').parts.first.text, 'v2');
    });

    test('run binds the current session', () {
      final session = Session(SessionState());
      expect(getCurrentSession(), isNull);
      session.run(() {
        expect(getCurrentSession(), same(session));
      });
    });

    test('getState returns a deep copy', () {
      final session = Session(SessionState(messages: [_user('hi')]));
      final state = session.getState();
      state.messages = [...state.messages!, _user('extra')];
      expect(session.getMessages().length, 1);
    });
  });

  group('InMemorySessionStore', () {
    test('saveSnapshot assigns an id and getSnapshot reads it back', () async {
      final store = InMemorySessionStore();
      final sessionId = generateUuidV4();
      final id = await store.saveSnapshot(
        null,
        (_) => _snapshot(snapshotId: '', sessionId: sessionId),
      );
      expect(id, isNotNull);
      expect(isSnapshotId(id!), isTrue);

      final loaded = await store.getSnapshot(snapshotId: id);
      expect(loaded, isNotNull);
      expect(loaded!.snapshotId, id);
    });

    test('getSnapshot by sessionId resolves the latest leaf', () async {
      final store = InMemorySessionStore();
      final sessionId = generateUuidV4();
      final firstId = await store.saveSnapshot(
        null,
        (_) => _snapshot(snapshotId: '', sessionId: sessionId),
      );
      final secondId = await store.saveSnapshot(
        null,
        (_) =>
            _snapshot(snapshotId: '', parentId: firstId, sessionId: sessionId),
      );

      final leaf = await store.getSnapshot(sessionId: sessionId);
      expect(leaf!.snapshotId, secondId);
    });

    test('getSnapshot by sessionId rejects branching histories', () async {
      final store = InMemorySessionStore();
      final sessionId = generateUuidV4();
      final rootId = await store.saveSnapshot(
        null,
        (_) => _snapshot(snapshotId: '', sessionId: sessionId),
      );
      // Two children of the same parent => two leaves => branch.
      await store.saveSnapshot(
        null,
        (_) =>
            _snapshot(snapshotId: '', parentId: rootId, sessionId: sessionId),
      );
      await store.saveSnapshot(
        null,
        (_) =>
            _snapshot(snapshotId: '', parentId: rootId, sessionId: sessionId),
      );

      expect(
        () => store.getSnapshot(sessionId: sessionId),
        throwsA(isA<GenkitException>()),
      );
    });

    test('getSnapshot requires exactly one of snapshotId/sessionId', () async {
      final store = InMemorySessionStore();
      expect(store.getSnapshot, throwsA(isA<GenkitException>()));
      expect(
        () => store.getSnapshot(snapshotId: 'x', sessionId: generateUuidV4()),
        throwsA(isA<GenkitException>()),
      );
    });

    test('saveSnapshot mutator returning null is a no-op', () async {
      final store = InMemorySessionStore();
      final id = await store.saveSnapshot(null, (_) => null);
      expect(id, isNull);
    });

    test('onSnapshotStateChange notifies listeners', () async {
      final store = InMemorySessionStore();
      final sessionId = generateUuidV4();
      final id = await store.saveSnapshot(
        null,
        (_) => _snapshot(snapshotId: '', sessionId: sessionId),
      );

      SessionSnapshot? seen;
      store.onSnapshotStateChange(id!, (snap) => seen = snap);
      await store.saveSnapshot(id, (current) {
        current!.status = 'done';
        return current;
      });
      expect(seen, isNotNull);
      expect(seen!.status, 'done');
    });
  });
}
