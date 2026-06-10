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
/// Ported from the Genkit JS `session.ts`, kept browser-safe (no `dart:io`).
/// The `dart:io`-backed `FileSessionStore` lives in `session_io.dart`.
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
typedef SnapshotMutator =
    SessionSnapshot? Function(SessionSnapshot? current);

/// Interface for persistent session snapshot storage.
abstract interface class SessionStore {
  /// Loads a snapshot either by its [snapshotId] or by [sessionId].
  ///
  /// Exactly one of [snapshotId] / [sessionId] must be provided. A [sessionId]
  /// resolves to the session's latest leaf snapshot and rejects branching
  /// histories with [StatusCodes.FAILED_PRECONDITION].
  Future<SessionSnapshot?> getSnapshot({String? snapshotId, String? sessionId});

  /// Atomically reads the current snapshot (if [snapshotId] is provided),
  /// passes it to [mutator], and persists the result.
  ///
  /// Returns the `snapshotId` that was used, or `null` when the mutator
  /// returned `null`.
  Future<String?> saveSnapshot(String? snapshotId, SnapshotMutator mutator);
}

/// Optional capability: a store may notify listeners when a snapshot's state
/// changes (used by the detach/poll path).
abstract interface class SnapshotChangeNotifier {
  /// Registers [callback] for state changes to [snapshotId]. Returns an
  /// unsubscribe function, or `null` if not supported.
  void Function()? onSnapshotStateChange(
    String snapshotId,
    void Function(SessionSnapshot snapshot) callback,
  );
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
  SessionState getState() => SessionState.fromJson(
    _deepClone(_json) as Map<String, dynamic>,
  );

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
class InMemorySessionStore
    implements SessionStore, SnapshotChangeNotifier {
  final Map<String, SessionSnapshot> _snapshots = {};
  final Map<String, List<void Function(SessionSnapshot)>> _listeners = {};

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
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
      if (snap.state.sessionId == normalized.sessionId) {
        owned.add(snap);
      }
    }
    final leaf = _selectLeafSnapshot(owned, normalized.sessionId!);
    return leaf != null ? _cloneSnapshot(leaf) : null;
  }

  @override
  Future<String?> saveSnapshot(
    String? snapshotId,
    SnapshotMutator mutator,
  ) async {
    final current = snapshotId != null ? _snapshots[snapshotId] : null;

    final result = mutator(current != null ? _cloneSnapshot(current) : null);
    if (result == null) return null;

    // Determine the final ID. For new snapshots compose an `s_{convoId}_{suffix}`
    // id where convoId is derived from the session id (so all snapshots of a
    // session share a grouping key for `getSnapshot(sessionId: ...)`).
    final resultId = result.snapshotId;
    final id = (snapshotId != null && snapshotId.isNotEmpty)
        ? snapshotId
        : (resultId.isNotEmpty
              ? resultId
              : _composeSnapshotId(
                  _deriveConvoId(result),
                  _generateSnapshotSuffix(),
                ));

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
    void Function(SessionSnapshot snapshot) callback,
  ) {
    (_listeners[snapshotId] ??= []).add(callback);
    return () {
      _listeners[snapshotId]?.remove(callback);
    };
  }
}

// ---------------------------------------------------------------------------
// snapshotId helpers (format must match JS for conformance).
// ---------------------------------------------------------------------------

// Only UUID-shaped strings are accepted for the convoId / sessionId component.
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

// The suffix part (after the convoId) must be alphanumeric / hyphens /
// underscores.
final RegExp _safeSuffixPattern = RegExp(r'^[0-9a-zA-Z_-]+$');

/// Prefix that visually distinguishes a `snapshotId` from a bare `sessionId`.
///
/// A `sessionId` is a plain UUID; a `snapshotId` is
/// `s_{sessionId}_{epochMs}_{random}`.
const String _snapshotIdPrefix = 's_';

/// Returns `true` when [id] looks like a snapshotId (carries the `s_` prefix).
bool isSnapshotId(String id) => id.startsWith(_snapshotIdPrefix);

/// Validates that [sessionId] is a UUID, throwing a descriptive error
/// otherwise.
void assertValidSessionId(String sessionId) {
  if (!_uuidPattern.hasMatch(sessionId)) {
    throw GenkitException(
      'Invalid sessionId: expected a UUID, got "$sessionId". '
      'Session ids must be UUIDs (e.g. generateUuidV4()).',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// Generates a short, unique suffix for a snapshot ID.
///
/// Format: `{epochMs}_{random4}` - e.g. `1747000878123_k9m2`.
String _generateSnapshotSuffix() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = _randomBase36(4);
  return '${timestamp}_$random';
}

/// Composes a snapshot ID from a conversation ID and a short suffix.
///
/// Format: `s_{convoId}_{epochMs}_{random}`.
String _composeSnapshotId(String convoId, String suffix) =>
    '$_snapshotIdPrefix${convoId}_$suffix';

/// Mints a new, store-compatible `snapshotId` *ahead of time* (before the
/// snapshot it identifies is actually written).
///
/// The convoId is derived from [sessionId] when provided (so all snapshots of a
/// session group together), falling back to the parent's convoId, then to a
/// fresh UUID.
String reserveSnapshotId({String? sessionId, String? parentId}) {
  String convoId;
  if (sessionId != null) {
    assertValidSessionId(sessionId);
    convoId = sessionId;
  } else if (parentId != null) {
    convoId = _parseSnapshotId(parentId).convoId;
  } else {
    convoId = generateUuidV4();
  }
  return _composeSnapshotId(convoId, _generateSnapshotSuffix());
}

class _ParsedSnapshotId {
  _ParsedSnapshotId(this.convoId, this.suffix);
  final String convoId;
  final String suffix;
}

/// Parses a composite snapshot ID into its conversation ID and suffix.
///
/// Throws if the ID cannot be parsed or the convoId is not a valid UUID.
_ParsedSnapshotId _parseSnapshotId(String snapshotId) {
  if (!snapshotId.startsWith(_snapshotIdPrefix)) {
    throw GenkitException(
      'Invalid snapshotId: expected format "s_{uuid}_{suffix}", got '
      '"$snapshotId". (A bare UUID is a sessionId, not a snapshotId.)',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  final body = snapshotId.substring(_snapshotIdPrefix.length);
  // UUID is always 36 chars (8-4-4-4-12). The separator `_` follows at index 36.
  if (body.length < 38 || body[36] != '_') {
    throw GenkitException(
      'Invalid snapshotId: expected format "s_{uuid}_{suffix}", got '
      '"$snapshotId"',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  final convoId = body.substring(0, 36);
  final suffix = body.substring(37);
  if (!_uuidPattern.hasMatch(convoId)) {
    throw GenkitException(
      'Invalid snapshotId: convoId component is not a valid UUID ("$convoId")',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  if (suffix.isEmpty || !_safeSuffixPattern.hasMatch(suffix)) {
    throw GenkitException(
      'Invalid snapshotId: suffix component is invalid ("$suffix")',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return _ParsedSnapshotId(convoId, suffix);
}

class _NormalizedGetSnapshot {
  _NormalizedGetSnapshot({this.snapshotId, this.sessionId});
  final String? snapshotId;
  final String? sessionId;
}

/// Normalizes and validates `getSnapshot` options.
///
/// Enforces that exactly one of [snapshotId] / [sessionId] is provided and,
/// when a [sessionId] is given, that it is a valid UUID.
_NormalizedGetSnapshot _normalizeGetSnapshotOptions({
  String? snapshotId,
  String? sessionId,
}) {
  final hasSnapshot = snapshotId != null;
  final hasSession = sessionId != null;
  if (hasSnapshot == hasSession) {
    throw GenkitException(
      "getSnapshot requires exactly one of 'snapshotId' or 'sessionId' "
      "(got ${hasSnapshot ? 'snapshotId' : 'neither'}"
      "${hasSession ? ' and sessionId' : ''}).",
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  if (sessionId != null) {
    assertValidSessionId(sessionId);
  }
  return _NormalizedGetSnapshot(snapshotId: snapshotId, sessionId: sessionId);
}

/// Derives the convoId to embed in a *new* snapshot's id.
///
/// Prefers the snapshot's own `state.sessionId`, falling back to the parent's
/// convoId, then to a fresh random UUID.
String _deriveConvoId(SessionSnapshot snapshot) {
  final sessionId = snapshot.state.sessionId;
  if (sessionId != null && sessionId.isNotEmpty) {
    assertValidSessionId(sessionId);
    return sessionId;
  }
  final parentId = snapshot.parentId;
  if (parentId != null) {
    return _parseSnapshotId(parentId).convoId;
  }
  return generateUuidV4();
}

/// Selects the single leaf (latest) snapshot from a set belonging to one
/// session.
///
/// Throws [StatusCodes.FAILED_PRECONDITION] when the history has branched
/// (more than one leaf, e.g. after a regenerate).
SessionSnapshot? _selectLeafSnapshot(
  List<SessionSnapshot> snapshots,
  String sessionId,
) {
  if (snapshots.isEmpty) return null;

  final parentIds = <String>{};
  for (final snap in snapshots) {
    final parentId = snap.parentId;
    if (parentId != null) parentIds.add(parentId);
  }
  final leaves = snapshots
      .where((s) => !parentIds.contains(s.snapshotId))
      .toList();

  if (leaves.length == 1) return leaves.first;

  if (leaves.isEmpty) {
    throw GenkitException(
      "Session '$sessionId' has no leaf snapshot (corrupt or cyclic "
      'history). Resume by snapshotId instead.',
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }

  throw GenkitException(
    "Session '$sessionId' has branching snapshots (${leaves.length} "
    'leaves), so there is no single latest snapshot. This happens when a '
    'conversation is branched (e.g. regenerate). Resume by snapshotId instead.',
    status: StatusCodes.FAILED_PRECONDITION,
  );
}

// ---------------------------------------------------------------------------
// Internal helpers shared with the file store (via session_io.dart re-export).
// ---------------------------------------------------------------------------

/// @nodoc — exposed for the IO file store implementation.
String composeSnapshotIdInternal(String convoId, String suffix) =>
    _composeSnapshotId(convoId, suffix);

/// @nodoc — exposed for the IO file store implementation.
String generateSnapshotSuffixInternal() => _generateSnapshotSuffix();

/// @nodoc — exposed for the IO file store implementation.
({String convoId, String suffix}) parseSnapshotIdInternal(String snapshotId) {
  final parsed = _parseSnapshotId(snapshotId);
  return (convoId: parsed.convoId, suffix: parsed.suffix);
}

/// @nodoc — exposed for the IO file store implementation.
({String? snapshotId, String? sessionId}) normalizeGetSnapshotOptionsInternal({
  String? snapshotId,
  String? sessionId,
}) {
  final normalized = _normalizeGetSnapshotOptions(
    snapshotId: snapshotId,
    sessionId: sessionId,
  );
  return (snapshotId: normalized.snapshotId, sessionId: normalized.sessionId);
}

/// @nodoc — exposed for the IO file store implementation.
String deriveConvoIdInternal(SessionSnapshot snapshot) =>
    _deriveConvoId(snapshot);

/// @nodoc — exposed for the IO file store implementation.
SessionSnapshot? selectLeafSnapshotInternal(
  List<SessionSnapshot> snapshots,
  String sessionId,
) => _selectLeafSnapshot(snapshots, sessionId);

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

/// Returns [length] random base-36 characters (0-9a-z).
String _randomBase36(int length) {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
}
