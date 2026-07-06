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

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit/io.dart';

import 'package:genkit/src/exception.dart';
import 'package:genkit/src/types.dart';
import 'package:test/test.dart';

SessionSnapshot _snap({
  required String snapshotId,
  String? sessionId,
  String? parentId,
  String? createdAt,
  SnapshotStatus? status,
}) {
  return SessionSnapshot(
    snapshotId: snapshotId,
    parentId: parentId,
    createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
    status: status,
    state: SessionState(sessionId: sessionId),
  );
}

void main() {
  late Directory tempDir;
  late FileSessionStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('genkit_file_store_test');
    store = FileSessionStore(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('FileSessionStore', () {
    test('saves and reads a snapshot by id', () async {
      final id = await store.saveSnapshot(
        's1',
        (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
      );
      expect(id, 's1');

      final loaded = await store.getSnapshot(snapshotId: 's1');
      expect(loaded, isNotNull);
      expect(loaded!.snapshotId, 's1');
      expect(loaded.state?.sessionId, 'sess');
    });

    test('persists snapshots to disk as <prefix>/<id>.json', () async {
      await store.saveSnapshot(
        's1',
        (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
      );
      final file = File('${tempDir.path}/global/s1.json');
      expect(file.existsSync(), isTrue);
    });

    test('returns null for a missing snapshot', () async {
      expect(await store.getSnapshot(snapshotId: 'nope'), isNull);
    });

    test('mints a UUID when no id is supplied', () async {
      final id = await store.saveSnapshot(
        null,
        (_) => _snap(snapshotId: '', sessionId: 'sess'),
      );
      expect(id, isNotNull);
      expect(id, isNotEmpty);
      expect(await store.getSnapshot(snapshotId: id!), isNotNull);
    });

    test('mutator returning null is a no-op', () async {
      final id = await store.saveSnapshot('s1', (_) => null);
      expect(id, isNull);
      expect(await store.getSnapshot(snapshotId: 's1'), isNull);
    });

    test('passes the current snapshot to the mutator on update', () async {
      await store.saveSnapshot(
        's1',
        (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
      );
      SessionSnapshot? seen;
      await store.saveSnapshot('s1', (current) {
        seen = current;
        current!.status = SnapshotStatus.completed;
        return current;
      });
      expect(seen, isNotNull);
      expect(seen!.snapshotId, 's1');
      final loaded = await store.getSnapshot(snapshotId: 's1');
      expect(loaded!.status?.value, 'completed');
    });

    group('getSnapshot by sessionId', () {
      test('resolves the single leaf of a linear chain', () async {
        await store.saveSnapshot(
          'a',
          (_) => _snap(
            snapshotId: 'a',
            sessionId: 'sess',
            createdAt: '2024-01-01T00:00:00.000Z',
          ),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            createdAt: '2024-01-02T00:00:00.000Z',
          ),
        );
        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'b');
      });

      test('returns null when no snapshot matches the session', () async {
        expect(await store.getSnapshot(sessionId: 'missing'), isNull);
      });

      test('picks the most recent leaf when branched (default)', () async {
        await store.saveSnapshot(
          'root',
          (_) => _snap(
            snapshotId: 'root',
            sessionId: 'sess',
            createdAt: '2024-01-01T00:00:00.000Z',
          ),
        );
        await store.saveSnapshot(
          'old',
          (_) => _snap(
            snapshotId: 'old',
            sessionId: 'sess',
            parentId: 'root',
            createdAt: '2024-01-02T00:00:00.000Z',
          ),
        );
        await store.saveSnapshot(
          'new',
          (_) => _snap(
            snapshotId: 'new',
            sessionId: 'sess',
            parentId: 'root',
            createdAt: '2024-01-03T00:00:00.000Z',
          ),
        );
        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'new');
      });

      test('rejects a branched session when configured', () async {
        final strict = FileSessionStore(
          tempDir.path,
          rejectBranchingSessions: true,
        );
        await strict.saveSnapshot(
          'root',
          (_) => _snap(snapshotId: 'root', sessionId: 'sess'),
        );
        await strict.saveSnapshot(
          'l1',
          (_) => _snap(snapshotId: 'l1', sessionId: 'sess', parentId: 'root'),
        );
        await strict.saveSnapshot(
          'l2',
          (_) => _snap(snapshotId: 'l2', sessionId: 'sess', parentId: 'root'),
        );
        expect(
          () => strict.getSnapshot(sessionId: 'sess'),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCodes.FAILED_PRECONDITION,
            ),
          ),
        );
      });
    });

    group('snapshotId safety', () {
      for (final bad in ['../escape', 'a/b', r'a\b', '..', '.', '']) {
        test('rejects unsafe snapshotId "$bad"', () async {
          expect(
            () => store.getSnapshot(snapshotId: bad),
            throwsA(isA<GenkitException>()),
          );
        });
      }
    });

    group('snapshotPathPrefix (multi-tenant)', () {
      test('isolates snapshots per tenant prefix', () async {
        final tenantStore = FileSessionStore(
          tempDir.path,
          snapshotPathPrefix: (context) =>
              context?['user'] as String? ?? 'anon',
        );
        await tenantStore.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
          context: {'user': 'alice'},
        );
        // Bob cannot see Alice's snapshot.
        expect(
          await tenantStore.getSnapshot(
            snapshotId: 's1',
            context: {'user': 'bob'},
          ),
          isNull,
        );
        // Alice can.
        expect(
          await tenantStore.getSnapshot(
            snapshotId: 's1',
            context: {'user': 'alice'},
          ),
          isNotNull,
        );
        expect(File('${tempDir.path}/alice/s1.json').existsSync(), isTrue);
      });
    });

    group('maxPersistedChainLength', () {
      test('trims snapshots older than the limit', () async {
        final trimming = FileSessionStore(
          tempDir.path,
          maxPersistedChainLength: 2,
        );
        await trimming.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess'),
        );
        await trimming.saveSnapshot(
          'b',
          (_) => _snap(snapshotId: 'b', sessionId: 'sess', parentId: 'a'),
        );
        await trimming.saveSnapshot(
          'c',
          (_) => _snap(snapshotId: 'c', sessionId: 'sess', parentId: 'b'),
        );
        // Chain is c -> b -> a; with a limit of 2, 'a' is pruned.
        expect(await trimming.getSnapshot(snapshotId: 'c'), isNotNull);
        expect(await trimming.getSnapshot(snapshotId: 'b'), isNotNull);
        expect(await trimming.getSnapshot(snapshotId: 'a'), isNull);
      });
    });

    group('per-session pointer', () {
      test('writes a pointer file under .pointers/ on save', () async {
        await store.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
        );
        final pointer = File('${tempDir.path}/global/.pointers/sess.json');
        expect(pointer.existsSync(), isTrue);
        final doc = jsonDecode(pointer.readAsStringSync()) as Map;
        expect(doc['currentSnapshotId'], 's1');
      });

      test('does not treat the .pointers dir as a snapshot in the scan', () {
        // The pointers sub-directory must never confuse the sessionId scan,
        // even when the fast-path pointer is bypassed.
        return Future(() async {
          await store.saveSnapshot(
            's1',
            (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
          );
          // Force a scan (no pointer hit) by using a strict store rooted at the
          // same dir, which bypasses the pointer fast path.
          final strict = FileSessionStore(
            tempDir.path,
            rejectBranchingSessions: true,
          );
          final leaf = await strict.getSnapshot(sessionId: 'sess');
          expect(leaf!.snapshotId, 's1');
        });
      });

      test('advances the pointer to the new leaf as a chain grows', () async {
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess'),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(snapshotId: 'b', sessionId: 'sess', parentId: 'a'),
        );
        final pointer = File('${tempDir.path}/global/.pointers/sess.json');
        final doc = jsonDecode(pointer.readAsStringSync()) as Map;
        expect(doc['currentSnapshotId'], 'b');
        expect((await store.getSnapshot(sessionId: 'sess'))!.snapshotId, 'b');
      });

      test('self-heals a stale pointer via the scan fallback', () async {
        await store.saveSnapshot(
          'a',
          (_) => _snap(
            snapshotId: 'a',
            sessionId: 'sess',
            createdAt: '2024-01-01T00:00:00.000Z',
          ),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            createdAt: '2024-01-02T00:00:00.000Z',
          ),
        );
        // Corrupt the pointer so it names a snapshot that no longer matches.
        final pointer = File('${tempDir.path}/global/.pointers/sess.json');
        pointer.writeAsStringSync(
          jsonEncode({'currentSnapshotId': 'gone', 'updatedAt': 'x'}),
        );
        // The scan fallback still resolves the true leaf...
        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'b');
        // ...and rewrites the pointer so it is fresh again.
        final doc = jsonDecode(pointer.readAsStringSync()) as Map;
        expect(doc['currentSnapshotId'], 'b');
      });

      test('tolerates a corrupt pointer file', () async {
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess'),
        );
        final pointer = File('${tempDir.path}/global/.pointers/sess.json');
        pointer.writeAsStringSync('{not valid json');
        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'a');
      });

      test(
        'a non-leaf rewrite with an absent pointer never aims at the non-leaf',
        () async {
          // Matching the JS store, the pointer is only advanced for a
          // brand-new snapshot. Rewriting an older (non-leaf) snapshot must
          // never point the session at it, even when the pointer file is
          // absent (e.g. a crash after the snapshot write but before the
          // best-effort pointer write, or a legacy store).
          await store.saveSnapshot(
            's1',
            (_) => _snap(
              snapshotId: 's1',
              sessionId: 'sess',
              createdAt: '2024-01-01T00:00:00.000Z',
            ),
          );
          await store.saveSnapshot(
            's2',
            (_) => _snap(
              snapshotId: 's2',
              sessionId: 'sess',
              parentId: 's1',
              createdAt: '2024-01-02T00:00:00.000Z',
            ),
          );
          // Simulate the pointer never having been written (or lost).
          File('${tempDir.path}/global/.pointers/sess.json').deleteSync();

          // Rewrite the non-leaf s1 (e.g. a status/heartbeat update).
          await store.saveSnapshot('s1', (current) {
            current!.status = SnapshotStatus.completed;
            return current;
          });

          // The lookup must resolve to the real leaf s2, not the rewritten s1.
          final leaf = await store.getSnapshot(sessionId: 'sess');
          expect(leaf!.snapshotId, 's2');
          // And the pointer that the scan self-heals must name s2.
          final doc =
              jsonDecode(
                    File(
                      '${tempDir.path}/global/.pointers/sess.json',
                    ).readAsStringSync(),
                  )
                  as Map;
          expect(doc['currentSnapshotId'], 's2');
        },
      );
    });

    group('onSnapshotStateChange', () {
      test('fires when a watched snapshot changes', () async {
        // Use a short poll interval so the test does not depend on the
        // directory watcher, which can silently miss events on some CI
        // filesystems. The polling fallback then observes the change well
        // within the wait below.
        final watched = FileSessionStore(
          tempDir.path,
          snapshotWatchPollInterval: const Duration(milliseconds: 20),
        );
        await watched.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
        );
        final seen = <SnapshotStatus?>[];
        final unsub = watched.onSnapshotStateChange('s1', (snap) {
          seen.add(snap.status);
        });
        // Initial emit of the existing state.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await watched.saveSnapshot('s1', (current) {
          current!.status = SnapshotStatus.aborted;
          return current;
        });
        // Allow the watcher/poller to observe the change.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        unsub?.call();

        expect(seen.map((s) => s?.value), contains('aborted'));
      });
    });
  });
}
