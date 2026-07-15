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

import 'package:schemantic/schemantic.dart';

import '../../exception.dart';
import '../../types.dart';
import 'state_codec.dart';

/// Zone key under which the active [Session] is stored during an agent turn.
const Object _sessionZoneKey = #ai.session;

/// Deep-clones a JSON-serializable value (`Map`, `List`, or primitive).
Object? _deepClone(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _deepClone(entry.value),
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

/// Decodes a stored JSON list into typed values via [fromJson], treating a
/// missing/null entry as an empty list.
List<T> _decodeJsonList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson,
) =>
    (raw as List?)?.map((e) => fromJson(e as Map<String, dynamic>)).toList() ??
    [];

/// Registers [callback] under [key] in [listeners], returning an unsubscribe
/// function that removes exactly that registration.
void Function() _addListener<T>(
  Map<String, List<T>> listeners,
  String key,
  T callback,
) {
  (listeners[key] ??= []).add(callback);
  return () => listeners[key]?.remove(callback);
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
/// Custom state is stored internally as plain JSON (mirroring the JS plain
/// object), and the typed `State` layer is a thin veneer over it: [getCustom]
/// parses the JSON into a `State`, and [updateCustom] serializes the returned
/// `State` back to JSON before storing. When a `stateSchema` is supplied,
/// `State` is a real parsed type (e.g. a schemantic-generated class); without
/// one `State` defaults to `dynamic` and the value is a bare view over the JSON.
///
/// Keeping the internal representation as plain JSON is deliberate: the
/// `customChanged` -> `customPatch` streaming logic diffs raw JSON, so the typed
/// API never changes what is stored on the wire.
class Session<State> {
  /// Builds a session from [initialState], assigning a [sessionId] if absent.
  ///
  /// State is held internally as the raw JSON map (mirroring the JS plain
  /// object) so mutations round-trip cleanly through `SessionState`'s
  /// (de)serialization regardless of the generated setter behavior.
  ///
  /// When a [stateSchema] is provided, [getCustom] / [updateCustom] parse and
  /// serialize the custom state through it; otherwise they operate on raw JSON.
  Session(SessionState initialState, {SchemanticType<State>? stateSchema})
    : sessionId = initialState.sessionId ?? generateUuidV4(),
      _stateSchema = stateSchema {
    // Deep-clone so we never alias (or mutate) the caller's object: the session
    // owns its state, and a handler mutating it must not reach back into the
    // caller's / chat's state. A shallow `Map.from` would leave nested
    // structures (messages, custom, artifacts) shared by reference.
    _json = _deepClone(initialState.toJson()) as Map<String, dynamic>;
    _json['sessionId'] = sessionId;
  }

  final SchemanticType<State>? _stateSchema;

  late final Map<String, dynamic> _json;

  int _version = 0;

  /// Stable identifier that correlates traces across agent turns.
  final String sessionId;

  final Map<String, List<void Function(Object?)>> _listeners = {};

  /// Subscribes to a session [event] (`'customChanged'`, `'artifactAdded'`,
  /// `'artifactUpdated'`). Returns an unsubscribe function.
  void Function() on(String event, void Function(Object? arg) callback) =>
      _addListener(_listeners, event, callback);

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
  ///
  /// Returns copies: the underlying maps are deep-cloned before decoding so
  /// mutating the returned [Message] objects (whose setters write through) can't
  /// alter session state without a version bump or event. This mirrors the JS
  /// implementation, which returns a `structuredClone`. (Note: unlike this and
  /// [getState], [getCustom] and [getArtifacts] intentionally return live data.)
  List<Message> getMessages() =>
      _decodeJsonList(_deepClone(_json['messages']), Message.fromJson);

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

  /// Retrieves the custom state of the session as a typed `State`.
  ///
  /// When a `stateSchema` was supplied, the stored JSON is parsed into a real
  /// `State` instance; otherwise the raw JSON is returned (a bare view cast to
  /// `State`). Returns `null` when no custom state has been set.
  ///
  /// Unlike the untyped JS implementation this returns a *parsed* value, so
  /// (when a schema is present) mutating it in place does not write back to the
  /// session - always persist changes through [updateCustom]. When no schema is
  /// present and the state is a raw `Map`/`List`, the returned value still
  /// aliases the live internal JSON, so treat it as read-only for the same
  /// reason: an in-place mutation bypasses the version bump and the
  /// `customChanged` event, so no `customPatch` is emitted upstack.
  State? getCustom() => castOrParseState<State>(_json['custom'], _stateSchema);

  /// Updates the custom state of the session using a mutator function.
  ///
  /// The current custom state is parsed into a `State`, handed to [fn], and the
  /// returned `State` is serialized back to plain JSON before storing. Storage
  /// stays plain JSON so the `customChanged` -> `customPatch` streaming diff
  /// keeps working unchanged.
  void updateCustom(State? Function(State? custom) fn) {
    final next = fn(castOrParseState<State>(_json['custom'], _stateSchema));
    _json['custom'] = serializeState<State>(next, _stateSchema);
    _version++;
    _emit('customChanged');
  }

  /// Retrieves the list of artifacts generated during the session.
  List<Artifact> getArtifacts() =>
      _decodeJsonList(_json['artifacts'], Artifact.fromJson);

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
///
/// When a `State` type argument is supplied it is applied to the returned
/// session, so `getCustom()` / `updateCustom(...)` are typed. Because Dart
/// generics are reified, the requested `State` must match the one the session
/// was created with (a mismatch throws on the cast). Defaults to
/// `Session<dynamic>?` (the untyped view) when no type argument is given.
Session<State>? getCurrentSession<State>() =>
    Zone.current[_sessionZoneKey] as Session<State>?;

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
    final normalized = normalizeGetSnapshotOptions(
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
      if (snapshotSessionId(snap) == normalized.sessionId) {
        owned.add(snap);
      }
    }
    final leaf = selectLeafSnapshot(
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

    final id = resolveSnapshotId(snapshotId, result);
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
  }) => _addListener(_listeners, snapshotId, callback);
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

/// Resolves the id a snapshot should be stored under.
///
/// The runtime normally supplies a [requestedId], but direct store users may
/// omit it; in that case we reuse the id already on [result] (if any) and
/// otherwise mint a fresh UUID.
String resolveSnapshotId(String? requestedId, SessionSnapshot result) {
  if (requestedId != null && requestedId.isNotEmpty) return requestedId;
  final resultId = result.snapshotId;
  return resultId.isNotEmpty ? resultId : generateUuidV4();
}

/// Returns the sessionId a snapshot belongs to, preferring the top-level
/// `sessionId` and falling back to `state.sessionId`.
String? snapshotSessionId(SessionSnapshot snapshot) =>
    snapshot.sessionId ?? snapshot.state?.sessionId;

class NormalizedGetSnapshot {
  NormalizedGetSnapshot({this.snapshotId, this.sessionId});
  final String? snapshotId;
  final String? sessionId;
}

/// Normalizes and validates `getSnapshot` options.
///
/// Enforces that exactly one of [snapshotId] / [sessionId] is provided and,
/// when a [sessionId] is given, that it is a non-empty string.
NormalizedGetSnapshot normalizeGetSnapshotOptions({
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
  return NormalizedGetSnapshot(
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
SessionSnapshot? selectLeafSnapshot(
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

  // Default: pick the most-recently created leaf.
  //
  // `createdAt` is expected to be a UTC ISO-8601 timestamp (see
  // `SessionSnapshot.createdAt`), but `SessionStore` is a public interface and
  // third-party stores could emit mixed offset formats (e.g. `...+05:00` vs
  // `...Z`), which a naive lexicographic compare would order incorrectly. We
  // therefore parse to a comparable instant when possible and only fall back to
  // lexicographic ordering when a timestamp can't be parsed (so we never throw
  // on malformed input). On an exact tie we keep the later element in iteration
  // order; since callers build [snapshots] by iterating an insertion-ordered
  // store, this resolves ties to the most-recently saved leaf.
  var latest = leaves.first;
  for (final snap in leaves.skip(1)) {
    if (_compareSnapshotRecency(snap, latest) >= 0) latest = snap;
  }
  return latest;
}

/// Compares two snapshots by recency, returning a positive value when [a] is
/// at least as recent as [b].
///
/// Prefers parsing `createdAt` to a UTC instant so mixed ISO-8601 offset
/// formats are ordered correctly; falls back to a lexicographic comparison of
/// the raw strings when either value can't be parsed.
int _compareSnapshotRecency(SessionSnapshot a, SessionSnapshot b) {
  final aTime = DateTime.tryParse(a.createdAt)?.toUtc();
  final bTime = DateTime.tryParse(b.createdAt)?.toUtc();
  if (aTime != null && bTime != null) return aTime.compareTo(bTime);
  return a.createdAt.compareTo(b.createdAt);
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
