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

/// Integration tests for [FirestoreSessionStore].
///
/// These tests require a running Firestore emulator and are skipped unless the
/// `FIRESTORE_EMULATOR_HOST` environment variable is set (e.g. to
/// `localhost:8080`). Start one with either:
///
/// ```bash
/// firebase emulators:start --only firestore
/// gcloud emulators firestore start --host-port=localhost:8080
/// ```
///
/// then run:
///
/// ```bash
/// FIRESTORE_EMULATOR_HOST=localhost:8080 GOOGLE_CLOUD_PROJECT=demo-genkit \
///   dart test
/// ```
@TestOn('vm')
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_cloud/firestore_session_store.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

/// The emulator host (e.g. `localhost:8080`), or `null` when not configured.
final _emulatorHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];

/// A throwaway project id; the emulator does not validate it.
const _projectId = 'demo-genkit';

/// Builds a snapshot whose [SessionState.custom] carries the given payload.
SessionSnapshot _snap({
  required String snapshotId,
  required String sessionId,
  String? parentId,
  String? createdAt,
  Object? custom,
  SnapshotStatus? status,
}) => SessionSnapshot(
  snapshotId: snapshotId,
  sessionId: sessionId,
  parentId: parentId,
  createdAt: createdAt ?? DateTime.now().toUtc().toIso8601String(),
  status: status,
  state: SessionState(sessionId: sessionId, custom: custom),
);

void main() {
  if (_emulatorHost == null) {
    // Surface a single, clear skip rather than silently passing.
    test(
      'FirestoreSessionStore (emulator)',
      () {},
      skip:
          'Set FIRESTORE_EMULATOR_HOST (e.g. localhost:8080) to run the '
          'Firestore integration tests.',
    );
    return;
  }

  late Firestore db;

  setUp(() {
    db = Firestore(settings: Settings(projectId: _projectId));
  });

  /// Returns a store using a unique collection per test so emulator state from
  /// one test never bleeds into the next.
  FirestoreSessionStore newStore({
    int checkpointInterval = defaultCheckpointInterval,
    int shardSize = defaultShardSize,
    String Function(Map<String, dynamic>? context)? snapshotPathPrefix,
    Duration snapshotWatchPollInterval = const Duration(milliseconds: 50),
  }) => FirestoreSessionStore(
    db: db,
    collection: 'test-${DateTime.now().microsecondsSinceEpoch}',
    checkpointInterval: checkpointInterval,
    shardSize: shardSize,
    snapshotPathPrefix: snapshotPathPrefix,
    snapshotWatchPollInterval: snapshotWatchPollInterval,
  );

  group('FirestoreSessionStore', () {
    test('saves and reads a snapshot by id (root checkpoint)', () async {
      final store = newStore();
      final id = await store.saveSnapshot(
        's1',
        (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'n': 1}),
      );
      expect(id, 's1');

      final loaded = await store.getSnapshot(snapshotId: 's1');
      expect(loaded, isNotNull);
      expect(loaded!.snapshotId, 's1');
      expect(loaded.sessionId, 'sess');
      expect(loaded.state?.custom, {'n': 1});
    });

    test('returns null for a missing snapshot', () async {
      final store = newStore();
      expect(await store.getSnapshot(snapshotId: 'nope'), isNull);
    });

    test('returns null for a missing session', () async {
      final store = newStore();
      expect(await store.getSnapshot(sessionId: 'nope'), isNull);
    });

    test('mints a UUID when no id is supplied', () async {
      final store = newStore();
      final id = await store.saveSnapshot(
        null,
        (_) => _snap(snapshotId: '', sessionId: 'sess'),
      );
      expect(id, isNotNull);
      expect(id, isNotEmpty);
      expect(await store.getSnapshot(snapshotId: id!), isNotNull);
    });

    test('mutator returning null is a no-op', () async {
      final store = newStore();
      final id = await store.saveSnapshot('s1', (_) => null);
      expect(id, isNull);
      expect(await store.getSnapshot(snapshotId: 's1'), isNull);
    });

    test('passes the current snapshot to the mutator on update', () async {
      final store = newStore();
      await store.saveSnapshot(
        's1',
        (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'n': 1}),
      );
      SessionSnapshot? seen;
      await store.saveSnapshot('s1', (current) {
        seen = current;
        current!.status = SnapshotStatus.completed;
        return current;
      });
      expect(seen, isNotNull);
      expect(seen!.snapshotId, 's1');
      expect(seen!.state?.custom, {'n': 1});
      final loaded = await store.getSnapshot(snapshotId: 's1');
      expect(loaded!.status?.value, 'completed');
    });

    test('throws INVALID_ARGUMENT without a sessionId', () async {
      final store = newStore();
      expect(
        () => store.saveSnapshot(
          's1',
          (_) => SessionSnapshot(
            snapshotId: 's1',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            state: SessionState(),
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });

    test('rejects both snapshotId and sessionId', () async {
      final store = newStore();
      expect(
        () => store.getSnapshot(snapshotId: 'a', sessionId: 'b'),
        throwsA(isA<GenkitException>()),
      );
    });

    group('diff chain', () {
      test('reconstructs state across a chain of diffs', () async {
        final store = newStore(checkpointInterval: 100);
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess', custom: {'v': 1}),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            custom: {'v': 2},
          ),
        );
        await store.saveSnapshot(
          'c',
          (_) => _snap(
            snapshotId: 'c',
            sessionId: 'sess',
            parentId: 'b',
            custom: {'v': 3},
          ),
        );

        expect((await store.getSnapshot(snapshotId: 'a'))!.state?.custom, {
          'v': 1,
        });
        expect((await store.getSnapshot(snapshotId: 'b'))!.state?.custom, {
          'v': 2,
        });
        expect((await store.getSnapshot(snapshotId: 'c'))!.state?.custom, {
          'v': 3,
        });
      });

      test('resolves a session to its latest leaf via the pointer', () async {
        final store = newStore(checkpointInterval: 100);
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess', custom: {'v': 1}),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            custom: {'v': 2},
          ),
        );

        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'b');
        expect(leaf.state?.custom, {'v': 2});
      });

      test('writes a checkpoint at the checkpoint interval', () async {
        // With interval 2, the 2nd turn (segmentPath length would reach 1, +1
        // == 2 >= 2) is promoted to a checkpoint anchoring itself.
        final store = newStore(checkpointInterval: 2);
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess', custom: {'v': 1}),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            custom: {'v': 2},
          ),
        );
        await store.saveSnapshot(
          'c',
          (_) => _snap(
            snapshotId: 'c',
            sessionId: 'sess',
            parentId: 'b',
            custom: {'v': 3},
          ),
        );

        // Every snapshot still reconstructs correctly despite the periodic
        // re-checkpointing.
        expect((await store.getSnapshot(snapshotId: 'c'))!.state?.custom, {
          'v': 3,
        });
        expect((await store.getSnapshot(sessionId: 'sess'))!.snapshotId, 'c');
      });
    });

    group('sharding', () {
      test('shards a large checkpoint state across documents', () async {
        // Tiny shardSize forces multi-shard checkpoints.
        final store = newStore(shardSize: 64);
        final big = List.generate(50, (i) => 'item-$i').join('-');
        await store.saveSnapshot(
          's1',
          (_) =>
              _snap(snapshotId: 's1', sessionId: 'sess', custom: {'big': big}),
        );
        final loaded = await store.getSnapshot(snapshotId: 's1');
        expect((loaded!.state?.custom as Map)['big'], big);
      });

      test('promotes an oversized diff to a sharded checkpoint', () async {
        final store = newStore(checkpointInterval: 100, shardSize: 64);
        await store.saveSnapshot(
          'a',
          (_) => _snap(snapshotId: 'a', sessionId: 'sess', custom: {'v': 1}),
        );
        final big = List.generate(50, (i) => 'x$i').join('-');
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            custom: {'big': big},
          ),
        );
        final loaded = await store.getSnapshot(snapshotId: 'b');
        expect((loaded!.state?.custom as Map)['big'], big);
      });

      test(
        'prunes stale trailing shards on a shrinking re-checkpoint',
        () async {
          // Root is a checkpoint; re-saving the same id re-checkpoints in place.
          final store = newStore(shardSize: 64);
          final big = List.generate(80, (i) => 'y$i').join('-');
          await store.saveSnapshot(
            's1',
            (_) => _snap(
              snapshotId: 's1',
              sessionId: 'sess',
              custom: {'big': big},
            ),
          );
          // Shrink the state dramatically; trailing shards must be removed.
          await store.saveSnapshot(
            's1',
            (current) =>
                _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 1}),
          );
          final loaded = await store.getSnapshot(snapshotId: 's1');
          expect(loaded!.state?.custom, {'v': 1});
        },
      );
    });

    group('multi-tenant isolation', () {
      test('scopes snapshots by prefix derived from context', () async {
        final store = newStore(
          snapshotPathPrefix: (context) =>
              context?['tenant'] as String? ?? 'global',
        );
        await store.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'t': 'a'}),
          context: {'tenant': 'alice'},
        );

        // Same id is invisible to a different tenant.
        expect(
          await store.getSnapshot(snapshotId: 's1', context: {'tenant': 'bob'}),
          isNull,
        );
        // ...and visible to the owning tenant.
        final mine = await store.getSnapshot(
          snapshotId: 's1',
          context: {'tenant': 'alice'},
        );
        expect(mine!.state?.custom, {'t': 'a'});
      });
    });

    group('prefix validation', () {
      test('rejects a blank prefix with INVALID_ARGUMENT', () async {
        final store = newStore(snapshotPathPrefix: (_) => '   ');
        expect(
          () => store.saveSnapshot(
            's1',
            (_) => _snap(snapshotId: 's1', sessionId: 'sess'),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCodes.INVALID_ARGUMENT,
            ),
          ),
        );
      });

      test('rejects a prefix containing a slash', () async {
        final store = newStore(snapshotPathPrefix: (_) => 'a/b');
        expect(
          () => store.getSnapshot(snapshotId: 's1'),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCodes.INVALID_ARGUMENT,
            ),
          ),
        );
      });

      test('rejects "." and ".." prefixes', () async {
        for (final bad in ['.', '..']) {
          final store = newStore(snapshotPathPrefix: (_) => bad);
          expect(
            () => store.getSnapshot(snapshotId: 's1'),
            throwsA(
              isA<GenkitException>().having(
                (e) => e.status,
                'status',
                StatusCodes.INVALID_ARGUMENT,
              ),
            ),
            reason: 'prefix "$bad" should be rejected',
          );
        }
      });
    });

    group('terminal-state upsert guard', () {
      test('rejects upserting a terminal snapshot', () async {
        final store = newStore();
        await store.saveSnapshot(
          's1',
          (_) => _snap(
            snapshotId: 's1',
            sessionId: 'sess',
            custom: {'v': 1},
            status: SnapshotStatus.completed,
          ),
        );
        expect(
          () => store.saveSnapshot(
            's1',
            (current) =>
                _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 2}),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.status,
              'status',
              StatusCodes.FAILED_PRECONDITION,
            ),
          ),
        );
        // The rejected write leaves the original state intact.
        final loaded = await store.getSnapshot(snapshotId: 's1');
        expect(loaded!.state?.custom, {'v': 1});
      });

      test('allows upserting a non-terminal (pending) snapshot', () async {
        final store = newStore();
        await store.saveSnapshot(
          's1',
          (_) => _snap(
            snapshotId: 's1',
            sessionId: 'sess',
            custom: {'v': 1},
            status: SnapshotStatus.pending,
          ),
        );
        // Upgrade pending -> completed in place, mirroring the detached-run
        // upgrade path.
        final id = await store.saveSnapshot('s1', (current) {
          current!.status = SnapshotStatus.completed;
          return current;
        });
        expect(id, 's1');
        final loaded = await store.getSnapshot(snapshotId: 's1');
        expect(loaded!.status?.value, 'completed');
        expect(loaded.state?.custom, {'v': 1});
      });
    });

    group('pointer advancement', () {
      test('does not regress to a backdated older leaf', () async {
        final store = newStore(checkpointInterval: 100);
        await store.saveSnapshot(
          'a',
          (_) => _snap(
            snapshotId: 'a',
            sessionId: 'sess',
            createdAt: '2020-01-01T00:00:00.000Z',
            custom: {'v': 1},
          ),
        );
        // Newer leaf, saved first.
        await store.saveSnapshot(
          'newer',
          (_) => _snap(
            snapshotId: 'newer',
            sessionId: 'sess',
            parentId: 'a',
            createdAt: '2020-01-01T00:00:02.000Z',
            custom: {'v': 2},
          ),
        );
        // Older (backdated) leaf, saved after: it must not clobber the pointer.
        await store.saveSnapshot(
          'older',
          (_) => _snap(
            snapshotId: 'older',
            sessionId: 'sess',
            parentId: 'a',
            createdAt: '2020-01-01T00:00:01.000Z',
            custom: {'v': 3},
          ),
        );

        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'newer');
        expect(leaf.state?.custom, {'v': 2});
        // Both leaves are still individually addressable by snapshotId.
        expect((await store.getSnapshot(snapshotId: 'older'))!.state?.custom, {
          'v': 3,
        });
      });

      test('advances to a strictly newer leaf', () async {
        final store = newStore(checkpointInterval: 100);
        await store.saveSnapshot(
          'a',
          (_) => _snap(
            snapshotId: 'a',
            sessionId: 'sess',
            createdAt: '2020-01-01T00:00:00.000Z',
            custom: {'v': 1},
          ),
        );
        await store.saveSnapshot(
          'b',
          (_) => _snap(
            snapshotId: 'b',
            sessionId: 'sess',
            parentId: 'a',
            createdAt: '2020-01-01T00:00:01.000Z',
            custom: {'v': 2},
          ),
        );
        final leaf = await store.getSnapshot(sessionId: 'sess');
        expect(leaf!.snapshotId, 'b');
        expect(leaf.state?.custom, {'v': 2});
      });
    });

    group('onSnapshotStateChange', () {
      test('fires the callback when the snapshot changes', () async {
        final store = newStore();
        await store.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 1}),
        );

        final seen = <Object?>[];
        final unsub = store.onSnapshotStateChange('s1', (snap) {
          seen.add((snap.state?.custom as Map?)?['v']);
        });
        addTearDown(() => unsub?.call());

        // Initial emit.
        await _waitFor(() => seen.contains(1));

        await store.saveSnapshot(
          's1',
          (current) =>
              _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 2}),
        );
        await _waitFor(() => seen.contains(2));
        expect(seen, containsAllInOrder([1, 2]));
      });

      test('unsubscribe stops further callbacks', () async {
        final store = newStore();
        await store.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 1}),
        );
        var count = 0;
        final unsub = store.onSnapshotStateChange('s1', (_) => count++);
        await _waitFor(() => count >= 1);
        unsub?.call();
        final countAfterUnsub = count;

        await store.saveSnapshot(
          's1',
          (_) => _snap(snapshotId: 's1', sessionId: 'sess', custom: {'v': 2}),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(count, countAfterUnsub);
      });
    });
  });
}

/// Polls [predicate] until it is true or a timeout elapses.
Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
