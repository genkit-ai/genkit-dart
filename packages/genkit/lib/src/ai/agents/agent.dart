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

/// Server-side agent runtime.
///
/// Ported from the Genkit JS `agent.ts`. Provides `defineCustomAgent`,
/// `definePromptAgent`, the [SessionRunner] turn loop, the in-process
/// transport, and the three wire actions (agent turn, `getSnapshotData`,
/// `abort`). The browser-safe client core lives in `agent_core.dart`.
library;

import 'dart:async';

import 'package:schemantic/schemantic.dart';

import '../../core/action.dart';
import '../../core/registry.dart';
import '../../exception.dart';
import '../../o11y/instrumentation.dart';
import '../../schema.dart';
import '../../schema_extensions.dart';
import '../../types.dart';
import '../generate.dart';
import '../prompt.dart';
import 'agent_core.dart';
import 'json_patch.dart';
import 'session.dart';

// ---------------------------------------------------------------------------
// Per-turn types.
// ---------------------------------------------------------------------------

/// Result returned by a single turn handler passed to [SessionRunner.run].
///
/// Returning a [finishReason] lets a custom agent explicitly state why the turn
/// ended (e.g. `interrupted`, `length`). When omitted, no per-turn reason is
/// reported.
class TurnResult {
  TurnResult({this.finishReason, this.finishMessage});

  final AgentFinishReason? finishReason;

  /// An optional human-readable message describing why the turn ended.
  ///
  /// Carries, for example, the "Reached max turns of N" text from a generation
  /// that overran its turn limit, so the [SessionRunner] can surface it rather
  /// than dropping it.
  final String? finishMessage;
}

/// Per-turn context handed to the handler passed to [SessionRunner.run].
///
/// The [snapshotId] is *reserved at turn start* (before the handler runs) and
/// is the id the snapshot persisted at turn end will reuse.
class TurnContext {
  TurnContext({
    required this.snapshotId,
    this.parentSnapshotId,
    required this.turnIndex,
  });

  /// The id the snapshot produced by this turn will be saved under.
  final String snapshotId;

  /// The id of the parent snapshot this turn continues from, or `null` on the
  /// first turn of a fresh session.
  final String? parentSnapshotId;

  /// Zero-based index of this turn within the current invocation.
  final int turnIndex;
}

/// Structured error details surfaced on the failure path.
class AgentErrorDetails {
  AgentErrorDetails({
    required this.status,
    required this.message,
    this.details,
  });

  /// The canonical status code name (e.g. `'INVALID_ARGUMENT'`).
  final String status;

  /// A human-readable description of what went wrong.
  final String message;

  /// Optional machine-readable payload carried alongside the error.
  final dynamic details;
}

/// Normalizes a thrown value into the structured error shape used across the
/// agent (in `AgentOutput.error` and [SessionRunner.lastTurnError]).
AgentErrorDetails toErrorDetails(Object? e) {
  if (e is GenkitException) {
    return AgentErrorDetails(
      status: e.status.name,
      message: e.message,
      details: e.details ?? e.underlyingException ?? e.message,
    );
  }
  if (e is AgentError) {
    return AgentErrorDetails(
      status: e.status,
      message: e.message,
      details: e.details ?? e,
    );
  }
  return AgentErrorDetails(
    status: 'INTERNAL',
    message: e?.toString() ?? 'Internal failure',
    details: e,
  );
}

AgentErrorInfo _toErrorInfo(AgentErrorDetails details) => AgentErrorInfo(
  status: details.status,
  message: details.message,
  details: details.details,
);

/// Error thrown for agent init *API misuse* that should surface to the caller
/// as a real, thrown error (mapped to an HTTP status by the server handler)
/// rather than being absorbed into a graceful `finishReason: 'failed'` result.
///
/// Covers calling an agent with an init that does not match its
/// state-management mode (e.g. sending `state` to a server-managed agent, or
/// `snapshotId`/`sessionId` to a client-managed one) and the snapshot/session
/// ownership guard. Other pre-turn failures (missing snapshot, non-resumable
/// snapshot, invalid custom state) remain graceful.
class AgentInitError extends GenkitException {
  AgentInitError(super.message, {required super.status, super.details});
}

// ---------------------------------------------------------------------------
// Snapshot mutators.
// ---------------------------------------------------------------------------

/// Builds an abort-aware [SnapshotMutator]: it skips the write (returns `null`)
/// when the current snapshot has already *settled*, otherwise writes [input].
/// This prevents a "completed"/"failed" write from clobbering a terminal status.
///
/// An `aborting` row is deliberately NOT treated as settled: it sits between the
/// abort flip (which stops the work) and the finalize (which stamps the state
/// on), so the finalize that settles it to `aborted` with state must be allowed
/// through.
SnapshotMutator _abortAwareMutator(SessionSnapshot input) {
  return (current) {
    final status = current?.status?.value;
    if (status == 'completed' || status == 'failed' || status == 'aborted') {
      return null;
    }
    return input;
  };
}

/// Asserts that an operation requiring a persistent store is not being invoked
/// on a store-less (client-managed) agent.
void _requireStore(SessionStore? store, String operation, String agentName) {
  if (store == null) {
    throw GenkitException(
      "$operation requires a persistent store. Provide a 'store' when "
      "defining '$agentName'.",
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }
}

/// Flips a `pending` snapshot to `aborting` via an ordinary `saveSnapshot`, and
/// returns the *resulting* status: `aborting` when the row was pending (or was
/// already aborting, since a second abort is an idempotent verbatim rewrite),
/// the existing terminal status when the row had already settled, or `null` when
/// the snapshot does not exist.
///
/// This is the first of the abort protocol's two writes: it stops the work (the
/// detached worker observes the flip and cancels its turn) but does not stamp
/// state - the worker's own finalize write later settles the row to `aborted`
/// *with* the last-good state (see [SessionRunner.maybeSnapshot]). The flip
/// deliberately leaves `heartbeatAt` where the worker left it: the beat is the
/// worker's liveness signal, so a dead worker's row reads as `expired` at once
/// rather than a heartbeat timeout later.
Future<String?> _abortSnapshotInStore(
  SessionStore store,
  String snapshotId,
  Map<String, dynamic>? context,
) async {
  String? resultStatus;
  await store.saveSnapshot(snapshotId, (current) {
    if (current == null) return null; // not found
    final status = current.status?.value;
    if (status != 'pending') {
      // Settled, or already aborting: re-persist verbatim so the returned
      // status carries the existing value (idempotent).
      resultStatus = status;
      return current;
    }
    current.status = SnapshotStatus.aborting;
    resultStatus = 'aborting';
    return current;
  }, context: context);
  return resultStatus;
}

// ---------------------------------------------------------------------------
// Heartbeat (detached run liveness).
// ---------------------------------------------------------------------------

/// Default interval at which a detached (background) turn refreshes its pending
/// snapshot's heartbeat. Each beat is a write to the session store.
const Duration _defaultHeartbeatInterval = Duration(seconds: 30);

/// Default staleness threshold after which a `pending` snapshot whose heartbeat
/// has not advanced is reported as `expired` on read. Comfortably larger than
/// [_defaultHeartbeatInterval] so a single missed beat does not trip expiry.
const Duration _defaultHeartbeatTimeout = Duration(seconds: 60);

/// Bounds how long an `aborting` invocation keeps heartbeating while its worker
/// drains toward the finalize write. The beats are what keep a live,
/// winding-down worker's row reading as `aborting` instead of `expired` the
/// moment the abort flip lands: the flip stops the work, not the worker, and a
/// drain through a slow tool call can outlast [_defaultHeartbeatTimeout]. A
/// worker that has not finalized within the budget is presumed wedged; its
/// beats stop, the row goes stale and reads as `expired`, and the task stays
/// recoverable instead of winding down forever.
const Duration _windDownHeartbeatBudget = Duration(minutes: 5);

/// Returns `true` when [snapshot] is a detached, in-flight snapshot whose
/// heartbeat is older than [timeout] - i.e. its background worker is presumed
/// dead. Both `pending` and `aborting` are in-flight, still-heartbeating states
/// (a worker keeps beating while it winds down an abort), so a stale beat in
/// either reads as `expired`; this mirrors the shared spec, where a `pending`
/// *or* `aborting` row with a stale beat surfaces as `expired`. A snapshot that
/// has not yet written a first heartbeat is not considered expired (the beat may
/// simply not have fired yet).
bool _isHeartbeatExpired(
  SessionSnapshot snapshot, [
  Duration timeout = _defaultHeartbeatTimeout,
]) {
  final status = snapshot.status?.value;
  if ((status != 'pending' && status != 'aborting') ||
      snapshot.heartbeatAt == null) {
    return false;
  }
  final last = DateTime.tryParse(snapshot.heartbeatAt!);
  if (last == null) return false;
  return DateTime.now().toUtc().difference(last.toUtc()) > timeout;
}

/// Asserts [snapshot] is in a resumable status and carries the state to resume
/// from, throwing a [GenkitException] otherwise (the caller turns that into a
/// graceful `finishReason: 'failed'`).
///
/// `completed`, `failed`, and `aborted` are resumable: each committed a
/// conversation ending at a turn seam, and whether to continue from a run that
/// broke or was stopped is the caller's judgement, not the framework's. A
/// `pending` or `aborting` row is rejected with heartbeat-aware messaging: a
/// live beat means the run is still writing this same id (wait/retry it), a
/// stale beat means the worker died and the resume point is the parent. An
/// `aborted`/`failed` row that somehow carries no state (written by something
/// other than the runtime) is redirected to its parent.
void _assertResumable(SessionSnapshot snapshot) {
  final status = snapshot.status?.value;
  switch (status) {
    case 'pending':
    case 'aborting':
      final id = snapshot.snapshotId;
      if (_isHeartbeatExpired(snapshot)) {
        final parent = snapshot.parentId;
        if (parent != null) {
          throw GenkitException(
            "Snapshot '$id' is still '$status' but its worker stopped "
            'heartbeating and is presumed dead; resume from its parent '
            "snapshot '$parent'.",
            status: StatusCodes.FAILED_PRECONDITION,
          );
        }
        throw GenkitException(
          "Snapshot '$id' is still '$status' but its worker stopped "
          'heartbeating and is presumed dead. It recorded no progress, so '
          'there is nothing to resume.',
          status: StatusCodes.FAILED_PRECONDITION,
        );
      }
      if (status == 'aborting') {
        throw GenkitException(
          "Snapshot '$id' is still being finalized: its invocation was "
          'aborted and has not recorded the state yet; retry this same '
          'snapshot id.',
          status: StatusCodes.FAILED_PRECONDITION,
        );
      }
      throw GenkitException(
        "Snapshot '$id' is still pending: its detached invocation is still "
        'running; wait for it to finalize or abort it before resuming.',
        status: StatusCodes.FAILED_PRECONDITION,
      );
    case 'completed':
    case 'failed':
    case 'aborted':
      // The runtime lands a `failed`/`aborted` row together with its state, so
      // one without state was written by something else; the parent is the
      // resume point.
      if (snapshot.state == null) {
        final parent = snapshot.parentId;
        throw GenkitException(
          "Snapshot '${snapshot.snapshotId}' is '$status' but carries no "
          'state to resume from'
          '${parent != null ? "; resume from its parent snapshot '$parent'." : ' and has no parent.'}',
          status: StatusCodes.FAILED_PRECONDITION,
        );
      }
      return;
    default:
      throw GenkitException(
        "Snapshot '${snapshot.snapshotId}' is not resumable (status: "
        "${status ?? 'unknown'}).",
        status: StatusCodes.INVALID_ARGUMENT,
      );
  }
}

/// Whether [snapshot] is in a resumable *terminal* status carrying state, used
/// by the `sessionId` parent-walk to find the last-good resume point.
bool _isResumableLeaf(SessionSnapshot snapshot) {
  final status = snapshot.status?.value;
  return (status == 'completed' || status == 'failed' || status == 'aborted') &&
      snapshot.state != null;
}

// ---------------------------------------------------------------------------
// JSON helpers.
// ---------------------------------------------------------------------------

Object? _clone(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _clone(entry.value),
    };
  }
  if (value is List) {
    return <dynamic>[for (final item in value) _clone(item)];
  }
  return value;
}

bool _deepEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEqual(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

// ---------------------------------------------------------------------------
// SessionRunner.
// ---------------------------------------------------------------------------

/// Callback invoked when a turn ends.
typedef OnEndTurn =
    void Function(String? snapshotId, AgentFinishReason? finishReason);

/// Callback invoked when a turn is detached.
typedef OnDetach = void Function(String snapshotId);

/// Executor responsible for running turns over input streams and persisting
/// state.
///
/// The `State` type parameter mirrors the wrapped [Session]'s: [getCustom] /
/// [updateCustom] delegate straight through, so a `SessionRunner<State>` exposes
/// the same typed custom-state API. It defaults to `dynamic` for the untyped
/// (raw-JSON) case.
class SessionRunner<State> {
  SessionRunner(
    this.session,
    this.inputCh, {
    SessionSnapshot? lastSnapshot,
    SessionStore? store,
    this.context,
    this.cancel,
    this.onEndTurn,
    this.onDetach,
  }) : _lastSnapshot = lastSnapshot,
       _store = store {
    // Seed the last-good state with the initial session state so a failure on
    // the very first turn still has a valid fallback state.
    lastGoodState = session.getState();
    lastGoodStateVersion = session.getVersion();
  }

  final Session<State> session;
  final Stream<AgentInput> inputCh;

  int turnIndex = 0;
  OnEndTurn? onEndTurn;
  OnDetach? onDetach;
  String? newSnapshotId;

  /// Cooperative cancellation token (the Dart stand-in for `AbortSignal`). When
  /// cancelled, a turn that rejects out of `generate` is reported as `aborted`
  /// (not `failed`) and settled with a single `aborted` snapshot write (the
  /// detached abort flip left the row `aborting`, which this finalize settles).
  final CancellationToken? cancel;

  /// The finish reason of the most recently completed turn.
  AgentFinishReason? lastTurnFinishReason;

  /// Error details of the most recent failed turn.
  AgentErrorDetails? lastTurnError;

  /// The state the most recently successful turn left behind. On a failed turn
  /// this is the state the failed turn started with.
  SessionState? lastGoodState;
  AgentFinishReason? _lastGoodFinishReason;
  int? lastGoodStateVersion;
  SessionSnapshot? _lastSnapshot;
  int _lastSnapshotVersion = 0;
  final SessionStore? _store;

  /// Ambient action context used to scope all persistent-store operations.
  final Map<String, dynamic>? context;

  bool isDetached = false;

  /// True until the first `customPatch` chunk of the current turn has been
  /// emitted. The first patch of every turn is a whole-document replace.
  bool firstCustomPatchInTurn = true;

  /// The latest persisted snapshot (read-only view for callers).
  SessionSnapshot? get lastSnapshot => _lastSnapshot;

  // ── Session delegate methods ────────────────────────────────────────

  /// Returns a deep copy of the current session state.
  SessionState getState() => session.getState();

  /// Retrieves all messages associated with the session.
  List<Message> getMessages() => session.getMessages();

  /// Appends messages to the session.
  void addMessages(List<Message> messages) => session.addMessages(messages);

  /// Overwrites the session messages.
  void setMessages(List<Message> messages) => session.setMessages(messages);

  /// Retrieves the custom state of the session as a typed `State`.
  State? getCustom() => session.getCustom();

  /// Updates the custom state using a mutator function.
  void updateCustom(State? Function(State? custom) fn) =>
      session.updateCustom(fn);

  /// Retrieves the list of artifacts generated during the session.
  List<Artifact> getArtifacts() => session.getArtifacts();

  /// Adds artifacts to the session, deduplicating by name.
  void addArtifacts(List<Artifact> artifacts) =>
      session.addArtifacts(artifacts);

  void _notifyEndTurn(String? snapshotId, AgentFinishReason? finishReason) {
    try {
      onEndTurn?.call(snapshotId, finishReason);
    } catch (_) {
      // Stream was closed, absorb exception.
    }
  }

  /// Executes the flow handler against incoming input messages sequentially.
  Future<void> run(
    Future<TurnResult?> Function(AgentInput input, TurnContext ctx) fn,
  ) async {
    await for (final input in inputCh) {
      final inputMessage = input.message;
      if (inputMessage != null) {
        session.addMessages([inputMessage]);
      }

      firstCustomPatchInTurn = true;

      final parentSnapshotId = _lastSnapshot?.snapshotId;

      if (_store != null && newSnapshotId == null) {
        newSnapshotId = reserveSnapshotId();
      }

      final turnSnapshotId = newSnapshotId;
      newSnapshotId = null;

      final turnContext = TurnContext(
        snapshotId: turnSnapshotId ?? '',
        parentSnapshotId: parentSnapshotId,
        turnIndex: turnIndex,
      );

      try {
        final aborted = await runInNewSpan('runTurn-${turnIndex + 1}', (
          _,
        ) async {
          final turnResult = await fn(input, turnContext);

          // The generate loop now resolves (rather than throws) on a
          // cooperative cancel, so a returned turn can still be an abort. Mirror
          // the catch-path handling: record `aborted`, write the settling
          // `aborted` snapshot, and stop processing further inputs.
          if (cancel?.isCancelled ?? false) {
            lastTurnFinishReason = AgentFinishReason.aborted;
            lastTurnError = null;
            // Persist the turn as `aborted`. This is the second of the abort
            // protocol's two writes: the detached route already flipped the row
            // to `aborting` via `_abortSnapshotInStore` (which stopped the
            // work), and this finalize settles it to `aborted` *with* the state
            // - the abort-aware mutator lets it through because `aborting` is
            // not terminal. The attached route (`AgentTurn.abort()` -> token
            // cancel) has written nothing, so this is its only abort write;
            // without it the trailing `invocationEnd` snapshot would persist a
            // half-finished turn as `completed` and later be picked as a resume
            // point.
            final snapshotId = await maybeSnapshot(
              status: 'aborted',
              snapshotId: turnSnapshotId,
              finishReason: AgentFinishReason.aborted,
            );
            _notifyEndTurn(
              snapshotId ?? _lastSnapshot?.snapshotId,
              AgentFinishReason.aborted,
            );
            return true;
          }

          final finishReason = turnResult?.finishReason;

          // A turn that resolved `aborted` *without* the token being cancelled
          // is not a cooperative cancel: it is an overrun (e.g. the generate
          // loop hit `maxTurns`). Route it to the failure path so the reason
          // (e.g. "Reached max turns of N") surfaces as an error instead of
          // being silently dropped as a success with a null message.
          if (finishReason == AgentFinishReason.aborted) {
            lastTurnFinishReason = AgentFinishReason.failed;
            lastTurnError = toErrorDetails(
              GenkitException(
                turnResult?.finishMessage ?? 'Turn aborted.',
                status: StatusCodes.ABORTED,
              ),
            );
            final snapshotId = await maybeSnapshot(
              status: 'failed',
              error: lastTurnError,
              snapshotId: turnSnapshotId,
              finishReason: AgentFinishReason.failed,
            );
            _notifyEndTurn(snapshotId, AgentFinishReason.failed);
            return true;
          }

          lastTurnFinishReason = finishReason;
          lastTurnError = null;

          final snapshotId = await maybeSnapshot(
            status: 'completed',
            snapshotId: turnSnapshotId,
            finishReason: finishReason,
          );

          lastGoodState = session.getState();
          lastGoodStateVersion = session.getVersion();
          _lastGoodFinishReason = finishReason;

          _notifyEndTurn(snapshotId, finishReason);
          return false;
        }, input: input);
        if (aborted) break;
        turnIndex++;
      } catch (e) {
        // An aborted turn rejects out of `generate` and lands here. Treat it as
        // `aborted` rather than `failed`: the settling `aborted` snapshot was
        // already written on the resolve path above (or, for a wedged run, is
        // owed by the finalize), and the abort-aware mutator would skip a late
        // `failed` write anyway, so we record the finish reason and skip the
        // failed snapshot write entirely instead of reporting a spurious error.
        if (cancel?.isCancelled ?? false) {
          lastTurnFinishReason = AgentFinishReason.aborted;
          lastTurnError = null;
          _notifyEndTurn(_lastSnapshot?.snapshotId, AgentFinishReason.aborted);
          break;
        }

        lastTurnFinishReason = AgentFinishReason.failed;
        lastTurnError = toErrorDetails(e);
        final snapshotId = await maybeSnapshot(
          status: 'failed',
          error: lastTurnError,
          snapshotId: turnSnapshotId,
          finishReason: AgentFinishReason.failed,
        );
        _notifyEndTurn(snapshotId, AgentFinishReason.failed);

        // Graceful failure: stop processing further inputs and let the
        // invocation resolve with `finishReason: 'failed'`.
        break;
      }
    }
  }

  /// Ensures the last-good state is persisted and returns its snapshotId.
  Future<String?> ensureRecoverySnapshot() async {
    if (_store == null || lastGoodState == null) {
      return _lastSnapshot?.snapshotId;
    }

    if (lastGoodStateVersion != null &&
        lastGoodStateVersion == _lastSnapshotVersion) {
      return _lastSnapshot?.snapshotId;
    }

    // First-turn failure: the last-good state is the seed the client holds.
    if (turnIndex == 0) {
      return null;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final snapshotInput = SessionSnapshot(
      snapshotId: '',
      sessionId: session.sessionId,
      createdAt: now,
      updatedAt: now,
      state: lastGoodState!,
      parentId: _lastSnapshot?.snapshotId,
      status: SnapshotStatus.completed,
      finishReason: _lastGoodFinishReason,
    );

    final assignedId = await _store.saveSnapshot(
      null,
      _abortAwareMutator(snapshotInput),
      context: context,
    );
    if (assignedId == null) {
      return _lastSnapshot?.snapshotId;
    }

    snapshotInput.snapshotId = assignedId;
    _lastSnapshot = snapshotInput;
    if (lastGoodStateVersion != null) {
      _lastSnapshotVersion = lastGoodStateVersion!;
    }
    return assignedId;
  }

  /// Evaluates whether to save a snapshot to the persistent store.
  Future<String?> maybeSnapshot({
    String? status,
    AgentErrorDetails? error,
    String? snapshotId,
    AgentFinishReason? finishReason,
  }) async {
    if (_store == null ||
        (isDetached && snapshotId != _lastSnapshot?.snapshotId)) {
      return _lastSnapshot?.snapshotId;
    }

    final currentVersion = session.getVersion();
    if (currentVersion == _lastSnapshotVersion && status == null) {
      return _lastSnapshot?.snapshotId;
    }

    final currentState = session.getState();
    final effectiveId = snapshotId ?? newSnapshotId;

    // When an id is reused (e.g. the detached `pending` snapshot is upgraded to
    // `completed` under the same id), `_lastSnapshot` already points at that id.
    // Inherit its parent instead of pointing the snapshot at itself, which would
    // create a self-referential `parentId` and later trip the cycle guard in
    // `loadChat`/`getSnapshot`.
    final reusingId =
        effectiveId != null && effectiveId == _lastSnapshot?.snapshotId;
    final parentId = reusingId
        ? _lastSnapshot?.parentId
        : _lastSnapshot?.snapshotId;

    // The `invocationEnd` write (the only caller that omits a status) persists
    // as `completed` so it stays a valid resume target.
    final now = DateTime.now().toUtc().toIso8601String();
    final snapshotInput = SessionSnapshot(
      snapshotId: effectiveId ?? '',
      sessionId: session.sessionId,
      createdAt: _lastSnapshot?.createdAt ?? now,
      updatedAt: now,

      // Stamp an initial heartbeat on a `pending` (detached, in-flight)
      // snapshot. A background heartbeat loop refreshes it; if it goes stale
      // the snapshot is reported as `expired` on read (worker presumed dead).
      heartbeatAt: status == 'pending' ? now : null,
      state: currentState,
      parentId: parentId,
      status: SnapshotStatus(status ?? 'completed'),
      finishReason: finishReason,
      error: error != null ? _toErrorInfo(error) : null,
    );

    final assignedId = await _store.saveSnapshot(
      effectiveId,
      _abortAwareMutator(snapshotInput),
      context: context,
    );
    if (assignedId == null) {
      // Snapshot was aborted concurrently; preserve the existing ID.
      return effectiveId;
    }

    snapshotInput.snapshotId = assignedId;
    _lastSnapshot = snapshotInput;
    _lastSnapshotVersion = currentVersion;

    return assignedId;
  }
}

// ---------------------------------------------------------------------------
// ClientTransform + AgentFn.
// ---------------------------------------------------------------------------

/// Projects an agent's server-side data onto the view a client should see.
///
/// - [state] reshapes/redacts session state at rest (applied to
///   `AgentOutput.state`, snapshots, and the streamed `customPatch` baseline).
/// - [chunk] reshapes/redacts each stream chunk in flight; return `null` to
///   drop the chunk entirely.
class ClientTransform {
  ClientTransform({this.state, this.chunk});

  final SessionState Function(SessionState state)? state;
  final AgentStreamChunk? Function(AgentStreamChunk chunk)? chunk;
}

/// Options handed to the handler of a custom agent.
class AgentFnOptions {
  AgentFnOptions({required this.sendChunk, this.cancel, this.context});

  /// Emits a stream chunk to the client.
  final void Function(AgentStreamChunk chunk) sendChunk;

  /// Cooperative cancellation token (the Dart stand-in for `AbortSignal`).
  final CancellationToken? cancel;

  /// The ambient request context.
  final Map<String, dynamic>? context;
}

/// Function handler definition for custom agent actions.
///
/// The `State` type parameter surfaces the agent's typed custom state on the
/// [SessionRunner] passed to the handler, so `sess.getCustom()` /
/// `sess.updateCustom(...)` are typed. It defaults to `dynamic` (raw JSON) when
/// the agent has no `stateSchema`.
typedef AgentFn<State> =
    Future<AgentResult> Function(
      SessionRunner<State> sess,
      AgentFnOptions options,
    );

/// Validation callback for the `custom` field of a session state.
typedef ValidateCustomState = void Function(dynamic custom);

// ---------------------------------------------------------------------------
// Internal config.
// ---------------------------------------------------------------------------

class _AgentConfig<State> {
  _AgentConfig({
    required this.name,
    this.description,
    this.stateSchema,
    this.store,
    this.clientTransform,
  });

  final String name;
  final String? description;
  final SchemanticType<State>? stateSchema;
  final SessionStore? store;
  final ClientTransform? clientTransform;
}

// ---------------------------------------------------------------------------
// resolveSession.
// ---------------------------------------------------------------------------

/// Asserts that the init strategy matches the agent's state-management mode,
/// throwing an [AgentInitError] on a mismatch.
///
/// Server-managed agents (with a store) resume via a `snapshotId` / `sessionId`;
/// client-managed agents (no store) supply the full `state` blob. This is API
/// misuse, so it propagates as a thrown error rather than a graceful failure.
void _assertInitMatchesStateManagement(_AgentConfig config, AgentInit? init) {
  if ((init?.snapshotId != null || init?.sessionId != null) &&
      config.store == null) {
    final which = init!.snapshotId != null ? 'snapshotId' : 'sessionId';
    throw AgentInitError(
      "Cannot use '$which' with agent '${config.name}': this agent has no "
      "store configured (client-managed state). Send 'state' instead.",
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }
  if (init?.state != null && config.store != null) {
    throw AgentInitError(
      "Cannot send 'state' to agent '${config.name}': this agent uses a "
      "server-managed store. Send 'snapshotId' or 'sessionId' instead.",
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }
}

/// Resolves the [Session] (and originating snapshot, if any) for an agent turn
/// from its [AgentInit].
///
/// Server-managed agents (with a store) resume via a `snapshotId` (an exact
/// snapshot) or a `sessionId` (the session's latest snapshot); client-managed
/// agents (no store) supply the full `state` blob. Throws a [GenkitException]
/// on a missing snapshot, non-resumable snapshot, or invalid custom state - the
/// caller translates that into a graceful `finishReason: 'failed'` result. The
/// state-management mismatch checks are performed up front by
/// [_assertInitMatchesStateManagement] and throw [AgentInitError]. The
/// snapshot/session ownership guard also throws [AgentInitError].
Future<({Session<State> session, SessionSnapshot? snapshot})>
_resolveSession<State>(
  _AgentConfig<State> config,
  SessionStore store,
  AgentInit? init,
  ValidateCustomState validateCustomState,
  Map<String, dynamic>? context,
) async {
  final stateSchema = config.stateSchema;
  if (init?.snapshotId != null) {
    final snapshot = await store.getSnapshot(
      snapshotId: init!.snapshotId,
      context: context,
    );
    if (snapshot == null) {
      throw GenkitException(
        'Snapshot ${init.snapshotId} not found',
        status: StatusCodes.NOT_FOUND,
      );
    }
    // When both `snapshotId` and `sessionId` are supplied, `snapshotId` selects
    // the exact snapshot to resume and `sessionId` acts as an ownership guard:
    // the snapshot must belong to that session. A mismatch is API misuse, so it
    // propagates as a thrown [AgentInitError]. Prefer the snapshot's top-level
    // `sessionId`; fall back to the id carried in its state for rows written
    // before snapshot-level ids existed.
    final snapshotSessionId = snapshot.sessionId ?? snapshot.state?.sessionId;
    if (init.sessionId != null && snapshotSessionId != init.sessionId) {
      throw AgentInitError(
        'Snapshot ${init.snapshotId} does not belong to session '
        '${init.sessionId} (it belongs to '
        '${snapshotSessionId ?? 'an unknown session'}).',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    // Validate the snapshot is in a resumable status and load its state. A
    // `failed` or `aborted` snapshot resumes: the turn that wrote it committed
    // a conversation ending at a turn seam, and whether to continue from a run
    // that broke or one that was stopped is the caller's judgement.
    _assertResumable(snapshot);

    validateCustomState(snapshot.state?.custom);
    return (
      snapshot: snapshot,
      session: Session(snapshot.state!, stateSchema: stateSchema),
    );
  }

  if (init?.sessionId != null) {
    // Resume the session's latest snapshot. The store returns the latest leaf
    // regardless of status, but only `completed` snapshots are resumable - so
    // if the leaf is a non-resumable turn, walk back over its parent chain to
    // the last-good (`completed`) snapshot. When the session has no resumable
    // snapshot, seed a fresh session bound to the requested sessionId.
    var snapshot = await store.getSnapshot(
      sessionId: init!.sessionId,
      context: context,
    );
    final visited = <String>{};
    while (snapshot != null && !_isResumableLeaf(snapshot)) {
      if (visited.contains(snapshot.snapshotId)) {
        throw GenkitException(
          "Session '${init.sessionId}' has a cyclic snapshot parent chain "
          "(snapshot '${snapshot.snapshotId}' was visited twice). Resume by "
          'snapshotId instead.',
          status: StatusCodes.FAILED_PRECONDITION,
        );
      }
      visited.add(snapshot.snapshotId);
      final parentId = snapshot.parentId;
      snapshot = parentId != null
          ? await store.getSnapshot(snapshotId: parentId, context: context)
          : null;
    }
    if (snapshot != null) {
      validateCustomState(snapshot.state?.custom);
      return (
        snapshot: snapshot,
        session: Session(snapshot.state!, stateSchema: stateSchema),
      );
    }
    return (
      snapshot: null,
      session: Session(
        SessionState(
          custom: <String, dynamic>{},
          artifacts: [],
          messages: [],
          sessionId: init.sessionId,
        ),
        stateSchema: stateSchema,
      ),
    );
  }

  if (init?.state != null && config.store == null) {
    validateCustomState(init!.state!.custom);
    return (
      snapshot: null,
      session: Session(init.state!, stateSchema: stateSchema),
    );
  }

  return (
    snapshot: null,
    session: Session(
      SessionState(custom: <String, dynamic>{}, artifacts: [], messages: []),
      stateSchema: stateSchema,
    ),
  );
}

// ---------------------------------------------------------------------------
// pipeInputWithDetach.
// ---------------------------------------------------------------------------

void _pipeInputWithDetach(
  Stream<AgentInput> inputStream,
  StreamController<AgentInput> target,
  SessionRunner Function() getRunner,
  bool storeEnabled,
  void Function(Object reason) rejectDetach,
) {
  () async {
    try {
      await for (final input in inputStream) {
        if (input.detach == true) {
          if (!storeEnabled) {
            rejectDetach(
              GenkitException(
                'Detach is only supported when a session store is provided.',
                status: StatusCodes.FAILED_PRECONDITION,
              ),
            );
          } else {
            final runner = getRunner();
            final turnSnapshotId = runner.newSnapshotId ?? reserveSnapshotId();
            runner.newSnapshotId = turnSnapshotId;

            await runner.maybeSnapshot(
              status: 'pending',
              snapshotId: turnSnapshotId,
            );
            runner.isDetached = true;

            runner.onDetach?.call(turnSnapshotId);
          }
          final hasPayload =
              input.message != null ||
              (input.resume?.restart?.isNotEmpty ?? false) ||
              (input.resume?.respond?.isNotEmpty ?? false);

          if (hasPayload) {
            target.add(input);
          }
        } else {
          target.add(input);
        }
      }
      await target.close();
    } catch (e) {
      target.addError(e);
      await target.close();
    }
  }();
}

// ---------------------------------------------------------------------------
// In-process transport.
// ---------------------------------------------------------------------------

final class _InProcessTransport extends AgentTransport {
  _InProcessTransport({
    required AgentStateManagement stateManagement,
    required this.primaryAction,
    required this.getSnapshotDataAction,
    required this.abortAgentAction,
  }) {
    this.stateManagement = stateManagement;
  }

  final Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>
  primaryAction;
  final Action<GetSnapshotDataInput, SessionSnapshot?, void, void>
  getSnapshotDataAction;
  final Action<AgentAbortRequest, AgentAbortResponse, void, void>
  abortAgentAction;

  BidiActionStream<AgentStreamChunk, AgentOutput, AgentInput> _startBidi(
    AgentInput input,
    AgentInit init, {
    Map<String, dynamic>? context,
    CancellationToken? cancel,
  }) {
    final bidi = primaryAction.streamBidi(
      init: init,
      context: context,
      cancel: cancel,
    );
    bidi.send(input);
    bidi.close();
    return bidi;
  }

  // [cancel] is threaded into the agent action's `generate` call (via
  // `streamBidi`), so aborting an attached in-process turn cooperatively stops
  // the in-flight model call. The detached path additionally observes the
  // persisted `aborted` status via `SnapshotChangeNotifier`.
  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    CancellationToken? cancel,
    Map<String, dynamic>? context,
  }) {
    final bidi = _startBidi(input, init, context: context, cancel: cancel);
    return (stream: bidi, output: bidi.onResult);
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    CancellationToken? cancel,
    Map<String, dynamic>? context,
  }) {
    return _startBidi(input, init, context: context, cancel: cancel).onResult;
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) => getSnapshotDataAction(
    GetSnapshotDataInput(snapshotId: snapshotId, sessionId: sessionId),
    context: context,
  );

  // Detached/persist-only: flips the persisted snapshot to `aborting` and
  // returns its resulting status. A detached worker watching the snapshot
  // cancels its own turn in response and its finalize settles the row to
  // `aborted`; an attached in-process turn's model call is not interrupted
  // (see [runTurn]).
  @override
  Future<SnapshotStatus?> abort(
    String snapshotId, {
    Map<String, dynamic>? context,
  }) async => (await abortAgentAction(
    AgentAbortRequest(snapshotId: snapshotId),
    context: context,
  )).status;
}

// ---------------------------------------------------------------------------
// Agent.
// ---------------------------------------------------------------------------

/// A configured, registered agent.
///
/// Exposes the ergonomic, transport-agnostic [AgentApi] surface (`chat`,
/// `loadChat`, `getSnapshot`, `abort`) - the same surface returned by
/// `remoteAgent` on the client - plus the lower-level [action] for serving
/// over HTTP and the snapshot/abort actions.
class Agent<State> {
  Agent._({
    required this.action,
    required this.getSnapshotDataAction,
    required this.abortAgentAction,
    required AgentApi<State> api,
  }) : _api = api;

  /// The primary bidi agent turn action.
  final Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit> action;

  /// The `getSnapshotData` action.
  final Action<GetSnapshotDataInput, SessionSnapshot?, void, void>
  getSnapshotDataAction;

  /// The `abort` action.
  final Action<AgentAbortRequest, AgentAbortResponse, void, void>
  abortAgentAction;

  final AgentApi<State> _api;

  /// Starts a new chat, optionally attaching via [snapshotId] / [sessionId] /
  /// [state] (provide at most one).
  AgentChat<State> chat({
    String? snapshotId,
    String? sessionId,
    SessionState? state,
  }) => _api.chat(snapshotId: snapshotId, sessionId: sessionId, state: state);

  /// Loads a server snapshot and returns a chat with history restored.
  Future<AgentChat<State>> loadChat({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) => _api.loadChat(
    snapshotId: snapshotId,
    sessionId: sessionId,
    context: context,
  );

  /// Reads a snapshot without starting a chat. Requires a server store.
  ///
  /// Returns a typed [AgentSnapshot] wrapper (with the same `stateSchema`
  /// applied to `snapshot.state`), or `null` when no snapshot is found.
  Future<AgentSnapshot<State>?> getSnapshot({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) => _api.getSnapshot(
    snapshotId: snapshotId,
    sessionId: sessionId,
    context: context,
  );

  /// Reads a snapshot (applying the client transform). Requires a server store.
  Future<SessionSnapshot?> getSnapshotData({
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  }) => getSnapshotDataAction(
    GetSnapshotDataInput(snapshotId: snapshotId, sessionId: sessionId),
    context: context,
  );

  /// Aborts a running snapshot. Requires a server store. Returns the status
  /// after the attempt (a pending row reads back as `aborting`; an
  /// already-settled row returns its terminal status), or `null` when the
  /// snapshot does not exist.
  Future<SnapshotStatus?> abort(
    String snapshotId, {
    Map<String, dynamic>? context,
  }) async => (await abortAgentAction(
    AgentAbortRequest(snapshotId: snapshotId),
    context: context,
  )).status;
}

// ---------------------------------------------------------------------------
// defineCustomAgent.
// ---------------------------------------------------------------------------

/// Registers a multi-turn custom agent action capable of maintaining
/// persistent state.
///
/// When a [stateSchema] is provided, the returned [Agent] is typed as
/// `Agent<State>`, and `chat().state` / `res.state` return parsed `State`
/// instances instead of raw JSON maps. Without one, `State` defaults to
/// `dynamic` (a bare view over the JSON).
Agent<State> defineCustomAgent<State>(
  Registry registry, {
  required String name,
  String? description,
  SchemanticType<State>? stateSchema,
  SessionStore? store,
  ClientTransform? clientTransform,
  required AgentFn<State> fn,
}) {
  final config = _AgentConfig<State>(
    name: name,
    description: description,
    stateSchema: stateSchema,
    store: store,
    clientTransform: clientTransform,
  );

  SessionState? toClientState(SessionState state) {
    if (config.clientTransform?.state != null) {
      return config.clientTransform!.state!(state);
    }
    return state;
  }

  final stateJsonSchema = config.stateSchema != null
      ? toJsonSchema(type: config.stateSchema)
      : null;

  void validateCustomState(dynamic custom) {
    if (config.stateSchema != null && custom != null) {
      config.stateSchema!.parse(custom);
    }
  }

  final primaryAction = Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>(
    name: config.name,
    description: config.description,
    actionType: .agent,
    inputSchema: AgentInput.$schema,
    outputSchema: AgentOutput.$schema,
    streamSchema: AgentStreamChunk.$schema,
    initSchema: AgentInit.$schema,
    metadata: {
      'agent': AgentMetadata(
        stateManagement: config.store != null
            ? AgentStateManagement.server
            : AgentStateManagement.client,
        abortable: config.store is SnapshotChangeNotifier,
        stateSchema: stateJsonSchema,
      ).toJson(),
    },
    fn: (input, ctx) async {
      final init = ctx.init;
      final resolvedStore = config.store ?? InMemorySessionStore();

      // API-misuse checks (init does not match the agent's state-management
      // mode) throw out of the handler so the server maps them to a proper
      // HTTP status, rather than being absorbed into a graceful
      // `finishReason: 'failed'` result below.
      _assertInitMatchesStateManagement(config, init);

      Session<State> session;
      SessionSnapshot? snapshot;
      try {
        final resolved = await _resolveSession<State>(
          config,
          resolvedStore,
          init,
          validateCustomState,
          ctx.context,
        );
        session = resolved.session;
        snapshot = resolved.snapshot;
      } catch (e) {
        // An AgentInitError signals API misuse (e.g. the snapshot/session
        // ownership guard) that must surface as a thrown error; re-throw it
        // so the server handler maps it to a proper HTTP status. Other
        // pre-turn failures resolve gracefully with `finishReason: 'failed'`
        // (preserving the original error.status).
        if (e is AgentInitError) rethrow;
        return AgentOutput(
          finishReason: AgentFinishReason.failed,
          error: _toErrorInfo(toErrorDetails(e)),
          state: (config.store == null && init?.state != null)
              ? init!.state
              : null,
        );
      }

      setCustomMetadataAttributes({'agent:sessionId': session.sessionId});

      String? detachedSnapshotId;
      final detachCompleter = Completer<void>();
      // Own a controller for this turn (cancelled on detach-abort or when
      // the persisted snapshot flips to `aborted`) and link the ambient
      // transport token to it, so an attached `runTurn(cancel:)` also
      // cooperatively stops this turn's `generate`.
      final cancelController = CancellationController();
      // Capture the disposer so a reused, long-lived `ctx.cancel` token
      // doesn't accumulate one stranded listener (pinning this turn's
      // controller and closure) per turn. Disposed when the flow settles.
      // `link` forwards the cancellation reason so a caller-supplied
      // `controller.cancel('...')` survives the hop into this turn's token.
      final unlinkCancel = ctx.cancel?.link(cancelController);
      final cancelToken = cancelController.token;
      void Function()? unsubscribe;
      // Background heartbeat timer for the detached snapshot. Started in
      // `onDetach`, cleared when the flow settles (or when the wind-down
      // budget after an abort elapses).
      Timer? heartbeatTimer;
      // Bounds how long the heartbeat keeps beating after an abort flip
      // while the worker drains toward its finalize; released early when the
      // heartbeat stops for any other reason so a normal wind-down does not
      // pin it for the whole budget.
      Timer? windDownBudget;
      void stopHeartbeat() {
        heartbeatTimer?.cancel();
        heartbeatTimer = null;
        windDownBudget?.cancel();
        windDownBudget = null;
      }

      late SessionRunner<State> runner;

      void emitChunk(AgentStreamChunk chunk) {
        final transform = config.clientTransform?.chunk;
        if (transform != null) {
          final transformed = transform(chunk);
          if (transformed == null) return;
          ctx.sendChunk(transformed);
          return;
        }
        ctx.sendChunk(chunk);
      }

      final runnerInputController = StreamController<AgentInput>();
      _pipeInputWithDetach(
        ctx.inputStream!,
        runnerInputController,
        () => runner,
        config.store != null,
        (reason) {
          if (!detachCompleter.isCompleted) {
            detachCompleter.completeError(reason);
          }
        },
      );

      runner = SessionRunner<State>(
        session,
        runnerInputController.stream,
        store: resolvedStore,
        context: ctx.context,
        lastSnapshot: snapshot,
        cancel: cancelToken,
        onDetach: (snapshotId) {
          detachedSnapshotId = snapshotId;
          if (!detachCompleter.isCompleted) detachCompleter.complete();

          // Refresh the detached snapshot's heartbeat periodically. The
          // mutator beats the two rows a live worker is still owed a write
          // for - a `pending` one while the turn runs, and an `aborting`
          // one while the stopped turn drains toward its finalize - and
          // no-ops on any other (settled) row, so it never resurrects a
          // terminal snapshot or clobbers a concurrent finalize. If a read
          // sees this heartbeat go stale, the snapshot is reported as
          // `expired` (worker presumed dead).
          heartbeatTimer = Timer.periodic(_defaultHeartbeatInterval, (_) {
            unawaited(
              resolvedStore
                  .saveSnapshot(snapshotId, (current) {
                    final status = current?.status?.value;
                    if (status != 'pending' && status != 'aborting') {
                      return null;
                    }
                    current!.heartbeatAt = DateTime.now()
                        .toUtc()
                        .toIso8601String();
                    return current;
                  }, context: ctx.context)
                  .catchError((_) {
                    // Best-effort heartbeat; ignore transient store errors.
                    return null;
                  }),
            );
          });

          if (resolvedStore is SnapshotChangeNotifier) {
            // Capture the unsubscribe in a local first: if
            // `onSnapshotStateChange` fires the callback synchronously on
            // registration, the outer `unsubscribe` would still be null.
            void Function()? localUnsubscribe;
            localUnsubscribe = (resolvedStore as SnapshotChangeNotifier)
                .onSnapshotStateChange(snapshotId, (snap) {
                  // The runtime's own abort flips the row to `aborting`; a
                  // foreign writer that lands `aborted` directly still means
                  // stop.
                  final status = snap.status?.value;
                  if (status != 'aborting' && status != 'aborted') return;
                  // The flip stops the work, not the worker: the run is
                  // winding down toward its finalize write now, and the
                  // heartbeat keeps running so readers see a live `aborting`
                  // row instead of presuming the worker dead the moment the
                  // flip lands. The flow's `finally` stops the beats right
                  // before the finalize; the budget bounds a worker whose fn
                  // never observes the cancellation, so a truly wedged run
                  // still goes stale and reads as `expired`.
                  windDownBudget = Timer(
                    _windDownHeartbeatBudget,
                    stopHeartbeat,
                  );
                  cancelController.cancel();
                  localUnsubscribe?.call();
                }, context: ctx.context);
            unsubscribe = localUnsubscribe;
          }
        },

        onEndTurn: (snapshotId, finishReason) {
          if (!runner.isDetached) {
            emitChunk(
              AgentStreamChunk(
                turnEnd: TurnEnd(
                  snapshotId: config.store != null ? snapshotId : null,
                  finishReason: finishReason,
                ),
              ),
            );
          }
        },
      );

      void sendArtifactChunk(Object? a) {
        if (!runner.isDetached) {
          emitChunk(AgentStreamChunk(artifact: a as Artifact));
        }
      }

      final offArtifactAdded = session.on('artifactAdded', sendArtifactChunk);
      final offArtifactUpdated = session.on(
        'artifactUpdated',
        sendArtifactChunk,
      );

      dynamic lastSentCustom;
      void sendCustomPatch(Object? _) {
        if (runner.isDetached) return;
        final transformed = toClientState(session.getState())?.custom;
        JsonPatch patch;
        if (runner.firstCustomPatchInTurn) {
          patch = [
            {'op': 'replace', 'path': '', 'value': _clone(transformed)},
          ];
          runner.firstCustomPatchInTurn = false;
        } else {
          patch = diff(lastSentCustom, transformed);
        }
        lastSentCustom = _clone(transformed);
        if (patch.isNotEmpty) {
          emitChunk(
            AgentStreamChunk(
              customPatch: patch.map(JsonPatchOperation.fromJson).toList(),
            ),
          );
        }
      }

      final offCustomChanged = session.on('customChanged', sendCustomPatch);

      void sendChunk(AgentStreamChunk chunk) {
        if (!runner.isDetached) emitChunk(chunk);
      }

      Future<({AgentResult result, String? finalSnapshotId})> flow() async {
        try {
          final result = await runWithSession(
            session,
            () => fn(
              runner,
              AgentFnOptions(
                sendChunk: sendChunk,
                cancel: cancelToken,
                context: ctx.context,
              ),
            ),
          );
          final finalSnapshotId = await runner.maybeSnapshot();
          return (result: result, finalSnapshotId: finalSnapshotId);
        } finally {
          // The turn has settled (the snapshot reached a terminal status),
          // so stop refreshing its heartbeat.
          stopHeartbeat();
          unlinkCancel?.call();
          unsubscribe?.call();
          offArtifactAdded();
          offArtifactUpdated();
          offCustomChanged();
        }
      }

      final flowFuture = flow();

      // Race the background flow execution against the detach signal.
      final outcome = Completer<_Outcome>();
      flowFuture
          .then((v) {
            if (!outcome.isCompleted) outcome.complete(_Outcome.flow(v));
          })
          .catchError((Object e, StackTrace s) {
            if (!outcome.isCompleted) outcome.completeError(e, s);
          });
      detachCompleter.future
          .then((_) {
            if (!outcome.isCompleted) outcome.complete(_Outcome.detached());
          })
          .catchError((Object e, StackTrace s) {
            if (!outcome.isCompleted) outcome.completeError(e, s);
          });

      final result = await outcome.future;

      if (result.isDetached) {
        // Swallow any later flow error now that we've detached.
        unawaited(
          flowFuture.catchError(
            (_) => (result: AgentResult(), finalSnapshotId: null),
          ),
        );
        return AgentOutput(
          sessionId: session.sessionId,
          snapshotId: detachedSnapshotId,
          finishReason: AgentFinishReason.detached,
          state: config.store == null
              ? toClientState(session.getState())
              : null,
        );
      }

      final flowValue = result.flowValue!;
      final agentResult = flowValue.result;
      final finalSnapshotId = flowValue.finalSnapshotId;

      // A turn failed: resolve gracefully with the last-good state.
      if (runner.lastTurnFinishReason == AgentFinishReason.failed &&
          runner.lastTurnError != null) {
        final lastGood = runner.lastGoodState ?? session.getState();
        final lastGoodMessages = lastGood.messages;
        return AgentOutput(
          sessionId: session.sessionId,
          finishReason: AgentFinishReason.failed,
          error: _toErrorInfo(runner.lastTurnError!),
          artifacts: agentResult.artifacts?.isNotEmpty == true
              ? agentResult.artifacts
              : null,
          message: lastGoodMessages?.isNotEmpty == true
              ? lastGoodMessages!.last
              : null,
          snapshotId: config.store != null
              ? await runner.ensureRecoverySnapshot()
              : null,
          state: config.store == null ? toClientState(lastGood) : null,
        );
      }

      final finishReason =
          agentResult.finishReason ?? runner.lastTurnFinishReason;

      return AgentOutput(
        sessionId: session.sessionId,
        artifacts: agentResult.artifacts?.isNotEmpty == true
            ? agentResult.artifacts
            : null,
        message: agentResult.message,
        finishReason: finishReason,
        snapshotId: config.store != null ? finalSnapshotId : null,
        state: config.store == null ? toClientState(session.getState()) : null,
      );
    },
  );

  registry.register(primaryAction);

  SessionSnapshot toClientSnapshot(SessionSnapshot snapshot) {
    final transform = config.clientTransform?.state;
    final state = snapshot.state;
    if (transform == null || state == null) return snapshot;
    final json = Map<String, dynamic>.from(snapshot.toJson());
    json['state'] = transform(state).toJson();
    return SessionSnapshot.fromJson(json);
  }

  Future<SessionSnapshot?> resolveSnapshot(
    String? snapshotId,
    String? sessionId,
    Map<String, dynamic>? context,
  ) async {
    _requireStore(config.store, 'getSnapshotData', config.name);
    final snapshot = await config.store!.getSnapshot(
      snapshotId: snapshotId,
      sessionId: sessionId,
      context: context,
    );
    if (snapshot == null) return null;
    // Compute `expired` on read: a `pending` snapshot whose heartbeat has gone
    // stale is presumed orphaned (its background worker died), so surface it as
    // `expired` rather than leaving it `pending` forever. This is read-only -
    // the status is not written back to the store.
    final effective = _isHeartbeatExpired(snapshot)
        ? (SessionSnapshot.fromJson(snapshot.toJson())
            ..status = SnapshotStatus.expired)
        : snapshot;
    return toClientSnapshot(effective);
  }

  Future<SnapshotStatus?> runAbort(
    String snapshotId,
    Map<String, dynamic>? context,
  ) async {
    _requireStore(config.store, 'abort', config.name);
    final previous = await _abortSnapshotInStore(
      config.store!,
      snapshotId,
      context,
    );
    return previous != null ? SnapshotStatus(previous) : null;
  }

  final getSnapshotDataAction =
      Action<GetSnapshotDataInput, SessionSnapshot?, void, void>(
        name: config.name,
        description:
            'Gets snapshot data for ${config.name} by snapshotId or sessionId',
        actionType: .agentSnapshot,
        inputSchema: GetSnapshotDataInput.$schema,
        fn: (lookup, ctx) async =>
            resolveSnapshot(lookup?.snapshotId, lookup?.sessionId, ctx.context),
      );
  registry.register(getSnapshotDataAction);

  final abortAgentAction =
      Action<AgentAbortRequest, AgentAbortResponse, void, void>(
        name: config.name,
        description:
            'Aborts ${config.name} agent by snapshotId. Returns the snapshot '
            'id and its status after the abort attempt.',
        actionType: .agentAbort,
        inputSchema: AgentAbortRequest.$schema,
        outputSchema: AgentAbortResponse.$schema,
        fn: (request, ctx) async {
          final status = await runAbort(request!.snapshotId, ctx.context);
          return AgentAbortResponse(
            snapshotId: request.snapshotId,
            status: status,
          );
        },
      );
  registry.register(abortAgentAction);

  final transport = _InProcessTransport(
    stateManagement: config.store != null
        ? AgentStateManagement.server
        : AgentStateManagement.client,
    primaryAction: primaryAction,
    getSnapshotDataAction: getSnapshotDataAction,
    abortAgentAction: abortAgentAction,
  );

  return Agent<State>._(
    action: primaryAction,
    getSnapshotDataAction: getSnapshotDataAction,
    abortAgentAction: abortAgentAction,
    api: AgentApi<State>(transport, stateSchema: config.stateSchema),
  );
}

class _Outcome {
  _Outcome.flow(this.flowValue) : isDetached = false;
  _Outcome.detached() : isDetached = true, flowValue = null;

  final bool isDetached;
  final ({AgentResult result, String? finalSnapshotId})? flowValue;
}

// ---------------------------------------------------------------------------
// definePromptAgent.
// ---------------------------------------------------------------------------

const _historyTag = '_genkit_history';
const _promptTag = 'agentPreamble';

/// Registers an agent from an existing prompt.
///
/// The [promptInput] supplies values for the referenced prompt's input
/// variables, so a single prompt can be reused and customized by multiple
/// agents.
Agent<State> definePromptAgent<State>(
  Registry registry, {
  required String promptName,
  Map<String, dynamic>? promptInput,
  SchemanticType<State>? stateSchema,
  SessionStore? store,
  ClientTransform? clientTransform,
}) {
  ExecutablePrompt? cachedPrompt;

  Future<AgentResult> fn(SessionRunner sess, AgentFnOptions options) async {
    final sendChunk = options.sendChunk;

    await sess.run((input, ctx) async {
      if (cachedPrompt == null) {
        final action = await registry.lookupAction(
          .executablePrompt,
          promptName,
        );
        if (action is! PromptAction) {
          throw GenkitException(
            "Prompt '$promptName' not found. Ensure it is defined before the "
            'agent is invoked.',
            status: StatusCodes.NOT_FOUND,
          );
        }
        cachedPrompt = action.executablePrompt;
        if (cachedPrompt == null) {
          throw GenkitException(
            "Prompt '$promptName' is not an executable prompt.",
            status: StatusCodes.NOT_FOUND,
          );
        }
      }

      // Tag every history message so we can identify them after render.
      final history = sess.getMessages().map((m) {
        final meta = <String, dynamic>{...?m.metadata, _historyTag: true};
        return Message(role: m.role, content: m.content, metadata: meta);
      }).toList();

      var genOpts = await cachedPrompt!.render(
        promptInput ?? <String, dynamic>{},
        PromptGenerateOptions(messages: history),
      );

      // Tag non-history messages as prompt-template, strip the history tag.
      final renderedMessages = genOpts.messages.map((m) {
        final meta = m.metadata;
        if (meta != null && meta[_historyTag] == true) {
          final rest = Map<String, dynamic>.from(meta)..remove(_historyTag);
          return Message(
            role: m.role,
            content: m.content,
            metadata: rest.isEmpty ? null : rest,
          );
        }
        return Message(
          role: m.role,
          content: m.content,
          metadata: {...?meta, _promptTag: true},
        );
      }).toList();

      GenerateResumeOptions? resume;
      final inputResume = input.resume;
      if (inputResume != null) {
        validateResumeAgainstHistory(inputResume, sess.getMessages());
        resume = GenerateResumeOptions(
          restart: inputResume.restart?.isNotEmpty == true
              ? inputResume.restart
              : null,
          respond: inputResume.respond?.isNotEmpty == true
              ? inputResume.respond
              : null,
        );
      }

      genOpts = GenerateActionOptions.fromJson({
        ...genOpts.toJson(),
        'messages': renderedMessages.map((m) => m.toJson()).toList(),
        'resume': ?resume?.toJson(),
      });

      final res = await runGenerateAction(registry, genOpts, (
        streamingRequested: true,
        sendChunk: (chunk) => sendChunk(AgentStreamChunk(modelChunk: chunk)),
        context: options.context,
        inputStream: null,
        init: null,
        cancel: options.cancel,
      ));

      final aborted = res.finishReason == FinishReason.aborted;

      // Keep everything that is NOT a prompt-template message. On an aborted
      // turn `res.message` is null; the abort path already carries the last-good
      // history in `res.modelRequest`, so leaving `keep` without a trailing
      // model message preserves the user turn as the resume point rather than
      // treating the user's own message as the model reply.
      final reqMessages = res.modelRequest?.messages;
      if (reqMessages != null) {
        final keep = reqMessages
            .where((m) => m.metadata?[_promptTag] != true)
            .toList();
        if (res.message != null) keep.add(res.message!);
        sess.setMessages(keep);
      } else if (res.message != null) {
        sess.addMessages([res.message!]);
      }

      if (res.finishReason == FinishReason.interrupted) {
        final parts =
            res.message?.content.where((p) => p.isToolRequest).toList() ??
            <Part>[];
        if (parts.isNotEmpty) {
          sendChunk(
            AgentStreamChunk(
              modelChunk: ModelResponseChunk(role: Role.model, content: parts),
            ),
          );
        }
      }

      final reason = res.finishReason;
      return TurnResult(
        finishReason: reason != null ? AgentFinishReason(reason.value) : null,
        finishMessage: aborted ? res.finishMessage : null,
      );
    });

    final msgs = sess.getMessages();
    // Only surface the last message as the agent's reply when it is actually a
    // model turn. An aborted turn leaves the user message last (see above), so
    // returning it would echo the user's prompt back as the agent's reply.
    final lastMessage = msgs.isNotEmpty ? msgs.last : null;
    return AgentResult(
      artifacts: sess.getArtifacts(),
      message: lastMessage?.role == Role.model ? lastMessage : null,
      finishReason: sess.lastTurnFinishReason,
    );
  }

  return defineCustomAgent<State>(
    registry,
    name: promptName,
    stateSchema: stateSchema,
    store: store,
    clientTransform: clientTransform,
    fn: fn,
  );
}

// ---------------------------------------------------------------------------
// Resume validation.
// ---------------------------------------------------------------------------

/// Validates that every `resume.restart` and `resume.respond` entry references
/// a tool request that actually exists in the session history.
void validateResumeAgainstHistory(AgentResume resume, List<Message> history) {
  final allToolRequests = <ToolRequest>[];
  for (final msg in history) {
    if (msg.role == Role.model) {
      for (final part in msg.content) {
        if (part.isToolRequest) {
          allToolRequests.add(part.toolRequest!);
        }
      }
    }
  }

  for (final restart in resume.restart ?? const <ToolRequestPart>[]) {
    final tr = restart.toolRequest;
    ToolRequest? match;
    for (final x in allToolRequests) {
      if (x.name == tr.name && x.ref == tr.ref) {
        match = x;
        break;
      }
    }
    if (match == null) {
      throw GenkitException(
        "resume.restart references tool '${tr.name}'"
        '${tr.ref != null ? ' (ref: ${tr.ref})' : ''}'
        ' which was not found in session history.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    if (!_deepEqual(tr.input, match.input)) {
      throw GenkitException(
        "resume.restart for tool '${tr.name}'"
        '${tr.ref != null ? ' (ref: ${tr.ref})' : ''}'
        ' has modified inputs that do not match the original tool request '
        'in session history. Restart inputs must exactly match the '
        'interrupted tool request.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
  }

  for (final respond in resume.respond ?? const <ToolResponsePart>[]) {
    final tr = respond.toolResponse;
    ToolRequest? match;
    for (final x in allToolRequests) {
      if (x.name == tr.name && x.ref == tr.ref) {
        match = x;
        break;
      }
    }
    if (match == null) {
      throw GenkitException(
        "resume.respond references tool '${tr.name}'"
        '${tr.ref != null ? ' (ref: ${tr.ref})' : ''}'
        ' which was not found in session history.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
  }
}
