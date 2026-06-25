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

/// File-system backed session snapshot storage.
///
/// Ported from the Genkit JS `session-stores.ts` (`FileSessionStore`). This
/// library depends on `dart:io`, so it lives behind the `package:genkit/io.dart`
/// entrypoint rather than the browser-safe `package:genkit/genkit.dart`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../exception.dart';
import '../../types.dart';
import 'session.dart';

/// Default interval for the polling fallback used by
/// [FileSessionStore.onSnapshotStateChange].
const Duration _defaultSnapshotWatchPollInterval = Duration(seconds: 2);

/// Validates that a snapshotId is a plain file basename and not a path that
/// could escape the (per-tenant) prefix directory.
///
/// A `snapshotId` can arrive straight off the wire (the abort/getSnapshot
/// actions accept a bare string), so without this an id like `../../foo` would
/// let a caller read or write outside the prefix and break per-tenant
/// isolation.
void _assertSafeSnapshotId(String snapshotId) {
  if (snapshotId.isEmpty ||
      snapshotId.contains('/') ||
      snapshotId.contains(r'\') ||
      snapshotId.contains('\u0000') ||
      snapshotId == '.' ||
      snapshotId == '..') {
    throw GenkitException(
      'Invalid snapshotId: "$snapshotId". A snapshotId must be a plain file '
      'name (no path separators or "..").',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// A `dart:io` file-system backed session snapshot store.
///
/// **Note:** This store is primarily intended for local development and
/// testing. Because `getSnapshot(sessionId: ...)` performs an O(N) scan of all
/// files in the prefix directory, it may become a performance bottleneck in
/// production environments with a large number of sessions.
///
/// Snapshots are stored as flat JSON files keyed by their `snapshotId`, under an
/// optional per-tenant sub-directory prefix:
///
///     dirPath/<prefix>/<snapshotId>.json
///
/// `getSnapshot(sessionId: ...)` scans the prefix directory and selects the
/// single leaf snapshot whose `state.sessionId` matches - there is no separate
/// grouping directory, the `sessionId` lives in each snapshot's state.
class FileSessionStore implements SessionStore, SnapshotChangeNotifier {
  /// Creates a file-backed store rooted at [dirPath] (created if missing).
  ///
  /// - [maxPersistedChainLength]: when set, snapshots older than this many
  ///   entries in a chain are automatically deleted on each save.
  /// - [snapshotPathPrefix]: returns a sub-directory prefix derived from the
  ///   call's `context` (e.g. the authenticated user id), useful for
  ///   multi-tenant isolation: all reads and writes are scoped to that prefix,
  ///   so one tenant can never see another's snapshots. Defaults to `"global"`.
  /// - [rejectBranchingSessions]: when `true`, a `sessionId` lookup that
  ///   resolves to a branched history (more than one leaf) throws
  ///   [StatusCodes.FAILED_PRECONDITION] instead of returning the latest leaf.
  ///   Defaults to `false`; opt in (e.g. in dev) to surface accidental
  ///   branching early.
  /// - [snapshotWatchPollInterval]: polling interval for the
  ///   [onSnapshotStateChange] fallback that backstops the directory watcher
  ///   (which can miss events on some filesystems, e.g. network mounts).
  FileSessionStore(
    String dirPath, {
    this.maxPersistedChainLength,
    this.snapshotPathPrefix,
    this.rejectBranchingSessions = false,
    Duration snapshotWatchPollInterval = _defaultSnapshotWatchPollInterval,
  }) : _dir = Directory(dirPath).absolute,
       _snapshotWatchPollInterval = snapshotWatchPollInterval {
    _dir.createSync(recursive: true);
  }

  final Directory _dir;

  /// When set, a chain longer than this is trimmed (oldest first) on each save.
  final int? maxPersistedChainLength;

  /// Derives the per-tenant sub-directory prefix from the call's `context`.
  final String Function(Map<String, dynamic>? context)? snapshotPathPrefix;

  /// Whether a branched `sessionId` lookup is rejected instead of resolving to
  /// the most-recent leaf.
  final bool rejectBranchingSessions;

  final Duration _snapshotWatchPollInterval;

  /// Per-file write locks.
  ///
  /// The [SessionStore] contract (and the abort-aware mutator that branches on
  /// `current.status`) assumes read-modify-write is atomic, but on the file
  /// system a read and the write below it are not. Without a lock two
  /// concurrent saves can read the same `current` and the later write clobbers
  /// the earlier one (e.g. a `completed` write overwriting a concurrent
  /// `aborted`). We serialize saves per resolved file path with a promise
  /// chain.
  final Map<String, Future<void>> _writeLocks = {};

  /// Resolves the (per-tenant) directory snapshots are stored under.
  Directory _prefixDir(Map<String, dynamic>? context) {
    final prefix = snapshotPathPrefix?.call(context) ?? 'global';
    return Directory('${_dir.path}${Platform.pathSeparator}$prefix');
  }

  /// Resolves the file for a given snapshotId: `<prefix>/<snapshotId>.json`.
  Future<File> _fileFor(
    String snapshotId,
    Map<String, dynamic>? context,
  ) async {
    _assertSafeSnapshotId(snapshotId);
    final dir = _prefixDir(context);
    await dir.create(recursive: true);
    return File('${dir.path}${Platform.pathSeparator}$snapshotId.json');
  }

  /// Serializes async work per resolved file path so a read-modify-write in
  /// [saveSnapshot] is not interleaved with a concurrent one for the same
  /// snapshot (see [_writeLocks]).
  Future<T> _withFileLock<T>(String path, Future<T> Function() fn) async {
    final prev = _writeLocks[path] ?? Future<void>.value();
    final completer = Completer<void>();
    // Ignore the prior save's result/error so a failure doesn't poison the
    // lock for subsequent callers.
    _writeLocks[path] = completer.future;
    await prev.then<void>((_) {}, onError: (_) {});
    try {
      return await fn();
    } finally {
      completer.complete();
      // If no one chained after us we are the tail; drop the entry to avoid
      // leaking a map entry per snapshotId.
      if (_writeLocks[path] == completer.future) {
        _writeLocks.remove(path);
      }
    }
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) async {
    final normalized = normalizeGetSnapshotOptions(
      snapshotId: snapshotId,
      sessionId: sessionId,
    );

    if (normalized.sessionId != null) {
      return _latestSnapshotForSession(normalized.sessionId!, context);
    }
    return _snapshotById(normalized.snapshotId!, context);
  }

  /// Loads a single snapshot file by its id (no sessionId branch). Used both by
  /// direct id lookups and by internal traversal (parent chains).
  Future<SessionSnapshot?> _snapshotById(
    String snapshotId,
    Map<String, dynamic>? context,
  ) async {
    final file = await _fileFor(snapshotId, context);
    if (!file.existsSync()) return null;
    return SessionSnapshot.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  /// Resolves the latest (leaf) snapshot for a session by scanning every
  /// snapshot file in the (per-tenant) prefix directory, keeping those whose
  /// `state.sessionId` matches, and selecting the single leaf.
  Future<SessionSnapshot?> _latestSnapshotForSession(
    String sessionId,
    Map<String, dynamic>? context,
  ) async {
    final dir = _prefixDir(context);
    if (!dir.existsSync()) return null;

    final snapshots = <SessionSnapshot>[];
    try {
      await for (final entry in dir.list()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        try {
          final snap = SessionSnapshot.fromJson(
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
          );
          if (snapshotSessionId(snap) == sessionId) snapshots.add(snap);
        } catch (_) {
          // Skip corrupted, malformed, or concurrently deleted files so a
          // single bad file does not break the whole scan.
          continue;
        }
      }
    } catch (_) {
      // Directory listing/access error: degrade gracefully.
    }

    return selectLeafSnapshot(
      snapshots,
      sessionId,
      rejectBranching: rejectBranchingSessions,
    );
  }

  @override
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator, {
    Map<String, dynamic>? context,
  }) async {
    // When an ID is supplied the read-modify-write below must be serialized
    // against concurrent saves of the same snapshot, otherwise a later write
    // (e.g. `completed`) can clobber an earlier concurrent one (e.g.
    // `aborted`). New (UUID) snapshots have no contender, so skip the lock.
    if (snapshotId != null && snapshotId.isNotEmpty) {
      final file = await _fileFor(snapshotId, context);
      return _withFileLock(
        file.path,
        () => _saveSnapshotUnlocked(snapshotId, mutator, context),
      );
    }
    return _saveSnapshotUnlocked(snapshotId, mutator, context);
  }

  Future<String?> _saveSnapshotUnlocked(
    String? snapshotId,
    SnapshotMutator mutator,
    Map<String, dynamic>? context,
  ) async {
    final hasId = snapshotId != null && snapshotId.isNotEmpty;
    final current = hasId ? await _snapshotById(snapshotId, context) : null;

    final result = mutator(current);
    if (result == null) return null;

    // Determine the final ID. The runtime normally supplies a snapshotId, but
    // fall back to a fresh UUID for direct store users who omit it.
    final id = hasId
        ? snapshotId
        : (result.snapshotId.isNotEmpty ? result.snapshotId : generateUuidV4());
    result.snapshotId = id;

    final file = await _fileFor(id, context);
    await _atomicWrite(
      file,
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );

    final maxChain = maxPersistedChainLength;
    if (maxChain != null && maxChain > 0) {
      await _trimChain(result, maxChain, context);
    }

    return id;
  }

  /// Deletes snapshots older than [maxChain] entries back from [head] along the
  /// `parentId` chain.
  Future<void> _trimChain(
    SessionSnapshot head,
    int maxChain,
    Map<String, dynamic>? context,
  ) async {
    final chain = <String>[];
    final visited = <String>{};
    SessionSnapshot? cur = head;
    // `visited.add` returns false on a repeat, breaking on a cyclic parent
    // chain (corrupt data) instead of looping forever.
    while (cur != null && visited.add(cur.snapshotId)) {
      chain.add(cur.snapshotId);
      final parentId = cur.parentId;
      cur = parentId != null ? await _snapshotById(parentId, context) : null;
    }

    for (var i = maxChain; i < chain.length; i++) {
      final file = await _fileFor(chain[i], context);
      try {
        await file.delete();
      } on PathNotFoundException {
        // Already gone; nothing to do.
      }
    }
  }

  /// Writes [contents] to [file] atomically: write to a temp file in the same
  /// directory, then rename over the target. `rename` is atomic on POSIX and
  /// Windows, so a concurrent reader in `getSnapshot` never observes a
  /// half-written (torn) file.
  Future<void> _atomicWrite(File file, String contents) async {
    final tmp = File('${file.path}.$pid.${generateUuidV4()}.tmp');
    try {
      await tmp.writeAsString(contents);
      await tmp.rename(file.path);
    } catch (e) {
      try {
        await tmp.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
      rethrow;
    }
  }

  /// Watches a single snapshot file for changes and invokes [callback] with the
  /// parsed snapshot whenever it changes.
  ///
  /// Unlike [InMemorySessionStore], file-backed snapshots are frequently
  /// mutated by a *different* process (e.g. the request handler that received an
  /// abort writes `status: 'aborted'`, while a detached background worker is the
  /// one watching). Detecting that requires observing the filesystem rather
  /// than in-process `saveSnapshot` calls.
  ///
  /// Reliability comes from two layers:
  /// - A directory watcher (`Directory.watch`) filtered to the target
  ///   `<snapshotId>.json`. This is low latency but can miss events on some
  ///   filesystems (network mounts, certain container volumes).
  /// - A polling fallback (`snapshotWatchPollInterval`) that re-reads the file
  ///   on an interval, backstopping any events the watcher drops.
  ///
  /// Callbacks are de-duplicated by serialized content, so the noisy/duplicate
  /// events the watcher emits collapse into one callback per real change.
  /// Transient read errors (e.g. a partially written file mid-rewrite, or a
  /// not-yet-created file) are swallowed; the next event/poll re-reads.
  ///
  /// Returns an unsubscribe function that stops watching and polling.
  @override
  void Function()? onSnapshotStateChange(
    String snapshotId,
    void Function(SessionSnapshot snapshot) callback, {
    Map<String, dynamic>? context,
  }) {
    final dir = _prefixDir(context)..createSync(recursive: true);
    final fileName = '$snapshotId.json';
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');

    var closed = false;
    var isReading = false;
    var needsRecheck = false;
    String? lastSerialized;

    // Re-read the file and fire the callback only when the content actually
    // changed. Watchers fire multiple events per write, so dedupe by content.
    // A non-overlapping loop (isReading / needsRecheck) ensures concurrent
    // events/poll ticks process sequentially without dropping a change.
    Future<void> emitIfChanged() async {
      if (closed) return;
      if (isReading) {
        needsRecheck = true;
        return;
      }
      isReading = true;
      try {
        do {
          needsRecheck = false;
          String contents;
          try {
            contents = await file.readAsString();
          } catch (_) {
            // Missing file (not yet created) or a transient read error during a
            // concurrent rewrite: ignore and wait for the next event/poll.
            continue;
          }
          if (closed || contents == lastSerialized) continue;
          SessionSnapshot snapshot;
          try {
            snapshot = SessionSnapshot.fromJson(
              jsonDecode(contents) as Map<String, dynamic>,
            );
          } catch (_) {
            // Partially written file mid-rewrite: skip without updating
            // lastSerialized so the next event/poll re-reads the complete file.
            continue;
          }
          lastSerialized = contents;
          callback(snapshot);
        } while (needsRecheck && !closed);
      } finally {
        isReading = false;
      }
    }

    // Watch the directory (not the file) so this still works before the file
    // exists and survives atomic rename-replace writes that swap the inode.
    StreamSubscription<FileSystemEvent>? watcher;
    try {
      watcher = dir.watch().listen((event) {
        if (event.path == file.path) unawaited(emitIfChanged());
      });
    } catch (_) {
      // Some environments disallow directory watching; polling covers us.
    }

    final pollTimer = Timer.periodic(
      _snapshotWatchPollInterval,
      (_) => unawaited(emitIfChanged()),
    );

    // Surface the current state immediately (if the file already exists).
    unawaited(emitIfChanged());

    return () {
      closed = true;
      unawaited(watcher?.cancel());
      pollTimer.cancel();
    };
  }
}
