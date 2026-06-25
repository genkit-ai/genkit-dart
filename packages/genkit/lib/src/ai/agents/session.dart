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

/// Session and snapshot storage for agents.
///
/// Ported from the Genkit JS `session.ts` / `session-stores.ts`, kept
/// browser-safe (no `dart:io`).
library;

import 'dart:async';
import 'dart:math';

import '../../exception.dart';
import '../../types.dart';

/// Zone key under which the active [Session] is stored during an agent turn.
const Object _sessionZoneKey = #ai.session;

/// Deep-clones a JSON-serializable value (`Map`, `List`, or primitive).
Object? _deepClone(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _deepClone(entry.value),
    };
  }
  if (value is List) {
    return <dynamic>[for (final item in value) _deepClone(item)];
  }
  return value;
}

/// Returns a deep copy of a [SessionSnapshot] (via its JSON representation).
SessionSnapshot _cloneSnapshot(SessionSnapshot snapshot) =>
    SessionSnapshot.fromJson(
      _deepClone(snapshot.toJson()) as Map<String, dynamic>,
    );

/// The lifecycle event that triggered a snapshot.
///
/// Mirrors the JS `SnapshotEventSchema` (`'turnEnd'` | `'invocationEnd'`). It
/// is surfaced to the [SnapshotCallback] via [SnapshotContext.event]; unlike
/// older revisions of the wire protocol it is no longer persisted as a field on
/// [SessionSnapshot].
extension type SnapshotEvent(String value) {
  /// A snapshot taken at the end of a single turn.
  static SnapshotEvent get turnEnd => SnapshotEvent('turnEnd');

  /// A snapshot taken at the end of the whole invocation.
  static SnapshotEvent get invocationEnd => SnapshotEvent('invocationEnd');
}

/// The execution context provided to a snapshot callback.
class SnapshotContext {
  SnapshotContext({
    required this.state,
    this.prevState,
    required this.turnIndex,
    required this.event,
  });

  final SessionState state;
  final SessionState? prevState;
  final int turnIndex;

  /// `'turnEnd'` | `'invocationEnd'`.
  final String event;
}

/// Callback triggered before a snapshot is saved. Return `false` to reject
/// persistence.
typedef SnapshotCallback = bool Function(SnapshotContext ctx);

/// A function that receives the current snapshot and returns the updated
/// snapshot to persist.
///
/// - Return the mutated snapshot to save it.
/// - Return `null` to silently skip the update (no-op).
/// - Throw to abort with an error (e.g. precondition failure).
///
/// The returned snapshot's `snapshotId` may be left empty (`''`) to let the
/// store assign a new identifier.
typedef SnapshotMutator = SessionSnapshot? Function(SessionSnapshot? current);

/// Interface for persistent session snapshot storage.
abstract interface class SessionStore {
  /// Loads a snapshot either by its [snapshotId] or by [sessionId].
  ///
  /// Exactly one of [snapshotId] / [sessionId] must be provided. A [sessionId]
  /// resolves to the session's latest leaf snapshot (the most recent snapshot
  /// that no other snapshot points to as its parent). A branched history (more
  /// than one leaf) resolves to the most-recently created leaf by default, or
  /// is rejected with [StatusCodes.FAILED_PRECONDITION] when the store is
  /// configured to reject branching.
  ///
  /// [context] carries the ambient request/action context (e.g. the
  /// authenticated user) so multi-tenant stores can route reads.
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  });

  /// Atomically reads the current snapshot (if [snapshotId] is provided),
  /// passes it to [mutator], and persists the result.
  ///
  /// [context] carries the ambient request/action context (e.g. the
  /// authenticated user) so multi-tenant stores can route writes.
  ///
  /// Returns the `snapshotId` that was used, or `null` when the mutator
  /// returned `null`.
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator, {
    Map<String, dynamic>? context,
  });
}

/// Optional capability: a store may notify listeners when a snapshot's state
/// changes (used by the detach/poll path).
abstract interface class SnapshotChangeNotifier {
  /// Registers [callback] for state changes to [snapshotId]. Returns an
  /// unsubscribe function, or `null` if not supported.
  ///
  /// [context] carries the ambient request/action context so multi-tenant
  /// stores can route the subscription.
  void Function()? onSnapshotStateChange(
    String snapshotId,
    void Function(SessionSnapshot snapshot) callback, {
    Map<String, dynamic>? context,
  });
}

/// State manager for a session turn, tracking messages, custom state, and
/// artifacts.
///
/// Custom state is held as plain JSON (`dynamic`); the typed `State` layer is
/// provided by the agent runtime, which (de)serializes around these values.
class Session {
  /// Builds a session from [initialState], assigning a [sessionId] if absent.
  ///
  /// State is held internally as the raw JSON map (mirroring the JS plain
  /// object) so mutations round-trip cleanly through `SessionState`'s
  /// (de)serialization regardless of the generated setter behavior.
  Session(SessionState initialState)
    : sessionId = initialState.sessionId ?? generateUuidV4() {
    _json = Map<String, dynamic>.from(initialState.toJson());
    _json['sessionId'] = sessionId;
  }

  late final Map<String, dynamic> _json;
  int _version = 0;

  /// Stable identifier that correlates traces across agent turns.
  final String sessionId;

  final Map<String, List<void Function(Object?)>> _listeners = {};

  /// Subscribes to a session [event] (`'customChanged'`, `'artifactAdded'`,
  /// `'artifactUpdated'`). Returns an unsubscribe function.
  void Function() on(String event, void Function(Object? arg) callback) {
    (_listeners[event] ??= []).add(callback);
    return () {
      _listeners[event]?.remove(callback);
    };
  }

  void _emit(String event, [Object? arg]) {
    final callbacks = _listeners[event];
    if (callbacks == null) return;
    for (final cb in [...callbacks]) {
      cb(arg);
    }
  }

  /// Returns a deep copy of the current session state.
  SessionState getState() =>
      SessionState.fromJson(_deepClone(_json) as Map<String, dynamic>);

  /// Retrieves all messages associated with the session.
  List<Message> getMessages() =>
      (_json['messages'] as List?)
          ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];

  /// Appends a list of messages to the session.
  void addMessages(List<Message> messages) {
    final existing = (_json['messages'] as List?) ?? [];
    _json['messages'] = [...existing, ...messages.map((m) => m.toJson())];
    _version++;
  }

  /// Overwrites the session messages.
  void setMessages(List<Message> messages) {
    _json['messages'] = messages.map((m) => m.toJson()).toList();
    _version++;
  }

  /// Retrieves the custom state of the session (plain JSON).
  dynamic getCustom() => _json['custom'];

  /// Updates the custom state of the session using a mutator function.
  void updateCustom(dynamic Function(dynamic custom) fn) {
    _json['custom'] = fn(_json['custom']);
    _version++;
    _emit('customChanged');
  }

  /// Retrieves the list of artifacts generated during the session.
  List<Artifact> getArtifacts() =>
      (_json['artifacts'] as List?)
          ?.map((e) => Artifact.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [];

  /// Adds artifacts to the session, deduplicating items by name.
  ///
  /// Emits `'artifactAdded'` for new artifacts and `'artifactUpdated'` for
  /// replacements.
  void addArtifacts(List<Artifact> artifacts) {
    final existing = (_json['artifacts'] as List?)?.toList() ?? [];
    final added = <Artifact>[];
    final updated = <Artifact>[];

    for (final a in artifacts) {
      final name = a.name;
      if (name != null) {
        final idx = existing.indexWhere(
          (e) => (e as Map<String, dynamic>)['name'] == name,
        );
        if (idx >= 0) {
          existing[idx] = a.toJson();
          updated.add(a);
          continue;
        }
      }
      existing.add(a.toJson());
      added.add(a);
    }

    _json['artifacts'] = existing;
    if (added.isNotEmpty || updated.isNotEmpty) {
      _version++;
    }
    for (final a in added) {
      _emit('artifactAdded', a);
    }
    for (final a in updated) {
      _emit('artifactUpdated', a);
    }
  }

  /// Runs the provided function inside the session's context.
  O run<O>(O Function() fn) =>
      runZoned(fn, zoneValues: {_sessionZoneKey: this});

  /// Gets the current mutation version of the session state.
  int getVersion() => _version;
}

/// Utility to execute a function bound to a [Session] instance context.
O runWithSession<O>(Session session, O Function() fn) => session.run(fn);

/// Returns the [Session] instance active in the current context, or `null`.
Session? getCurrentSession() => Zone.current[_sessionZoneKey] as Session?;

/// Error thrown during session execution.
class SessionError implements Exception {
  SessionError(this.message);
  final String message;

  @override
  String toString() => 'SessionError: $message';
}

/// In-memory implementation of persistent session store.
class InMemorySessionStore implements SessionStore, SnapshotChangeNotifier {
  /// Creates an in-memory store.
  ///
  /// When [rejectBranchingSessions] is `true`, a `sessionId` lookup that
  /// resolves to a branched history (more than one leaf) throws
  /// [StatusCodes.FAILED_PRECONDITION] instead of returning the latest leaf.
  /// Defaults to `false`; opt in (e.g. in dev) to surface accidental branching
  /// early.
  InMemorySessionStore({this.rejectBranchingSessions = false});

  /// Whether a branched `sessionId` lookup is rejected instead of resolving to
  /// the most-recent leaf.
  final bool rejectBranchingSessions;

  final Map<String, SessionSnapshot> _snapshots = {};
  final Map<String, List<void Function(SessionSnapshot)>> _listeners = {};

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) async {
    final normalized = _normalizeGetSnapshotOptions(
      snapshotId: snapshotId,
      sessionId: sessionId,
    );

    if (normalized.snapshotId != null) {
      final snap = _snapshots[normalized.snapshotId];
      if (snap == null) return null;
      return _cloneSnapshot(snap);
    }

    // sessionId lookup: gather every snapshot belonging to this session and
    // resolve the single leaf (latest) snapshot.
    final owned = <SessionSnapshot>[];
    for (final snap in _snapshots.values) {
      if (_snapshotSessionId(snap) == normalized.sessionId) {
        owned.add(snap);
      }
    }
    final leaf = _selectLeafSnapshot(
      owned,
      normalized.sessionId!,
      rejectBranching: rejectBranchingSessions,
    );
    return leaf != null ? _cloneSnapshot(leaf) : null;
  }

  @override
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator, {
    Map<String, dynamic>? context,
  }) async {
    final current = (snapshotId != null && snapshotId.isNotEmpty)
        ? _snapshots[snapshotId]
        : null;

    final result = mutator(current != null ? _cloneSnapshot(current) : null);
    if (result == null) return null;

    // Determine the final ID. The runtime normally supplies a snapshotId, but
    // fall back to a fresh UUID for direct store users who omit it.
    final resultId = result.snapshotId;
    final id = (snapshotId != null && snapshotId.isNotEmpty)
        ? snapshotId
        : (resultId.isNotEmpty ? resultId : generateUuidV4());

    result.snapshotId = id;
    _snapshots[id] = _cloneSnapshot(result);

    final snapshotListeners = _listeners[id];
    if (snapshotListeners != null) {
      for (final listener in [...snapshotListeners]) {
        listener(_cloneSnapshot(result));
      }
    }
    return id;
  }

  @override
  void Function()? onSnapshotStateChange(
    String snapshotId,
    void Function(SessionSnapshot snapshot) callback, {
    Map<String, dynamic>? context,
  }) {
    (_listeners[snapshotId] ??= []).add(callback);
    return () {
      _listeners[snapshotId]?.remove(callback);
    };
  }
}

// ---------------------------------------------------------------------------
// sessionId / snapshotId helpers.
// ---------------------------------------------------------------------------

/// Validates that [sessionId] is a non-empty string, throwing a descriptive
/// error otherwise.
///
/// Session ids can be minted by the client and can be any non-empty string
/// (e.g. a UUID, or an application-specific identifier). We only reject empty /
/// blank values so the id stays usable as a key.
void assertValidSessionId(String sessionId) {
  if (sessionId.trim().isEmpty) {
    throw GenkitException(
      'Invalid sessionId: expected a non-empty string, got "$sessionId".',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// Mints a new `snapshotId` (a plain random UUID).
///
/// The runtime normally supplies the snapshotId to the store at save time, but
/// some flows need the id *ahead of time* - e.g. an agent turn that wants to
/// know the snapshotId at turn *start*, and have the snapshot persisted at turn
/// end reuse that very id, or the detach path which pre-reserves the in-flight
/// snapshot's id.
String reserveSnapshotId() => generateUuidV4();

/// Returns the sessionId a snapshot belongs to, preferring the top-level
/// `sessionId` and falling back to `state.sessionId`.
String? _snapshotSessionId(SessionSnapshot snapshot) =>
    snapshot.sessionId ?? snapshot.state?.sessionId;

class _NormalizedGetSnapshot {
  _NormalizedGetSnapshot({this.snapshotId, this.sessionId});
  final String? snapshotId;
  final String? sessionId;
}

/// Normalizes and validates `getSnapshot` options.
///
/// Enforces that exactly one of [snapshotId] / [sessionId] is provided and,
/// when a [sessionId] is given, that it is a non-empty string.
_NormalizedGetSnapshot _normalizeGetSnapshotOptions({
  String? snapshotId,
  String? sessionId,
}) {
  // Mirror JS truthiness: an empty-string id is treated as absent, so a blank
  // `snapshotId` coming straight off the wire does not satisfy the
  // "exactly one of" requirement.
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
  if (hasSession) {
    assertValidSessionId(sessionId);
  }
  return _NormalizedGetSnapshot(
    snapshotId: hasSnapshot ? snapshotId : null,
    sessionId: hasSession ? sessionId : null,
  );
}

/// Selects the latest leaf snapshot from a set belonging to one session.
///
/// A "leaf" is a snapshot that no other snapshot points to as its `parentId`.
/// A healthy linear session has exactly one leaf - the latest turn.
///
/// - Returns `null` when [snapshots] is empty.
/// - Returns the single leaf when the history is linear.
/// - When the history has branched (more than one leaf, e.g. after a
///   regenerate) the behavior depends on [rejectBranching]:
///   - `false` (default): returns the most-recently created leaf (by
///     `createdAt`).
///   - `true`: throws [StatusCodes.FAILED_PRECONDITION], since there is no
///     unambiguous "latest".
SessionSnapshot? _selectLeafSnapshot(
  List<SessionSnapshot> snapshots,
  String sessionId, {
  bool rejectBranching = false,
}) {
  if (snapshots.isEmpty) return null;

  final parentIds = <String>{};
  for (final snap in snapshots) {
    final parentId = snap.parentId;
    if (parentId != null) parentIds.add(parentId);
  }
  final leaves = snapshots
      .where((s) => !parentIds.contains(s.snapshotId))
      .toList();

  // A single-snapshot session, or any chain, collapses to one leaf.
  if (leaves.length == 1) return leaves.first;

  if (leaves.isEmpty) {
    // Cyclic / corrupt history - every snapshot is someone's parent.
    throw GenkitException(
      "Session '$sessionId' has no leaf snapshot (corrupt or cyclic "
      'history). Resume by snapshotId instead.',
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }

  if (rejectBranching) {
    throw GenkitException(
      "Session '$sessionId' has branching snapshots (${leaves.length} "
      'leaves), so there is no single latest snapshot. This happens when a '
      'conversation is branched (e.g. regenerate). Resume by snapshotId '
      'instead.',
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }

  // Default: pick the most-recently created leaf. `createdAt` is an ISO-8601
  // timestamp, so lexicographic comparison matches chronological order.
  return leaves.reduce(
    (latest, snap) =>
        snap.createdAt.compareTo(latest.createdAt) > 0 ? snap : latest,
  );
}

// ---------------------------------------------------------------------------
// UUID + RNG (browser-safe).
// ---------------------------------------------------------------------------

final Random _rng = Random.secure();

/// Generates a random RFC 4122 version-4 UUID.
String generateUuidV4() {
  final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
  // Set version (4) and variant (10xx) bits.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
