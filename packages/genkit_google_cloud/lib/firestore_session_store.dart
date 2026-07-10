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

/// A Firestore-backed [SessionStore] for Genkit agents.
///
/// Ported from the Genkit JS `FirestoreSessionStore`, this store persists
/// session snapshots as incremental JSON Patch diffs anchored to periodic,
/// sharded full-state checkpoints, so it scales to arbitrarily long sessions
/// without any single document approaching Firestore's 1 MiB limit.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:logging/logging.dart';

final _logger = Logger('genkit.firestoreSessionStore');

/// Default number of turns between full-state checkpoints.
///
/// Chosen to favor the common chat workload, where per-turn state is small and
/// read cost dominates. Per-save reconstruction reads grow ~linearly with the
/// interval while checkpoint write/storage cost shrinks with it, so the op-cost
/// optimum is roughly `sqrt(6 * checkpointShardCount)` (small for tiny state);
/// 25 sits near that optimum for chat while staying conservative for larger
/// states. Raise it (e.g. 50-100) for large per-turn state retained long-term;
/// lower it (e.g. 10) for small-state, read-heavy sessions.
const int defaultCheckpointInterval = 25;

/// Default maximum size (in bytes) of a single shard / diff document. Kept well
/// under Firestore's 1 MiB per-document limit so that no individual write can
/// be rejected for being too large.
const int defaultShardSize = 512 * 1024;

/// Fallback prefix used when no [FirestoreSessionStore.snapshotPathPrefix] is
/// configured.
const String _defaultPrefix = 'global';

/// Default polling interval for [FirestoreSessionStore.onSnapshotStateChange].
const Duration _defaultSnapshotWatchPollInterval = Duration(seconds: 2);

/// Snapshot statuses that are terminal: once a snapshot reaches one of these it
/// is immutable and may have descendants, so it must never be upserted in place
/// (doing so would prune/rewrite shards its descendants still depend on). Kept
/// in sync with the core runtime's terminal-status set.
const Set<String> _terminalStatuses = {
  'completed',
  'failed',
  'aborted',
  'expired',
};

/// Firestore document data is a plain string-keyed map.
typedef _Doc = Map<String, Object?>;

/// Chain metadata needed to materialize a snapshot: its nearest checkpoint, the
/// checkpoint's shard count and the ordered diff segment leading to it.
typedef _ChainMeta = ({
  String checkpointId,
  int checkpointShardCount,
  List<String> segmentPath,
});

/// The result of writing (or planning) a snapshot document's chain position.
typedef _ChainWrite = ({
  String kind,
  String checkpointId,
  int checkpointShardCount,
  List<String> segmentPath,
  JsonPatch? statePatch,
});

/// A reconstructed snapshot: its persisted document plus materialized state.
typedef _Reconstructed = ({_SnapshotDoc doc, Map<String, dynamic> state});

/// A minimal batched read interface over a [Transaction].
///
/// Both `get` and `getAll` are document-ID lookups, which Firestore serves with
/// strong consistency (unlike queries), keeping reconstruction deterministic.
/// All reads run inside a transaction (read-only for `getSnapshot`, read-write
/// for `saveSnapshot`), so a single consistent snapshot of the chain is
/// observed even while another writer is mutating shards in place.
class _Reader {
  _Reader(this._tx);
  final Transaction _tx;

  Future<DocumentSnapshot<_Doc>> get(DocumentReference<_Doc> ref) =>
      _tx.get(ref);

  Future<List<DocumentSnapshot<_Doc>>> getAll(
    List<DocumentReference<_Doc>> refs,
  ) async => refs.isEmpty ? const [] : _tx.getAll(refs);
}

/// The persisted shape of a snapshot document.
///
/// A session's history is stored as a chain of per-turn documents that come in
/// two kinds:
///
/// - `checkpoint` - a full materialization of the session state at that turn,
///   stored out of band (sharded across the shards collection) so it never
///   approaches the 1 MiB document limit.
/// - `diff` - only the [JsonPatch] (`statePatch`) that transforms its parent's
///   state into its own.
///
/// Every document carries the metadata needed to reconstruct it with a single
/// batched, strongly-consistent `getAll`: `checkpointId` (the nearest
/// checkpoint ancestor), `checkpointShardCount`, and `segmentPath` (the ordered
/// diff IDs from that checkpoint down to this document).
class _SnapshotDoc {
  _SnapshotDoc({
    required this.snapshotId,
    required this.sessionId,
    this.parentId,
    required this.createdAt,
    this.updatedAt,
    this.status,
    this.heartbeatAt,
    this.finishReason,
    this.error,
    required this.kind,
    required this.checkpointId,
    required this.checkpointShardCount,
    required this.segmentPath,
    this.statePatch,
  });

  factory _SnapshotDoc.fromData(Map<String, Object?> d) => _SnapshotDoc(
    snapshotId: d['snapshotId'] as String,
    sessionId: d['sessionId'] as String,
    parentId: d['parentId'] as String?,
    createdAt: d['createdAt'] as String,
    updatedAt: d['updatedAt'] as String?,
    status: d['status'] as String?,
    heartbeatAt: d['heartbeatAt'] as String?,
    finishReason: d['finishReason'] as String?,
    error: (d['error'] as Map?)?.cast<String, dynamic>(),
    kind: d['kind'] as String,
    checkpointId: d['checkpointId'] as String,
    checkpointShardCount: (d['checkpointShardCount'] as num).toInt(),
    segmentPath: (d['segmentPath'] as List?)?.cast<String>() ?? const [],
    statePatch: (d['statePatch'] as List?)
        ?.map((e) => (e as Map).cast<String, dynamic>())
        .toList(),
  );

  final String snapshotId;
  final String sessionId;
  final String? parentId;
  final String createdAt;
  final String? updatedAt;
  final String? status;
  final String? heartbeatAt;
  final String? finishReason;
  final Map<String, dynamic>? error;
  final String kind;
  final String checkpointId;
  final int checkpointShardCount;
  final List<String> segmentPath;
  final JsonPatch? statePatch;

  /// Serializes to a Firestore document, omitting `null` members (matching the
  /// JS port, which strips `undefined`).
  Map<String, Object?> toData() => {
    'snapshotId': snapshotId,
    'sessionId': sessionId,
    if (parentId != null) 'parentId': parentId,
    'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (status != null) 'status': status,
    if (heartbeatAt != null) 'heartbeatAt': heartbeatAt,
    if (finishReason != null) 'finishReason': finishReason,
    if (error != null) 'error': error,
    'kind': kind,
    'checkpointId': checkpointId,
    'checkpointShardCount': checkpointShardCount,
    'segmentPath': segmentPath,
    if (statePatch != null) 'statePatch': statePatch,
  };
}

/// The per-session pointer document. Tracks the current leaf snapshot and the
/// metadata needed to reconstruct it (its checkpoint, shard count and segment
/// path) so the common `sessionId` lookup is a single pointer read followed by
/// one batched `getAll`. It deliberately does not cache the full state, so it
/// can never approach the 1 MiB limit no matter how long the session grows.
class _PointerDoc {
  _PointerDoc({
    required this.currentSnapshotId,
    required this.checkpointId,
    required this.checkpointShardCount,
    required this.segmentPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _PointerDoc.fromData(Map<String, Object?> d) => _PointerDoc(
    currentSnapshotId: d['currentSnapshotId'] as String,
    checkpointId: d['checkpointId'] as String,
    checkpointShardCount: (d['checkpointShardCount'] as num).toInt(),
    segmentPath: (d['segmentPath'] as List?)?.cast<String>() ?? const [],
    createdAt: d['createdAt'] as String? ?? '',
    updatedAt: d['updatedAt'] as String? ?? '',
  );

  final String currentSnapshotId;
  final String checkpointId;
  final int checkpointShardCount;
  final List<String> segmentPath;

  /// The `createdAt` of [currentSnapshotId]. Used to gate pointer advancement
  /// so a concurrently-committed or backdated older leaf can never clobber a
  /// newer one (see `saveSnapshot`).
  final String createdAt;
  final String updatedAt;

  Map<String, Object?> toData() => {
    'currentSnapshotId': currentSnapshotId,
    'checkpointId': checkpointId,
    'checkpointShardCount': checkpointShardCount,
    'segmentPath': segmentPath,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

/// Normalizes a JSON-serializable value to plain objects (`Map`, `List`,
/// primitives), matching how snapshot state is diffed and reconstructed.
Object? _sanitize(Object? value) => jsonDecode(jsonEncode(value));

/// UTF-8 byte length of a JSON-serializable value.
int _byteLength(Object? value) => utf8.encode(jsonEncode(value)).length;

/// Normalizes and validates `getSnapshot` options.
///
/// Enforces that exactly one of [snapshotId] / [sessionId] is provided
/// (mirroring JS truthiness: an empty-string id is treated as absent, so a
/// blank id coming straight off the wire does not satisfy the requirement).
({String? snapshotId, String? sessionId}) _normalizeGetSnapshotOptions(
  String? snapshotId,
  String? sessionId,
) {
  final hasSnapshot = snapshotId != null && snapshotId.isNotEmpty;
  final hasSession = sessionId != null && sessionId.isNotEmpty;
  if (hasSnapshot == hasSession) {
    throw GenkitException(
      "getSnapshot requires exactly one of 'snapshotId' or 'sessionId' "
      "(got ${hasSnapshot ? 'snapshotId' : 'neither'}"
      "${hasSession ? ' and sessionId' : ''}).",
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return (
    snapshotId: hasSnapshot ? snapshotId : null,
    sessionId: hasSession ? sessionId : null,
  );
}

/// Resolves the id a snapshot should be stored under: prefer the explicitly
/// [requestedId], otherwise reuse the id already on [result], otherwise mint a
/// fresh UUID.
String _resolveSnapshotId(String? requestedId, SessionSnapshot result) {
  if (requestedId != null && requestedId.isNotEmpty) return requestedId;
  final resultId = result.snapshotId;
  return resultId.isNotEmpty ? resultId : generateUuidV4();
}

/// Returns the sessionId a snapshot belongs to, preferring the top-level
/// `sessionId` and falling back to `state.sessionId`.
String? _snapshotSessionId(SessionSnapshot snapshot) =>
    snapshot.sessionId ?? snapshot.state?.sessionId;

/// Compares two `createdAt` timestamps, preferring to parse them to a UTC
/// instant so mixed ISO-8601 offset formats (e.g. `...+05:00` vs `...Z`) order
/// correctly; falls back to a lexicographic compare when either can't be parsed
/// (so it never throws on malformed input). Mirrors `selectLeafSnapshot`.
int _compareCreatedAt(String a, String b) {
  final aTime = DateTime.tryParse(a)?.toUtc();
  final bTime = DateTime.tryParse(b)?.toUtc();
  if (aTime != null && bTime != null) return aTime.compareTo(bTime);
  return a.compareTo(b);
}

/// Whether the leaf `(aCreatedAt, aId)` is strictly newer than
/// `(bCreatedAt, bId)`, using the same `(createdAt, snapshotId)` ordering as
/// `selectLeafSnapshot` and the Go store: compare `createdAt`, breaking exact
/// ties by `snapshotId`. Strictly-greater means an older-or-equal leaf never
/// wins, so a backdated or concurrently-committed leaf can't clobber a newer
/// one.
bool _isNewerLeaf(
  String aCreatedAt,
  String aId,
  String bCreatedAt,
  String bId,
) {
  final cmp = _compareCreatedAt(aCreatedAt, bCreatedAt);
  if (cmp != 0) return cmp > 0;
  return aId.compareTo(bId) > 0;
}

/// A Firestore-backed [SessionStore] that persists session snapshots as
/// incremental JSON Patch diffs anchored to periodic, sharded full-state
/// checkpoints.
///
/// Storage layout (the `<prefix>` segment is the per-tenant prefix returned by
/// [snapshotPathPrefix], or `"global"` when none is configured):
///
/// - `<collection>/<prefix>/snapshots/<snapshotId>` - one document per
///   snapshot. A `diff` document holds the patch from its parent
///   (`statePatch`); a `checkpoint` document holds a full-state materialization
///   (sharded out of band).
/// - `<collection>-shards/<prefix>/shards/<checkpointId>_<index>` - the sharded
///   full state for a checkpoint.
/// - `<collection>-pointers/<prefix>/pointers/<sessionId>` - one document per
///   session pointing at the latest leaf snapshot and the metadata needed to
///   reconstruct it.
///
/// Reconstruction uses only document-ID lookups (`getAll`), so it needs no
/// secondary indexes and is strongly consistent. No single document approaches
/// the 1 MiB limit (state is sharded by [shardSize]), and the number of *diff*
/// documents touched per read/write is bounded by [checkpointInterval] rather
/// than total session length.
///
/// ## Emulator
///
/// The underlying `google_cloud_firestore` client honors the
/// `FIRESTORE_EMULATOR_HOST` environment variable (e.g. `localhost:8080`), so a
/// store created with the default [Firestore] instance transparently targets a
/// local emulator when that variable is set.
///
/// ## Real-time changes
///
/// Unlike the JS port (which uses Firestore's live `onSnapshot` listener), the
/// Dart Firestore client has no real-time listener, so
/// [onSnapshotStateChange] is implemented by polling. Tune the latency via the
/// `snapshotWatchPollInterval` constructor argument.
class FirestoreSessionStore implements SessionStore, SnapshotChangeNotifier {
  /// Creates a Firestore-backed session store.
  ///
  /// - [db]: an explicit [Firestore] instance. Defaults to a new [Firestore]
  ///   (which picks up Application Default Credentials and the
  ///   `FIRESTORE_EMULATOR_HOST` environment variable).
  /// - [collection]: the collection where snapshot documents are stored.
  ///   Defaults to `"genkit-sessions"`. Two companion collections are derived
  ///   from it: `"<collection>-pointers"` and `"<collection>-shards"`.
  /// - [checkpointInterval]: number of turns between full-state checkpoints.
  ///   Defaults to [defaultCheckpointInterval].
  /// - [shardSize]: maximum size in bytes of a single shard / diff document.
  ///   Defaults to [defaultShardSize].
  /// - [snapshotPathPrefix]: returns a per-tenant prefix derived from the
  ///   call's `context` (e.g. the authenticated user id). When set, all
  ///   snapshot, pointer and shard documents are nested under a tenant-scoped
  ///   subcollection keyed by this prefix, isolating reads and writes per
  ///   tenant. Defaults to `"global"`.
  /// - [snapshotWatchPollInterval]: polling interval used by
  ///   [onSnapshotStateChange]. Defaults to 2 seconds.
  FirestoreSessionStore({
    Firestore? db,
    this.collection = 'genkit-sessions',
    this.checkpointInterval = defaultCheckpointInterval,
    this.shardSize = defaultShardSize,
    this.snapshotPathPrefix,
    Duration snapshotWatchPollInterval = _defaultSnapshotWatchPollInterval,
  }) : db = db ?? Firestore(),
       _snapshotWatchPollInterval = snapshotWatchPollInterval;

  /// The Firestore instance backing this store.
  final Firestore db;

  /// The root collection snapshot documents are stored under.
  final String collection;

  /// Number of turns between full-state checkpoints.
  final int checkpointInterval;

  /// Maximum size in bytes of a single shard / diff document.
  final int shardSize;

  /// Derives the per-tenant prefix from the call's `context`.
  final String Function(Map<String, dynamic>? context)? snapshotPathPrefix;

  final Duration _snapshotWatchPollInterval;

  /// Resolves the (per-tenant) prefix for the given call context.
  ///
  /// The prefix is used verbatim as a Firestore document id, so a blank prefix
  /// would throw opaquely mid-transaction and a value containing `/` (or `.` /
  /// `..`) would silently nest into a deeper path instead of isolating a
  /// tenant. Reject those up front with a clean `INVALID_ARGUMENT` (matching the
  /// Go store).
  String _prefixFor(Map<String, dynamic>? context) {
    final prefix = snapshotPathPrefix?.call(context) ?? _defaultPrefix;
    if (prefix.trim().isEmpty ||
        prefix.contains('/') ||
        prefix == '.' ||
        prefix == '..') {
      throw GenkitException(
        "FirestoreSessionStore: invalid snapshotPathPrefix '$prefix' - it must "
        "be a non-blank string that is not '.' / '..' and contains no '/'.",
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return prefix;
  }

  /// The (per-tenant) snapshots subcollection.
  CollectionReference<_Doc> _snapshotsCol(Map<String, dynamic>? context) => db
      .collection(collection)
      .doc(_prefixFor(context))
      .collection('snapshots');

  /// The (per-tenant) pointers subcollection.
  CollectionReference<_Doc> _pointersCol(Map<String, dynamic>? context) => db
      .collection('$collection-pointers')
      .doc(_prefixFor(context))
      .collection('pointers');

  /// The (per-tenant) shards subcollection.
  CollectionReference<_Doc> _shardsCol(Map<String, dynamic>? context) => db
      .collection('$collection-shards')
      .doc(_prefixFor(context))
      .collection('shards');

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) {
    final normalized = _normalizeGetSnapshotOptions(snapshotId, sessionId);

    // Reconstruct inside a read-only transaction so the pointer read and the
    // batched shard/diff reads all observe a single, consistent point in time.
    // Without this, a concurrent checkpoint write - which overwrites a
    // checkpoint's shards in place and may delete now-stale trailing shards
    // (see `_writeShards`) - could let a reader stitch together a mix of old
    // and new chunks, yielding a `DATA_LOSS` (missing shard) error or a corrupt
    // JSON decode. A read-only transaction also avoids the contention/retries
    // of a read-write one.
    return db.runTransaction((tx) async {
      final reader = _Reader(tx);

      if (normalized.sessionId != null) {
        final pointerSnap = await tx.get(
          _pointersCol(context).doc(normalized.sessionId!),
        );
        if (!pointerSnap.exists) return null;
        final pointer = _PointerDoc.fromData(pointerSnap.data()!);
        // Reconstruct straight from the pointer's checkpoint metadata - one
        // batched round-trip, no extra read of the leaf document.
        final reconstructed = await _reconstructFrom(
          reader,
          pointer.checkpointId,
          pointer.checkpointShardCount,
          pointer.segmentPath,
          pointer.currentSnapshotId,
          context,
        );
        if (reconstructed == null) return null;
        return _toSnapshot(reconstructed.doc, reconstructed.state);
      }

      final reconstructed = await _reconstruct(
        reader,
        normalized.snapshotId!,
        context,
      );
      if (reconstructed == null) return null;
      return _toSnapshot(reconstructed.doc, reconstructed.state);
    }, transactionOptions: ReadOnlyTransactionOptions());
  }

  @override
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator, {
    Map<String, dynamic>? context,
  }) {
    return db.runTransaction((tx) async {
      final reader = _Reader(tx);

      // Reads phase 1: load the existing snapshot (if any) so the mutator can
      // inspect the current full state.
      _Reconstructed? existing;
      if (snapshotId != null && snapshotId.isNotEmpty) {
        existing = await _reconstruct(reader, snapshotId, context);
      }
      final current = existing != null
          ? _toSnapshot(existing.doc, existing.state)
          : null;

      final result = mutator(current);
      if (result == null) return null;

      final id = _resolveSnapshotId(
        snapshotId != null && snapshotId.isNotEmpty ? snapshotId : null,
        result,
      );
      // Prefer the snapshot's top-level `sessionId`; fall back to the id
      // carried in its state for rows written before snapshot-level ids
      // existed.
      final sessionId = _snapshotSessionId(result);
      if (sessionId == null) {
        throw GenkitException(
          "FirestoreSessionStore requires 'sessionId' to be set on the "
          'snapshot.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }
      final newState = result.state?.toJson() ?? <String, dynamic>{};

      // Reads phase 2: the per-session pointer (current leaf metadata).
      final pointerRef = _pointersCol(context).doc(sessionId);
      final pointerSnap = await tx.get(pointerRef);
      final pointer = pointerSnap.exists
          ? _PointerDoc.fromData(pointerSnap.data()!)
          : null;

      _ChainWrite chain;

      if (existing != null) {
        // Upsert: preserve the document's role and chain position; only the
        // state/metadata change. Callers must only upsert the *leaf* -
        // rewriting a non-leaf snapshot's state would invalidate its
        // descendants' diffs (re-checkpointing prunes trailing shards and
        // promotion nulls a diff's statePatch, either of which corrupts a
        // descendant that still depends on this document's chain position).
        //
        // Nothing enforces "leaf only" at the type level, so enforce the
        // invariant that guarantees it: only a *terminal* snapshot can have
        // descendants (the runtime only ever resumes - and thus parents a child
        // onto - a `completed` snapshot), so a snapshot in a terminal state may
        // already have descendants and must never be rewritten in place. Every
        // legitimate upsert (a detached `pending -> completed` upgrade, an
        // `abort`'s `pending -> aborted`) targets a non-terminal snapshot, so
        // this rejects only genuine misuse - loudly, before any shard is
        // pruned - rather than silently corrupting the chain.
        if (existing.doc.status != null &&
            _terminalStatuses.contains(existing.doc.status)) {
          throw GenkitException(
            "FirestoreSessionStore: cannot upsert snapshot '$id' because it is "
            "in a terminal state ('${existing.doc.status}'). Terminal snapshots "
            'are immutable and may have descendants; write a new child snapshot '
            'instead.',
            status: StatusCodes.FAILED_PRECONDITION,
          );
        }
        if (existing.doc.kind == 'checkpoint') {
          chain = _writeCheckpoint(
            tx,
            id,
            newState,
            context,
            existing.doc.checkpointShardCount,
          );
        } else {
          // Reads phase 3 (diff upsert): resolve parent state for the patch.
          final parentState = existing.doc.parentId != null
              ? (await _reconstruct(
                  reader,
                  existing.doc.parentId!,
                  context,
                ))?.state
              : null;
          final candidatePatch = diff(parentState, newState);
          // Promote an oversized diff to a (sharded) checkpoint so even an
          // in-place leaf rewrite can never push the document past the 1 MiB
          // limit. Safe because callers only upsert the leaf, which has no
          // descendants depending on its chain position.
          if (_byteLength(candidatePatch) > shardSize) {
            chain = _writeCheckpoint(tx, id, newState, context);
          } else {
            chain = (
              kind: 'diff',
              checkpointId: existing.doc.checkpointId,
              checkpointShardCount: existing.doc.checkpointShardCount,
              segmentPath: existing.doc.segmentPath,
              statePatch: candidatePatch,
            );
          }
        }
      } else {
        // New snapshot: resolve the parent's *chain metadata* (no state) to
        // decide diff vs checkpoint. Materializing the parent's full state is
        // deferred until we know we actually need a diff - so the expensive
        // reconstruction is skipped on every checkpoint-boundary turn (which
        // would rewrite the whole state regardless).
        _ChainMeta? parentMeta;
        if (result.parentId != null) {
          parentMeta = await _loadParentChainMeta(
            reader,
            result.parentId!,
            pointer,
            context,
          );
        }

        if (result.parentId == null ||
            parentMeta == null ||
            parentMeta.segmentPath.length + 1 >= checkpointInterval) {
          // Write a full checkpoint without ever reconstructing the parent's
          // state, for any of: a session root, an orphaned parent, or reaching
          // the checkpoint interval (whose final segment is exactly the
          // longest, costliest one we'd otherwise pay to reconstruct here).
          chain = _writeCheckpoint(tx, id, newState, context);
        } else {
          // Diff candidate: now we must materialize the parent's state to
          // compute the patch.
          final parentState = (await _reconstructFrom(
            reader,
            parentMeta.checkpointId,
            parentMeta.checkpointShardCount,
            parentMeta.segmentPath,
            result.parentId!,
            context,
          ))?.state;
          final candidatePatch = diff(parentState, newState);
          // Promote oversized diffs to checkpoints so a single large turn is
          // sharded rather than rejected by the 1 MiB limit.
          if (_byteLength(candidatePatch) > shardSize) {
            chain = _writeCheckpoint(tx, id, newState, context);
          } else {
            chain = (
              kind: 'diff',
              checkpointId: parentMeta.checkpointId,
              checkpointShardCount: parentMeta.checkpointShardCount,
              segmentPath: [...parentMeta.segmentPath, id],
              statePatch: candidatePatch,
            );
          }
        }
      }

      // Writes phase.
      final doc = _SnapshotDoc(
        snapshotId: id,
        sessionId: sessionId,
        parentId: result.parentId,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt ?? result.createdAt,
        status: result.status?.value,
        heartbeatAt: result.heartbeatAt,
        finishReason: result.finishReason?.value,
        error: result.error?.toJson(),
        kind: chain.kind,
        checkpointId: chain.checkpointId,
        checkpointShardCount: chain.checkpointShardCount,
        segmentPath: chain.segmentPath,
        statePatch: chain.statePatch,
      );
      tx.set(
        _snapshotsCol(context).doc(id),
        (_sanitize(doc.toData()) as Map).cast<String, Object?>(),
      );

      // Update the pointer in one of two cases:
      //
      // - Refresh: we just rewrote the snapshot the pointer already tracks
      //   (an in-place leaf upsert), so re-point at its (possibly changed)
      //   chain metadata under the same id.
      // - Advance: a brand-new leaf. When there is no pointer yet it wins
      //   unconditionally; otherwise it must be strictly newer - by
      //   `(createdAt, snapshotId)`, the same ordering `selectLeafSnapshot` and
      //   the Go store use - than the leaf the pointer currently tracks. Gating
      //   on recency (rather than always advancing) means a backdated or
      //   concurrently-committed *older* leaf can't clobber a newer one and
      //   stick, which would otherwise violate the 'most recently created leaf'
      //   contract under clock skew / concurrency. We rely on `(createdAt, id)`
      //   here rather than a full-collection scan fallback (as InMemory/File
      //   do) so `sessionId` resolution stays a single pointer read - the whole
      //   point of the pointer design.
      final isNew = existing == null;
      final isRefresh = pointer != null && pointer.currentSnapshotId == id;
      final advances =
          isNew &&
          (pointer == null ||
              _isNewerLeaf(
                result.createdAt,
                id,
                pointer.createdAt,
                pointer.currentSnapshotId,
              ));
      if (isRefresh || advances) {
        tx.set(
          pointerRef,
          _PointerDoc(
            currentSnapshotId: advances ? id : pointer!.currentSnapshotId,
            checkpointId: chain.checkpointId,
            checkpointShardCount: chain.checkpointShardCount,
            segmentPath: chain.segmentPath,
            createdAt: result.createdAt,
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ).toData(),
        );
      }

      return id;
    });
  }

  /// Watches a snapshot for state changes via polling and invokes [callback]
  /// with the reconstructed snapshot whenever it changes.
  ///
  /// The Dart Firestore client has no real-time listener, so this re-reads the
  /// snapshot on the configured `snapshotWatchPollInterval`, de-duplicating by
  /// serialized content so only real changes fire the callback. Transient read
  /// failures (network / permission) are swallowed; the next poll retries.
  ///
  /// Returns an unsubscribe function that stops polling.
  @override
  void Function()? onSnapshotStateChange(
    String snapshotId,
    void Function(SessionSnapshot snapshot) callback, {
    Map<String, dynamic>? context,
  }) {
    var closed = false;
    var isReading = false;
    String? lastSerialized;

    Future<void> poll() async {
      if (closed || isReading) return;
      isReading = true;
      try {
        final snapshot = await getSnapshot(
          snapshotId: snapshotId,
          context: context,
        );
        if (closed || snapshot == null) return;
        final serialized = jsonEncode(snapshot.toJson());
        if (serialized == lastSerialized) return;
        lastSerialized = serialized;
        callback(snapshot);
      } catch (err) {
        // Swallow errors so a transient read failure doesn't crash the poller.
        // The next tick retries.
        _logger.warning(
          'FirestoreSessionStore.onSnapshotStateChange failed to load '
          'snapshot $snapshotId',
          err,
        );
      } finally {
        isReading = false;
      }
    }

    final timer = Timer.periodic(
      _snapshotWatchPollInterval,
      (_) => unawaited(poll()),
    );
    // Surface the current state immediately (if the snapshot already exists).
    unawaited(poll());

    return () {
      closed = true;
      timer.cancel();
    };
  }

  /// Resolves a parent's chain metadata (nearest checkpoint, shard count and
  /// segment path) *without* materializing its - potentially large - state.
  ///
  /// In the common linear case the parent is the session's current leaf, so the
  /// metadata is read straight off the pointer and this performs *zero*
  /// document reads. Otherwise it reads the single parent document.
  Future<_ChainMeta?> _loadParentChainMeta(
    _Reader reader,
    String parentId,
    _PointerDoc? pointer,
    Map<String, dynamic>? context,
  ) async {
    if (pointer != null && pointer.currentSnapshotId == parentId) {
      return (
        checkpointId: pointer.checkpointId,
        checkpointShardCount: pointer.checkpointShardCount,
        segmentPath: pointer.segmentPath,
      );
    }
    final snap = await reader.get(_snapshotsCol(context).doc(parentId));
    if (!snap.exists) return null;
    final d = _SnapshotDoc.fromData(snap.data()!);
    return (
      checkpointId: d.checkpointId,
      checkpointShardCount: d.checkpointShardCount,
      segmentPath: d.segmentPath,
    );
  }

  /// Reconstructs the state of [id] by reading its document to learn its
  /// checkpoint and segment path, then materializing from that checkpoint.
  /// Returns `null` when the snapshot does not exist.
  Future<_Reconstructed?> _reconstruct(
    _Reader reader,
    String id,
    Map<String, dynamic>? context,
  ) async {
    final snap = await reader.get(_snapshotsCol(context).doc(id));
    if (!snap.exists) return null;
    final d = _SnapshotDoc.fromData(snap.data()!);
    return _reconstructFrom(
      reader,
      d.checkpointId,
      d.checkpointShardCount,
      d.segmentPath,
      id,
      context,
    );
  }

  /// Materializes the state of [targetId] from a known checkpoint using a
  /// single batched, strongly-consistent `getAll`: the checkpoint's shards, the
  /// (bounded) segment of diff documents along [segmentPath], and - only when
  /// the target *is* the checkpoint - the checkpoint document itself. The diffs
  /// are then applied in order onto the checkpoint's state.
  ///
  /// Note: when [segmentPath] is non-empty the state comes entirely from the
  /// shards and the target's metadata from the last segment document, so the
  /// checkpoint *document* is not read - saving one read on the common path.
  Future<_Reconstructed?> _reconstructFrom(
    _Reader reader,
    String checkpointId,
    int shardCount,
    List<String> segmentPath,
    String targetId,
    Map<String, dynamic>? context,
  ) async {
    final targetIsCheckpoint = segmentPath.isEmpty;
    final snapshotsCol = _snapshotsCol(context);
    final shardsCol = _shardsCol(context);
    final checkpointRef = snapshotsCol.doc(checkpointId);
    final shardRefs = [
      for (var i = 0; i < shardCount; i++) shardsCol.doc('${checkpointId}_$i'),
    ];
    final segRefs = [for (final sid in segmentPath) snapshotsCol.doc(sid)];

    final snaps = await reader.getAll([
      // The checkpoint document is only needed when it is itself the target;
      // otherwise the last segment document carries the target metadata.
      if (targetIsCheckpoint) checkpointRef,
      ...shardRefs,
      ...segRefs,
    ]);

    // `getAll` does not guarantee result order matches request order, so index
    // the snapshots by their (fully-qualified) path and look each up
    // explicitly.
    final byPath = <String, DocumentSnapshot<_Doc>>{
      for (final s in snaps) s.ref.path: s,
    };

    final shardSnaps = [for (final ref in shardRefs) byPath[ref.path]!];
    var state = _stitch(shardSnaps);

    if (targetIsCheckpoint) {
      final checkpointSnap = byPath[checkpointRef.path];
      if (checkpointSnap == null || !checkpointSnap.exists) return null;
      final checkpointDoc = _SnapshotDoc.fromData(checkpointSnap.data()!);
      if (checkpointDoc.snapshotId != targetId) return null;
      return (
        doc: checkpointDoc,
        state: (state as Map<String, dynamic>?) ?? <String, dynamic>{},
      );
    }

    _SnapshotDoc? targetDoc;
    for (final ref in segRefs) {
      final segSnap = byPath[ref.path];
      if (segSnap == null || !segSnap.exists) return null; // Corrupt chain.
      final segDoc = _SnapshotDoc.fromData(segSnap.data()!);
      state = applyPatch(state, segDoc.statePatch ?? const []);
      targetDoc = segDoc;
    }

    if (targetDoc == null || targetDoc.snapshotId != targetId) return null;
    return (
      doc: targetDoc,
      state: (state as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
  }

  /// Serializes [state] to UTF-8, splits it into [shardSize]-byte chunks, and
  /// writes them at `<checkpointId>_<index>`. When [oldShardCount] exceeds the
  /// new count (a shrinking re-checkpoint), the now-stale trailing shards are
  /// deleted. Returns the number of shards written.
  int _writeShards(
    Transaction tx,
    String checkpointId,
    Map<String, dynamic> state,
    Map<String, dynamic>? context, [
    int oldShardCount = 0,
  ]) {
    final shardsCol = _shardsCol(context);
    final buf = utf8.encode(jsonEncode(state));
    final count = buf.isEmpty ? 1 : ((buf.length + shardSize - 1) ~/ shardSize);
    for (var i = 0; i < count; i++) {
      final start = i * shardSize;
      final end = (start + shardSize) < buf.length
          ? (start + shardSize)
          : buf.length;
      // `buf.sublist` already returns an independent `Uint8List` copy, so the
      // Firestore serializer persists exactly these bytes.
      final chunk = buf.sublist(start, end);
      tx.set(shardsCol.doc('${checkpointId}_$i'), {'chunk': chunk});
    }
    for (var i = count; i < oldShardCount; i++) {
      tx.delete(shardsCol.doc('${checkpointId}_$i'));
    }
    return count;
  }

  /// Writes a full-state checkpoint at [id] (sharding the state via
  /// [_writeShards]) and returns the chain metadata describing it: a checkpoint
  /// anchors itself (`checkpointId == id`), has an empty `segmentPath`, and
  /// carries no `statePatch`.
  ///
  /// Pass [oldShardCount] when re-checkpointing an existing checkpoint so stale
  /// trailing shards are pruned.
  _ChainWrite _writeCheckpoint(
    Transaction tx,
    String id,
    Map<String, dynamic> state,
    Map<String, dynamic>? context, [
    int oldShardCount = 0,
  ]) => (
    kind: 'checkpoint',
    checkpointId: id,
    checkpointShardCount: _writeShards(tx, id, state, context, oldShardCount),
    segmentPath: const [],
    statePatch: null,
  );

  /// Concatenates ordered shard documents and decodes the materialized state.
  Object? _stitch(List<DocumentSnapshot<_Doc>> shardSnaps) {
    if (shardSnaps.isEmpty) return null;
    final builder = BytesBuilder(copy: false);
    for (final s in shardSnaps) {
      if (!s.exists) {
        throw GenkitException(
          "FirestoreSessionStore: missing checkpoint shard '${s.id}'.",
          status: StatusCodes.DATA_LOSS,
        );
      }
      builder.add((s.data()!['chunk'] as List).cast<int>());
    }
    return jsonDecode(utf8.decode(builder.toBytes()));
  }

  /// Assembles a [SessionSnapshot] from a document and its state.
  SessionSnapshot _toSnapshot(_SnapshotDoc doc, Map<String, dynamic> state) {
    final json = <String, dynamic>{
      'snapshotId': doc.snapshotId,
      'sessionId': doc.sessionId,
      'createdAt': doc.createdAt,
      // Normalize to plain objects: values reconstructed from Firestore
      // documents (e.g. patch operands) can carry non-plain types.
      'state': _sanitize(state),
      if (doc.parentId != null) 'parentId': doc.parentId,
      if (doc.updatedAt != null) 'updatedAt': doc.updatedAt,
      if (doc.status != null) 'status': doc.status,
      if (doc.heartbeatAt != null) 'heartbeatAt': doc.heartbeatAt,
      if (doc.finishReason != null) 'finishReason': doc.finishReason,
      if (doc.error != null) 'error': doc.error,
    };
    return SessionSnapshot.fromJson(json);
  }
}
