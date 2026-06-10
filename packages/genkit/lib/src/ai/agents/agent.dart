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
  TurnResult({this.finishReason});

  final AgentFinishReason? finishReason;
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

  final String status;
  final String message;
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

// ---------------------------------------------------------------------------
// Snapshot mutators.
// ---------------------------------------------------------------------------

/// Builds an abort-aware [SnapshotMutator]: it skips the write (returns `null`)
/// when the current snapshot was concurrently aborted, otherwise writes
/// [input]. This prevents a "done"/"failed" write from clobbering an "aborted"
/// status set by a concurrent abort.
SnapshotMutator _abortAwareMutator(SessionSnapshot input) {
  return (current) => current?.status == 'aborted' ? null : input;
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

/// Sets a snapshot's status to `aborted` (unless it already reached a terminal
/// state) and returns its previous status, or `null` when the snapshot does
/// not exist.
Future<String?> _abortSnapshotInStore(
  SessionStore store,
  String snapshotId,
) async {
  String? previousStatus;
  await store.saveSnapshot(snapshotId, (current) {
    if (current == null) return null;
    previousStatus = current.status;
    if (current.status == 'done' ||
        current.status == 'failed' ||
        current.status == 'aborted') {
      return null; // Already terminal - don't override.
    }
    current.status = 'aborted';
    return current;
  });
  return previousStatus;
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
class SessionRunner {
  SessionRunner(
    this.session,
    this.inputCh, {
    SnapshotCallback? snapshotCallback,
    SessionSnapshot? lastSnapshot,
    SessionStore? store,
    this.onEndTurn,
    this.onDetach,
  }) : _snapshotCallback = snapshotCallback,
       _lastSnapshot = lastSnapshot,
       _store = store {
    // Seed the last-good state with the initial session state so a failure on
    // the very first turn still has a valid fallback state.
    lastGoodState = session.getState();
    lastGoodStateVersion = session.getVersion();
  }

  final Session session;
  final Stream<AgentInput> inputCh;

  int turnIndex = 0;
  OnEndTurn? onEndTurn;
  OnDetach? onDetach;
  String? newSnapshotId;

  /// The finish reason of the most recently completed turn.
  AgentFinishReason? lastTurnFinishReason;

  /// Error details of the most recent failed turn.
  AgentErrorDetails? lastTurnError;

  /// The state the most recently successful turn left behind. On a failed turn
  /// this is the state the failed turn started with.
  SessionState? lastGoodState;
  AgentFinishReason? _lastGoodFinishReason;
  int? lastGoodStateVersion;

  final SnapshotCallback? _snapshotCallback;
  SessionSnapshot? _lastSnapshot;
  int _lastSnapshotVersion = 0;
  final SessionStore? _store;

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

  /// Retrieves the custom state of the session.
  dynamic getCustom() => session.getCustom();

  /// Updates the custom state using a mutator function.
  void updateCustom(dynamic Function(dynamic custom) fn) =>
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
      final inputMessages = input.messages;
      if (inputMessages != null) {
        session.addMessages(inputMessages);
      }

      firstCustomPatchInTurn = true;

      final parentSnapshotId = _lastSnapshot?.snapshotId;

      if (_store != null && newSnapshotId == null) {
        newSnapshotId = reserveSnapshotId(
          sessionId: session.sessionId,
          parentId: parentSnapshotId,
        );
      }
      final turnSnapshotId = newSnapshotId;
      newSnapshotId = null;

      final turnContext = TurnContext(
        snapshotId: turnSnapshotId ?? '',
        parentSnapshotId: parentSnapshotId,
        turnIndex: turnIndex,
      );

      try {
        await runInNewSpan('runTurn-${turnIndex + 1}', (_) async {
          final turnResult = await fn(input, turnContext);

          final finishReason = turnResult?.finishReason;
          lastTurnFinishReason = finishReason;
          lastTurnError = null;

          final snapshotId = await maybeSnapshot(
            SnapshotEvent.turnEnd,
            status: 'done',
            snapshotId: turnSnapshotId,
            finishReason: finishReason,
          );

          lastGoodState = session.getState();
          lastGoodStateVersion = session.getVersion();
          _lastGoodFinishReason = finishReason;

          _notifyEndTurn(snapshotId, finishReason);
          return 0;
        }, input: input);
        turnIndex++;
      } catch (e) {
        lastTurnFinishReason = AgentFinishReason.failed;
        lastTurnError = toErrorDetails(e);
        final snapshotId = await maybeSnapshot(
          SnapshotEvent.turnEnd,
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

    final snapshotInput = SessionSnapshot(
      snapshotId: '',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      event: SnapshotEvent.turnEnd,
      state: lastGoodState!,
      parentId: _lastSnapshot?.snapshotId,
      status: 'done',
      finishReason: _lastGoodFinishReason,
    );

    final assignedId = await _store.saveSnapshot(
      null,
      _abortAwareMutator(snapshotInput),
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
  Future<String?> maybeSnapshot(
    SnapshotEvent event, {
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
    final prevState = _lastSnapshot?.state;

    if (_snapshotCallback != null && !isDetached) {
      final keep = _snapshotCallback(
        SnapshotContext(
          state: currentState,
          prevState: prevState,
          turnIndex: turnIndex,
          event: event.value,
        ),
      );
      if (!keep) return null;
    }

    final effectiveId = snapshotId ?? newSnapshotId;

    final snapshotInput = SessionSnapshot(
      snapshotId: effectiveId ?? '',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      event: event,
      state: currentState,
      parentId: _lastSnapshot?.snapshotId,
      status: status,
      finishReason: finishReason,
      error: error != null ? _toErrorInfo(error) : null,
    );

    final assignedId = await _store.saveSnapshot(
      effectiveId,
      _abortAwareMutator(snapshotInput),
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
typedef AgentFn =
    Future<AgentResult> Function(SessionRunner sess, AgentFnOptions options);

/// Validation callback for the `custom` field of a session state.
typedef ValidateCustomState = void Function(dynamic custom);

// ---------------------------------------------------------------------------
// Internal config.
// ---------------------------------------------------------------------------

class _AgentConfig {
  _AgentConfig({
    required this.name,
    this.description,
    this.stateSchema,
    this.store,
    this.snapshotCallback,
    this.clientTransform,
  });

  final String name;
  final String? description;
  final SchemanticType<dynamic>? stateSchema;
  final SessionStore? store;
  final SnapshotCallback? snapshotCallback;
  final ClientTransform? clientTransform;
}

// ---------------------------------------------------------------------------
// resolveSession.
// ---------------------------------------------------------------------------

Future<({Session session, SessionSnapshot? snapshot})> _resolveSession(
  _AgentConfig config,
  SessionStore store,
  AgentInit? init,
  ValidateCustomState validateCustomState,
) async {
  if ((init?.snapshotId != null || init?.sessionId != null) &&
      config.store == null) {
    final which = init!.snapshotId != null ? 'snapshotId' : 'sessionId';
    throw GenkitException(
      "Cannot use '$which' with agent '${config.name}': this agent has no "
      "store configured (client-managed state). Send 'state' instead.",
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }
  if (init?.state != null && config.store != null) {
    throw GenkitException(
      "Cannot send 'state' to agent '${config.name}': this agent uses a "
      "server-managed store. Send 'snapshotId' or 'sessionId' instead.",
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }
  if (init?.snapshotId != null && init?.sessionId != null) {
    throw GenkitException(
      "Cannot send both 'snapshotId' and 'sessionId' to agent "
      "'${config.name}'. Provide exactly one (snapshotId for an exact "
      "snapshot, sessionId for the session's latest snapshot).",
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (init?.snapshotId != null) {
    final snapshot = await store.getSnapshot(snapshotId: init!.snapshotId);
    if (snapshot == null) {
      throw GenkitException(
        'Snapshot ${init.snapshotId} not found',
        status: StatusCodes.NOT_FOUND,
      );
    }
    validateCustomState(snapshot.state.custom);
    return (snapshot: snapshot, session: Session(snapshot.state));
  }

  if (init?.sessionId != null) {
    final snapshot = await store.getSnapshot(sessionId: init!.sessionId);
    if (snapshot != null) {
      validateCustomState(snapshot.state.custom);
      return (snapshot: snapshot, session: Session(snapshot.state));
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
      ),
    );
  }

  if (init?.state != null && config.store == null) {
    validateCustomState(init!.state!.custom);
    return (snapshot: null, session: Session(init.state!));
  }

  return (
    snapshot: null,
    session: Session(
      SessionState(custom: <String, dynamic>{}, artifacts: [], messages: []),
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
            final turnSnapshotId =
                runner.newSnapshotId ??
                reserveSnapshotId(sessionId: runner.session.sessionId);
            runner.newSnapshotId = turnSnapshotId;

            await runner.maybeSnapshot(
              SnapshotEvent.turnEnd,
              status: 'pending',
              snapshotId: turnSnapshotId,
            );
            runner.isDetached = true;

            runner.onDetach?.call(turnSnapshotId);
          }
          final hasPayload =
              (input.messages?.isNotEmpty ?? false) ||
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

class _InProcessTransport extends AgentTransport {
  _InProcessTransport({
    required String stateManagement,
    required this.primaryAction,
    required this.getSnapshotFn,
    required this.abortFn,
  }) {
    this.stateManagement = stateManagement;
  }

  final Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>
  primaryAction;
  final Future<SessionSnapshot?> Function(String? snapshotId, String? sessionId)
  getSnapshotFn;
  final Future<String?> Function(String snapshotId) abortFn;

  BidiActionStream<AgentStreamChunk, AgentOutput, AgentInput> _startBidi(
    AgentInput input,
    AgentInit init,
  ) {
    final bidi = primaryAction.streamBidi(init: init);
    bidi.send(input);
    bidi.close();
    return bidi;
  }

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  }) {
    final bidi = _startBidi(input, init);
    return (stream: bidi, output: bidi.onResult);
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  }) {
    return _startBidi(input, init).onResult;
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) => getSnapshotFn(snapshotId, sessionId);

  @override
  Future<String?> abort(String snapshotId) => abortFn(snapshotId);
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
class Agent {
  Agent._({
    required this.action,
    required this.getSnapshotDataAction,
    required this.abortAgentAction,
    required AgentApi api,
    required Future<SessionSnapshot?> Function(
      String? snapshotId,
      String? sessionId,
    )
    resolveSnapshot,
    required Future<String?> Function(String snapshotId) runAbort,
  }) : _api = api,
       _resolveSnapshot = resolveSnapshot,
       _runAbort = runAbort;

  /// The primary bidi agent turn action.
  final Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit> action;

  /// The `getSnapshotData` action.
  final Action<GetSnapshotDataInput, SessionSnapshot?, void, void>
  getSnapshotDataAction;

  /// The `abort` action.
  final Action<String, String?, void, void> abortAgentAction;

  final AgentApi _api;
  final Future<SessionSnapshot?> Function(String? snapshotId, String? sessionId)
  _resolveSnapshot;
  final Future<String?> Function(String snapshotId) _runAbort;

  /// Starts a new chat, optionally attaching via [snapshotId] / [sessionId] /
  /// [state] (provide at most one).
  AgentChat chat({
    String? snapshotId,
    String? sessionId,
    SessionState? state,
  }) => _api.chat(snapshotId: snapshotId, sessionId: sessionId, state: state);

  /// Loads a server snapshot and returns a chat with history restored.
  Future<AgentChat> loadChat({String? snapshotId, String? sessionId}) =>
      _api.loadChat(snapshotId: snapshotId, sessionId: sessionId);

  /// Reads a snapshot without starting a chat. Requires a server store.
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) => _api.getSnapshot(snapshotId: snapshotId, sessionId: sessionId);

  /// Reads a snapshot (applying the client transform). Requires a server store.
  Future<SessionSnapshot?> getSnapshotData({
    String? snapshotId,
    String? sessionId,
  }) => _resolveSnapshot(snapshotId, sessionId);

  /// Aborts a running snapshot. Requires a server store. Returns the prior
  /// status, or `null`.
  Future<String?> abort(String snapshotId) => _runAbort(snapshotId);
}

// ---------------------------------------------------------------------------
// defineCustomAgent.
// ---------------------------------------------------------------------------

/// Registers a multi-turn custom agent action capable of maintaining
/// persistent state.
Agent defineCustomAgent(
  Registry registry, {
  required String name,
  String? description,
  SchemanticType<dynamic>? stateSchema,
  SessionStore? store,
  SnapshotCallback? snapshotCallback,
  ClientTransform? clientTransform,
  required AgentFn fn,
}) {
  final config = _AgentConfig(
    name: name,
    description: description,
    stateSchema: stateSchema,
    store: store,
    snapshotCallback: snapshotCallback,
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

  final primaryAction =
      Action<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>(
        name: config.name,
        description: config.description,
        actionType: 'agent',
        inputSchema: AgentInput.$schema,
        outputSchema: AgentOutput.$schema,
        streamSchema: AgentStreamChunk.$schema,
        initSchema: AgentInit.$schema,
        metadata: {
          'agent': {
            'stateManagement': config.store != null ? 'server' : 'client',
            'abortable': config.store is SnapshotChangeNotifier,
            'stateSchema': ?stateJsonSchema,
          },
        },
        fn: (input, ctx) async {
          final init = ctx.init;
          final resolvedStore = config.store ?? InMemorySessionStore();

          Session session;
          SessionSnapshot? snapshot;
          try {
            final resolved = await _resolveSession(
              config,
              resolvedStore,
              init,
              validateCustomState,
            );
            session = resolved.session;
            snapshot = resolved.snapshot;
          } catch (e) {
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
          final cancelToken = CancellationToken();
          void Function()? unsubscribe;
          late SessionRunner runner;

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

          runner = SessionRunner(
            session,
            runnerInputController.stream,
            store: resolvedStore,
            snapshotCallback: config.snapshotCallback,
            lastSnapshot: snapshot,
            onDetach: (snapshotId) {
              detachedSnapshotId = snapshotId;
              if (!detachCompleter.isCompleted) detachCompleter.complete();

              if (resolvedStore is SnapshotChangeNotifier) {
                unsubscribe = (resolvedStore as SnapshotChangeNotifier)
                    .onSnapshotStateChange(snapshotId, (snap) {
                      if (snap.status == 'aborted') {
                        cancelToken.cancel();
                        unsubscribe?.call();
                      }
                    });
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

          final offArtifactAdded = session.on(
            'artifactAdded',
            sendArtifactChunk,
          );
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
              final finalSnapshotId = await runner.maybeSnapshot(
                SnapshotEvent.invocationEnd,
              );
              return (result: result, finalSnapshotId: finalSnapshotId);
            } finally {
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
              finishReason: AgentFinishReason.failed,
              error: _toErrorInfo(runner.lastTurnError!),
              artifacts:
                  (agentResult.artifacts != null &&
                      agentResult.artifacts!.isNotEmpty)
                  ? agentResult.artifacts
                  : null,
              message: (lastGoodMessages != null && lastGoodMessages.isNotEmpty)
                  ? lastGoodMessages.last
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
            artifacts:
                (agentResult.artifacts != null &&
                    agentResult.artifacts!.isNotEmpty)
                ? agentResult.artifacts
                : null,
            message: agentResult.message,
            finishReason: finishReason,
            snapshotId: config.store != null ? finalSnapshotId : null,
            state: config.store == null
                ? toClientState(session.getState())
                : null,
          );
        },
      );

  registry.register(primaryAction);

  SessionSnapshot toClientSnapshot(SessionSnapshot snapshot) {
    if (config.clientTransform?.state == null) return snapshot;
    final json = Map<String, dynamic>.from(snapshot.toJson());
    json['state'] = config.clientTransform!.state!(snapshot.state).toJson();
    return SessionSnapshot.fromJson(json);
  }

  Future<SessionSnapshot?> resolveSnapshot(
    String? snapshotId,
    String? sessionId,
  ) async {
    _requireStore(config.store, 'getSnapshotData', config.name);
    final snapshot = await config.store!.getSnapshot(
      snapshotId: snapshotId,
      sessionId: sessionId,
    );
    return snapshot != null ? toClientSnapshot(snapshot) : null;
  }

  Future<String?> runAbort(String snapshotId) async {
    _requireStore(config.store, 'abort', config.name);
    return _abortSnapshotInStore(config.store!, snapshotId);
  }

  final getSnapshotDataAction =
      Action<GetSnapshotDataInput, SessionSnapshot?, void, void>(
        name: config.name,
        description:
            'Gets snapshot data for ${config.name} by snapshotId or sessionId',
        actionType: 'agent-snapshot',
        inputSchema: GetSnapshotDataInput.$schema,
        fn: (lookup, ctx) async =>
            resolveSnapshot(lookup?.snapshotId, lookup?.sessionId),
      );
  registry.register(getSnapshotDataAction);

  final abortAgentAction = Action<String, String?, void, void>(
    name: config.name,
    description:
        'Aborts ${config.name} agent by snapshotId. Returns the previous '
        "status of the snapshot before it was set to 'aborted', or null if "
        'the snapshot was not found.',
    actionType: 'agent-abort',
    inputSchema: SchemanticType.string(),
    fn: (snapshotId, ctx) async => runAbort(snapshotId!),
  );
  registry.register(abortAgentAction);

  final transport = _InProcessTransport(
    stateManagement: config.store != null ? 'server' : 'client',
    primaryAction: primaryAction,
    getSnapshotFn: resolveSnapshot,
    abortFn: runAbort,
  );

  return Agent._(
    action: primaryAction,
    getSnapshotDataAction: getSnapshotDataAction,
    abortAgentAction: abortAgentAction,
    api: createAgentApi(transport),
    resolveSnapshot: resolveSnapshot,
    runAbort: runAbort,
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
Agent definePromptAgent(
  Registry registry, {
  required String promptName,
  SchemanticType<dynamic>? stateSchema,
  SessionStore? store,
  SnapshotCallback? snapshotCallback,
  ClientTransform? clientTransform,
}) {
  ExecutablePrompt? cachedPrompt;

  Future<AgentResult> fn(SessionRunner sess, AgentFnOptions options) async {
    final sendChunk = options.sendChunk;

    await sess.run((input, ctx) async {
      if (cachedPrompt == null) {
        final action = await registry.lookupAction(
          'executable-prompt',
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
        <String, dynamic>{},
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
          restart:
              (inputResume.restart != null && inputResume.restart!.isNotEmpty)
              ? inputResume.restart
              : null,
          respond:
              (inputResume.respond != null && inputResume.respond!.isNotEmpty)
              ? inputResume.respond
              : null,
        );
      }

      genOpts = GenerateActionOptions.fromJson({
        ...genOpts.toJson(),
        'messages': renderedMessages.map((m) => m.toJson()).toList(),
        if (resume != null) 'resume': resume.toJson(),
      });

      final res = await runGenerateAction(registry, genOpts, (
        streamingRequested: true,
        sendChunk: (chunk) => sendChunk(AgentStreamChunk(modelChunk: chunk)),
        context: options.context,
        inputStream: null,
        init: null,
      ));

      // Keep everything that is NOT a prompt-template message.
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
              modelChunk: ModelResponseChunk(role: Role.tool, content: parts),
            ),
          );
        }
      }

      final reason = res.finishReason;
      return TurnResult(
        finishReason: reason != null ? AgentFinishReason(reason.value) : null,
      );
    });

    final msgs = sess.getMessages();
    return AgentResult(
      artifacts: sess.getArtifacts(),
      message: msgs.isNotEmpty ? msgs.last : null,
      finishReason: sess.lastTurnFinishReason,
    );
  }

  return defineCustomAgent(
    registry,
    name: promptName,
    stateSchema: stateSchema,
    store: store,
    snapshotCallback: snapshotCallback,
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
