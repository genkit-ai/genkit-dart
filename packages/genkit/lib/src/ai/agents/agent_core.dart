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

/// Transport-agnostic agent client core.
///
/// Ported from the Genkit JS `agent-core.ts`. This module is browser-safe: it
/// has no `dart:io` dependency. Both the in-process server agent
/// (`ai.defineAgent`) and the HTTP `remoteAgent` client compose the same
/// [AgentChat] / [AgentApi] core over a transport that implements
/// [AgentTransport].
///
/// Custom state is exposed through a `State` type parameter that defaults to
/// `Object?`. Because state travels the wire as plain JSON, `State` is a
/// view-cast over that JSON: parameterize with `Object?` / a `Map`-shaped type,
/// or convert to your own domain types yourself. A mismatched `State` throws at
/// read time (Dart generics are reified, unlike the erased TypeScript original).
library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import '../../schema_extensions.dart';
import '../../types.dart';
import 'json_patch.dart';

/// Casts or parses raw JSON [raw] into the typed [State].
///
/// When a [schema] is supplied, the raw JSON is `parse`d into a real `State`
/// instance (e.g. a schemantic-generated class); otherwise it is a bare view
/// cast over the JSON (the `Object?` / `Map`-shaped default). Returns `null`
/// when [raw] is `null`. Mirrors the `inputSchema != null ? parse : as` pattern
/// used by `Action`.
State? _castOrParseState<State>(Object? raw, SchemanticType<State>? schema) {
  if (raw == null) return null;
  return schema != null ? schema.parse(raw) : raw as State;
}

// ---------------------------------------------------------------------------
// Cancellation (Dart has no AbortSignal/AbortController).
// ---------------------------------------------------------------------------

/// A minimal cooperative cancellation primitive, the Dart stand-in for the
/// Web's `AbortSignal`/`AbortController`.
class CancellationToken {
  final Completer<void> _completer = Completer<void>();
  final List<void Function()> _listeners = [];

  /// Whether cancellation has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  /// Registers [callback] to run when this token is cancelled, and returns a
  /// disposer that unregisters it. Unlike [whenCancelled] (a one-shot future
  /// that can never be detached), this lets a caller-supplied token be reused
  /// across turns without leaking per-turn handlers. If the token is already
  /// cancelled, [callback] runs synchronously and the returned disposer is a
  /// no-op.
  void Function() onCancel(void Function() callback) {
    if (_completer.isCompleted) {
      callback();
      return () {};
    }
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  /// Requests cancellation (idempotent).
  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
    // Snapshot then clear so listeners that (re)register during fan-out don't
    // fire twice and can't be stranded in the list.
    final listeners = [..._listeners];
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

/// The streamed result of a single turn: incremental `stream` chunks plus an
/// `output` future for the final, non-throwing [AgentOutput] (failures resolve
/// with `finishReason: 'failed'`).
typedef TurnStream = ({
  Stream<AgentStreamChunk> stream,
  Future<AgentOutput> output,
});

/// The pluggable backend the agent-client core runs over. Implementations
/// exist for the in-process server agent (driving the agent action directly)
/// and for the HTTP `remoteAgent` (driving stream/run calls).
abstract class AgentTransport {
  /// Declares server- vs client-managed state
  /// ([AgentStateManagement.server] | [AgentStateManagement.client]);
  /// auto-detected when left `null`.
  AgentStateManagement? stateManagement;

  /// Runs a single turn, returning the streamed chunks plus a future for the
  /// final, non-throwing [AgentOutput].
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  });

  /// Runs a single turn without streaming. Returns `null` to signal the core
  /// should fall back to consuming [runTurn]'s `output`.
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  }) => null;

  /// Reads a snapshot. Requires a server store.
  Future<SessionSnapshot?> getSnapshot({String? snapshotId, String? sessionId});

  /// Aborts a running snapshot. Requires a server store. Returns the prior
  /// status, or `null`.
  Future<SnapshotStatus?> abort(String snapshotId);

  /// Releases any resources owned by this transport. The default is a no-op;
  /// transports that own resources (e.g. an HTTP client) override it.
  FutureOr<void> close() {}
}

const Set<String> _terminalStatuses = {
  'completed',
  'failed',
  'aborted',
  'expired',
};

// ---------------------------------------------------------------------------
// Part-derived accessor helpers (mirroring generate).
// ---------------------------------------------------------------------------

String _partsText(List<Part>? parts) =>
    (parts ?? []).map((p) => p.text ?? '').join('');

String _partsReasoning(List<Part>? parts) => (parts ?? [])
    .where((p) => p.isReasoning)
    .map((p) => p.reasoning ?? '')
    .join('');

Media? _firstMedia(List<Part>? parts) {
  for (final p in parts ?? const <Part>[]) {
    final media = p.media;
    if (media != null) {
      return Media(url: media.url, contentType: media.contentType);
    }
  }
  return null;
}

Object? _firstData(List<Part>? parts) {
  for (final p in parts ?? const <Part>[]) {
    if (p.isData) return p.data;
  }
  return null;
}

List<ToolRequestPart> _toolRequestParts(List<Part>? parts) => (parts ?? [])
    .where((p) => p.isToolRequest)
    .map((p) => p.toolRequestPart!)
    .toList();

/// Wraps [text] into an [AgentInput] with a single user message.
AgentInput _agentInputFromText(String text) => AgentInput(
  message: Message(
    role: Role.user,
    content: [TextPart(text: text)],
  ),
);

// ---------------------------------------------------------------------------
// AgentInterrupt
// ---------------------------------------------------------------------------

/// A single tool request a turn paused on. `respond`/`restart` are builders:
/// they return the part to put into a `resume` payload; they do not send.
class AgentInterrupt<Input, Output> {
  AgentInterrupt(ToolRequestPart part)
    : name = part.toolRequest.name,
      ref = part.toolRequest.ref,
      input = part.toolRequest.input as Input;

  final String name;
  final String? ref;
  final Input input;

  /// Builds a `respond` entry for this interrupt. Does not send.
  ToolResponsePart respond(Output output) => ToolResponsePart(
    toolResponse: ToolResponse(name: name, ref: ref, output: output),
  );

  /// Builds a `restart` entry re-issuing the original tool request.
  ToolRequestPart restart() => ToolRequestPart(
    toolRequest: ToolRequest(name: name, ref: ref, input: input),
  );
}

// ---------------------------------------------------------------------------
// AgentResponse
// ---------------------------------------------------------------------------

/// The completed result of a turn. Mirrors `GenerateResponse` and adds the
/// agent fields (`snapshotId`, `state`, `artifacts`).
class AgentResponse<State> {
  AgentResponse._(
    this._raw,
    this._messages, [
    this._fallbackState,
    this._fallbackSessionId,
    this._stateSchema,
  ]);

  /// Test-only constructor for building a response directly from a raw
  /// [AgentOutput] and message list, bypassing a transport turn.
  @visibleForTesting
  AgentResponse.forTesting(AgentOutput raw, List<Message> messages)
    : this._(raw, messages);

  final AgentOutput _raw;
  final List<Message> _messages;

  /// Optional schema used to `parse` the raw wire state into a typed [State]
  /// instance; when `null`, [state] is a bare view cast over the JSON.
  final SchemanticType<State>? _stateSchema;

  /// Fallback custom-state getter. Server-managed agents (with a store) do not
  /// return `state` on the wire; the chat tracks custom state locally (via
  /// streamed `customPatch` chunks), so we fall back to it here, ensuring
  /// `res.state` matches `chat.state`.
  final State? Function()? _fallbackState;

  /// Fallback sessionId getter. Server-managed agents may not echo `sessionId`
  /// on every wire frame; fall back to the chat's tracked sessionId so
  /// `res.sessionId` matches `chat.sessionId`.
  final String? Function()? _fallbackSessionId;

  Message? get message => _raw.message;

  String get text => _partsText(_raw.message?.content);

  String get reasoning => _partsReasoning(_raw.message?.content);

  Media? get media => _firstMedia(_raw.message?.content);

  Object? get data => _firstData(_raw.message?.content);

  List<ToolRequestPart> get toolRequests =>
      _toolRequestParts(_raw.message?.content);

  List<AgentInterrupt> get interrupts => toolRequests
      .where((p) => p.metadata?['interrupt'] != null)
      .map(AgentInterrupt.new)
      .toList();

  List<Message> get messages => _messages;

  AgentFinishReason get finishReason =>
      _raw.finishReason ?? AgentFinishReason.unknown;

  String? get finishMessage => _raw.error?.message;

  AgentOutput get raw => _raw;

  String? get snapshotId => _raw.snapshotId;

  /// Stable identifier correlating snapshots/turns of this conversation.
  String? get sessionId => _raw.sessionId ?? _fallbackSessionId?.call();

  State? get state {
    final fromWire = _raw.state?.custom;
    // Server-managed agents omit `state` on the wire; fall back to the chat's
    // locally tracked custom state (already typed) so `res.state == chat.state`.
    // The wire branch is cast/parsed via the optional schema.
    if (fromWire != null) return _castOrParseState(fromWire, _stateSchema);
    return _fallbackState?.call();
  }

  List<Artifact> get artifacts => _raw.artifacts ?? _raw.state?.artifacts ?? [];

  void assertValid() {
    if (finishReason == AgentFinishReason.blocked) {
      throw StateError(
        'Generation blocked${finishMessage != null ? ': $finishMessage' : ''}.',
      );
    }
    if (_raw.message == null) {
      throw StateError('Agent response has no message.');
    }
  }
}

// ---------------------------------------------------------------------------
// AgentChunk
// ---------------------------------------------------------------------------

/// A streamed chunk. Mirrors `GenerateResponseChunk` and adds the agent fields
/// (`artifact`, `custom`).
class AgentChunk<State> {
  AgentChunk._(this._raw, this._previousText);

  final AgentStreamChunk _raw;
  final String _previousText;
  State? _custom;

  /// Internal: records the post-patch custom state this chunk reports.
  void _setCustom(State? custom) => _custom = custom;

  List<Part>? get _content => _raw.modelChunk?.content;

  String get text => _partsText(_content);

  String get reasoning => _partsReasoning(_content);

  String get accumulatedText => _previousText + text;

  List<ToolRequestPart> get toolRequests => _toolRequestParts(_content);

  Object? get data => _firstData(_content);

  Media? get media => _firstMedia(_content);

  Artifact? get artifact => _raw.artifact;

  /// The full, post-patch custom state. Present only on chunks that carry a
  /// custom-state update; `null` otherwise.
  State? get custom => _custom;

  AgentStreamChunk get raw => _raw;
}

// ---------------------------------------------------------------------------
// AgentTurn
// ---------------------------------------------------------------------------

/// A single in-flight turn — the analog of `generateStream`'s
/// `{stream, response}`, plus [abort].
class AgentTurn<State> {
  AgentTurn._({
    required this.stream,
    required this.response,
    required void Function() onAbort,
  }) : _onAbort = onAbort;

  /// Chunks as the turn progresses.
  final Stream<AgentChunk<State>> stream;

  /// The completed turn, with generate-style accessors.
  final Future<AgentResponse<State>> response;

  final void Function() _onAbort;

  /// Aborts this in-flight turn.
  void abort() => _onAbort();
}

// ---------------------------------------------------------------------------
// AgentError
// ---------------------------------------------------------------------------

/// Thrown when a turn fails. Carries the last-good state so the session is
/// recoverable.
class AgentError<State> implements Exception {
  AgentError({
    required this.message,
    required this.status,
    this.details,
    this.state,
    this.snapshotId,
    required this.response,
  });

  final String message;
  final String status;
  final Object? details;
  final State? state;
  final String? snapshotId;
  final AgentResponse<State> response;

  @override
  String toString() => 'AgentError($status): $message';
}

// ---------------------------------------------------------------------------
// DetachedTask
// ---------------------------------------------------------------------------

/// A handle to a background (detached) task.
class DetachedTask {
  DetachedTask._(this.snapshotId, this._transport);

  final String snapshotId;
  final AgentTransport _transport;

  /// Yields status until a terminal state.
  ///
  /// A snapshot can be briefly absent right after [DetachedTask] is created
  /// (the background worker hasn't persisted the first snapshot yet), so a
  /// `null` read is tolerated. But a snapshot that never appears (deleted, or a
  /// bad id) would otherwise loop forever and leak this poller, so give up
  /// after [maxConsecutiveMisses] consecutive misses.
  Stream<SessionSnapshot> poll({
    Duration interval = const Duration(seconds: 1),
    int maxConsecutiveMisses = 10,
  }) async* {
    var misses = 0;
    while (true) {
      final snap = await _transport.getSnapshot(snapshotId: snapshotId);
      if (snap == null) {
        if (++misses >= maxConsecutiveMisses) {
          throw StateError('Snapshot $snapshotId not found.');
        }
      } else {
        misses = 0;
        yield snap;
        final status = snap.status;
        if (status != null && _terminalStatuses.contains(status.value)) return;
      }
      await Future<void>.delayed(interval);
    }
  }

  /// Resolves when the task reaches a terminal state.
  Future<SessionSnapshot> wait({
    Duration interval = const Duration(seconds: 1),
  }) async {
    SessionSnapshot? last;
    await for (final snap in poll(interval: interval)) {
      last = snap;
    }
    if (last == null) {
      throw StateError('Detached task $snapshotId did not produce a snapshot.');
    }
    return last;
  }

  /// Aborts the task.
  Future<SnapshotStatus?> abort() => _transport.abort(snapshotId);
}

// ---------------------------------------------------------------------------
// AgentChat
// ---------------------------------------------------------------------------

/// A stateful conversation with an agent. Tracks state across turns so callers
/// do not have to thread `snapshotId`/`state` by hand.
class AgentChat<State> {
  AgentChat._(this._transport, [this._connectInit, this._stateSchema]) {
    final init = _connectInit;
    if (init != null) {
      if (init.snapshotId != null) {
        _snapshotId = init.snapshotId;
      }
      if (init.sessionId != null) {
        _sessionId = init.sessionId;
      }
      final state = init.state;
      if (state != null) {
        _hydrateFromState(state);
      }
    }
  }

  final AgentTransport _transport;
  final AgentInit? _connectInit;

  /// Optional schema used to `parse` the raw wire state into a typed [State]
  /// instance; when `null`, [state] is a bare view cast over the JSON.
  final SchemanticType<State>? _stateSchema;

  String? _snapshotId;

  /// The snapshot id tracked across turns of this conversation.
  String? get snapshotId => _snapshotId;

  /// The server-assigned session id, populated from each turn's
  /// [AgentOutput.sessionId]. Lets a server-managed chat be resumed by
  /// `sessionId` later.
  String? _sessionId;

  /// Stable identifier correlating snapshots/turns of this conversation.
  String? get sessionId => _sessionId;

  List<Message> _messages = [];

  /// The running message history of this conversation.
  List<Message> get messages => _messages;

  List<Artifact> _artifacts = [];

  /// The artifacts accumulated across this conversation.
  List<Artifact> get artifacts => _artifacts;

  SessionState? _clientState;

  State? get state => _castOrParseState(_clientState?.custom, _stateSchema);

  /// Replaces the tracked aggregates with (copies of) those carried by a
  /// session state.
  void _hydrateFromState(SessionState? state) {
    _clientState = state;
    _messages = state?.messages != null ? [...state!.messages!] : [];
    _artifacts = state?.artifacts != null ? [...state!.artifacts!] : [];
    if (state?.sessionId != null) {
      _sessionId = state!.sessionId;
    }
  }

  /// Loads aggregates from a server snapshot (used by `loadChat`).
  void _loadFromSnapshot(SessionSnapshot snapshot) {
    _snapshotId = snapshot.snapshotId;
    _hydrateFromState(snapshot.state);
  }

  /// Builds the init for the next turn from tracked aggregates. Always returns
  /// an object (never `null`) — an empty init is the valid "fresh session".
  AgentInit _buildInit() {
    if (_snapshotId != null) {
      return AgentInit(snapshotId: _snapshotId);
    }
    if (_clientState != null) {
      return AgentInit(state: _clientState);
    }
    return _connectInit ?? AgentInit();
  }

  /// Applies a completed turn's output to the running aggregates.
  void _applyOutput(AgentOutput raw) {
    if (raw.snapshotId != null) {
      _snapshotId = raw.snapshotId;
    }
    if (raw.state != null) {
      _clientState = raw.state;
    }
    if (_transport.stateManagement == null) {
      if (raw.snapshotId != null) {
        _transport.stateManagement = AgentStateManagement.server;
      } else if (raw.state != null) {
        _transport.stateManagement = AgentStateManagement.client;
      }
    }
    final stateMessages = raw.state?.messages;
    if (stateMessages != null) {
      _messages = [...stateMessages];
    } else if (raw.message != null) {
      _messages.add(raw.message!);
    }
    // Adopt the server-assigned sessionId so future turns of a server-managed
    // chat resume the same conversation.
    final outSessionId = raw.sessionId;
    if (outSessionId != null) {
      _sessionId = outSessionId;
    }

    final stateArtifacts = raw.state?.artifacts;
    if (stateArtifacts != null) {
      _artifacts = [...stateArtifacts];
    } else if (raw.artifacts != null && raw.artifacts!.isNotEmpty) {
      for (final a in raw.artifacts!) {
        final name = a.name;
        final idx = name != null
            ? _artifacts.indexWhere((x) => x.name == name)
            : -1;
        if (idx >= 0) {
          _artifacts[idx] = a;
        } else {
          _artifacts.add(a);
        }
      }
    }
  }

  /// Resolves a turn's raw `output` into an [AgentResponse], applying it to the
  /// running aggregates and throwing an [AgentError] on a failed turn. Aborted
  /// turns resolve to a synthetic `aborted` response.
  Future<AgentResponse<State>> _buildResponse(
    Future<AgentOutput> output,
    CancellationToken cancel,
    int messageCountBeforeTurn,
  ) async {
    AgentOutput raw;
    try {
      raw = await output;
    } catch (e) {
      if (cancel.isCancelled) {
        raw = AgentOutput(finishReason: AgentFinishReason.aborted);
      } else {
        // A thrown transport error / non-200 rejects before reaching the
        // structured failed/aborted rollback below, so trim the eagerly-pushed
        // user message here too. Otherwise it's left orphaned in `messages`
        // (with no reply) and the next send stacks another one after it.
        if (messages.length > messageCountBeforeTurn) {
          messages.removeRange(messageCountBeforeTurn, messages.length);
        }
        throw _toAgentError(e);
      }
    }
    // A failed/aborted turn that returns no authoritative messages leaves the
    // eagerly-pushed user message orphaned in `messages` with no reply. Roll it
    // back so it isn't re-sent on the next turn. When the turn returns
    // authoritative `state.messages`, `_applyOutput` replaces the array
    // wholesale, so this rollback is a no-op for the success path.
    if ((raw.finishReason == AgentFinishReason.failed ||
            raw.finishReason == AgentFinishReason.aborted) &&
        raw.state?.messages == null &&
        raw.message == null &&
        messages.length > messageCountBeforeTurn) {
      messages.removeRange(messageCountBeforeTurn, messages.length);
    }
    _applyOutput(raw);
    final response = _response(raw);
    if (raw.finishReason == AgentFinishReason.failed) {
      throw AgentError<State>(
        message: raw.error?.message ?? 'Agent turn failed.',
        status: raw.error?.status ?? 'UNKNOWN',
        details: raw.error?.details,
        state: _castOrParseState(raw.state?.custom, _stateSchema),
        snapshotId: raw.snapshotId,
        response: response,
      );
    }
    return response;
  }

  /// Runs a single turn from free-form [text] and resolves with the completed
  /// [AgentResponse]. Sugar for [send] with a single user text message.
  Future<AgentResponse<State>> sendText(
    String text, {
    CancellationToken? cancel,
  }) => send(_agentInputFromText(text), cancel: cancel);

  /// Runs a single turn and resolves with the completed [AgentResponse].
  ///
  /// `send()` is a non-streaming veneer over the streaming path: it runs the
  /// turn via [sendStream] and drains the stream internally before resolving.
  /// Draining matters for server-managed agents (with a store): they do not
  /// return custom `state` on the wire (only a `snapshotId`); the chat's
  /// tracked custom state is kept live by applying the streamed `customPatch`
  /// chunks. Consuming the stream here keeps `send()` and `sendStream()`
  /// consistent. A transport that opts into the non-streaming [AgentTransport.run]
  /// path (e.g. returns full state on the wire) skips the drain.
  Future<AgentResponse<State>> send(
    AgentInput input, {
    CancellationToken? cancel,
  }) async {
    final token = cancel ?? CancellationToken();
    // Bail before pushing the message or dispatching the turn if the caller's
    // token is already cancelled: there's no point starting work, and we must
    // not leave an orphaned user message in `messages`.
    if (token.isCancelled) {
      return _abortedResponse();
    }
    final runFuture = _transport.run(input, _buildInit(), cancel: token);
    if (runFuture != null) {
      final messageCountBeforeTurn = messages.length;
      final inputMessage = input.message;
      if (inputMessage != null) {
        messages.add(inputMessage);
      }
      return _buildResponse(runFuture, token, messageCountBeforeTurn);
    }
    final turn = sendStream(input, cancel: token);
    // Drain the stream so custom-state patches are applied to the chat.
    await for (final _ in turn.stream) {
      // no-op: side effects (custom-state patches) happen as we iterate.
    }
    return turn.response;
  }

  /// Builds an [AgentResponse] for [raw] over a snapshot of the current
  /// aggregates (messages, state, sessionId).
  AgentResponse<State> _response(AgentOutput raw) => AgentResponse<State>._(
    raw,
    [...messages],
    () => state,
    () => sessionId,
    _stateSchema,
  );

  /// Builds a synthetic `aborted` [AgentResponse] for a turn that never ran
  /// (the caller's token was already cancelled). Mirrors the JS core's
  /// pre-aborted bail, which short-circuits with `finishReason: 'aborted'`.
  AgentResponse<State> _abortedResponse() =>
      _response(AgentOutput(finishReason: AgentFinishReason.aborted));

  /// Runs a single turn from free-form [text] and returns an [AgentTurn]. Sugar
  /// for [sendStream] with a single user text message.
  AgentTurn<State> sendTextStream(String text, {CancellationToken? cancel}) =>
      sendStream(_agentInputFromText(text), cancel: cancel);

  /// Runs a single turn and returns an [AgentTurn] exposing `.stream` and
  /// `.response`.
  AgentTurn<State> sendStream(AgentInput input, {CancellationToken? cancel}) {
    final token = cancel ?? CancellationToken();
    // Bail before pushing the message or dispatching the turn if the caller's
    // token is already cancelled: return an empty stream and a synthetic
    // `aborted` response, and leave `messages` untouched. Mirrors the JS
    // core's pre-aborted short-circuit.
    if (token.isCancelled) {
      return AgentTurn<State>._(
        stream: const Stream.empty(),
        response: Future.value(_abortedResponse()),
        onAbort: () {},
      );
    }
    // Remember the message count so a failed/aborted turn that returns no
    // authoritative messages can roll back the eager push below (see
    // `_buildResponse`).
    final messageCountBeforeTurn = messages.length;
    final inputMessage = input.message;
    if (inputMessage != null) {
      messages.add(inputMessage);
    }
    final init = _buildInit();

    final turn = _transport.runTurn(input, init, cancel: token);

    final responsePromise = _buildResponse(
      turn.output,
      token,
      messageCountBeforeTurn,
    );
    // Avoid unhandled-rejection warnings when only the stream is consumed.
    responsePromise.catchError(
      (_) => AgentResponse<State>._(AgentOutput(), messages),
    );

    Stream<AgentChunk<State>> buildStream() async* {
      var previousText = '';
      try {
        await for (final raw in turn.stream) {
          final chunk = AgentChunk<State>._(raw, previousText);
          previousText = chunk.accumulatedText;
          // Keep the locally tracked custom state live mid-stream by applying
          // each streamed JSON Patch to it; surface the post-patch state on
          // the chunk as `chunk.custom`. The first patch of a turn is a
          // whole-document replace that re-bases onto the server baseline.
          final patch = raw.customPatch;
          if (patch != null) {
            _applyCustomPatch(patch);
            chunk._setCustom(state);
          }
          yield chunk;
        }
      } catch (e) {
        if (!token.isCancelled) {
          await responsePromise;
          throw _toAgentError(e);
        }
      }
      // Re-surface a failed turn (which resolves the wire, but rejects here).
      await responsePromise;
    }

    return AgentTurn<State>._(
      stream: buildStream(),
      response: responsePromise,
      onAbort: token.cancel,
    );
  }

  /// Resumes after an interrupt. Sugar for `send` with only the resume params.
  Future<AgentResponse<State>> resume(
    AgentResume resume, {
    CancellationToken? cancel,
  }) => send(AgentInput(resume: resume), cancel: cancel);

  /// Streaming resume. Sugar for `sendStream` with only the resume params.
  AgentTurn<State> resumeStream(
    AgentResume resume, {
    CancellationToken? cancel,
  }) => sendStream(AgentInput(resume: resume), cancel: cancel);

  /// Applies a streamed RFC 6902 JSON Patch to the locally tracked custom
  /// state, keeping [state] live as the turn streams.
  void _applyCustomPatch(List<JsonPatchOperation> patch) {
    final current = _clientState?.custom;
    final next = applyPatch(current, patch.map((op) => op.toJson()).toList());
    if (_clientState != null) {
      final json = Map<String, dynamic>.from(_clientState!.toJson());
      json['custom'] = next;
      _clientState = SessionState.fromJson(json);
    } else {
      _clientState = SessionState(custom: next);
    }
  }

  /// Submits a detached (background) turn. Requires a store.
  Future<DetachedTask> detach(AgentInput input) async {
    final agentInput = AgentInput(
      message: input.message,
      resume: input.resume,
      detach: true,
    );
    final inputMessage = agentInput.message;
    if (inputMessage != null) {
      messages.add(inputMessage);
    }
    final init = _buildInit();

    final token = CancellationToken();
    final turn = _transport.runTurn(agentInput, init, cancel: token);
    final raw = await turn.output;
    _applyOutput(raw);
    final id = raw.snapshotId;
    if (id == null) {
      throw StateError('detach did not return a snapshotId.');
    }
    return DetachedTask._(id, _transport);
  }

  /// Submits a detached (background) turn from free-form [text]. Requires a
  /// store. Sugar for [detach] with a single user text message.
  Future<DetachedTask> detachText(String text) =>
      detach(_agentInputFromText(text));

  /// Aborts the current snapshot.
  Future<SnapshotStatus?> abort() async {
    final id = snapshotId;
    if (id == null) return null;
    return _transport.abort(id);
  }

  AgentError<State> _toAgentError(Object e) {
    if (e is AgentError<State>) return e;
    final message = e.toString();
    final match = RegExp(r'^([A-Z_]+):').firstMatch(message);
    final status = match != null ? match.group(1)! : 'UNKNOWN';
    final raw = AgentOutput(
      finishReason: AgentFinishReason.failed,
      error: AgentErrorInfo(status: status, message: message),
    );
    final response = _response(raw);
    return AgentError<State>(
      message: message,
      status: status,
      details: e,
      state: _castOrParseState(_clientState?.custom, _stateSchema),
      snapshotId: snapshotId,
      response: response,
    );
  }
}

// ---------------------------------------------------------------------------
// AgentApi - builds the API surface over any transport.
// ---------------------------------------------------------------------------

/// The transport-agnostic surface for talking to an agent. The same shape is
/// returned by `ai.defineAgent(...)` on the server and by `remoteAgent(...)`
/// on the client.
class AgentApi<State> {
  @internal
  AgentApi(this._transport, {SchemanticType<State>? stateSchema})
    : _stateSchema = stateSchema;

  final AgentTransport _transport;

  /// Optional schema used to `parse` the raw wire state into a typed [State]
  /// instance; forwarded to every [AgentChat] this api creates. When `null`,
  /// state is a bare view cast over the JSON (the `Object?` / `Map` default).
  final SchemanticType<State>? _stateSchema;

  /// Starts a new chat, optionally attaching via [snapshotId] / [sessionId] /
  /// [state] (provide at most one).
  AgentChat<State> chat({
    String? snapshotId,
    String? sessionId,
    SessionState? state,
  }) {
    assert(
      [snapshotId, sessionId, state].where((x) => x != null).length <= 1,
      'Provide at most one of snapshotId, sessionId, or state.',
    );
    if (snapshotId == null && sessionId == null && state == null) {
      return AgentChat<State>._(_transport, null, _stateSchema);
    }
    return AgentChat<State>._(
      _transport,
      AgentInit(snapshotId: snapshotId, sessionId: sessionId, state: state),
      _stateSchema,
    );
  }

  /// Loads a server snapshot and returns a chat with history restored. Provide
  /// exactly one of [snapshotId] / [sessionId].
  Future<AgentChat<State>> loadChat({
    String? snapshotId,
    String? sessionId,
  }) async {
    assert(
      (snapshotId != null) ^ (sessionId != null),
      'Provide exactly one of snapshotId or sessionId.',
    );
    final snapshot = await _transport.getSnapshot(
      snapshotId: snapshotId,
      sessionId: sessionId,
    );
    if (snapshot == null) {
      final id = snapshotId ?? 'session $sessionId';
      throw StateError('Snapshot $id not found.');
    }
    final chat = AgentChat<State>._(_transport, null, _stateSchema);
    chat._loadFromSnapshot(snapshot);
    return chat;
  }

  /// Reads a snapshot without starting a chat. Requires a server store.
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) => _transport.getSnapshot(snapshotId: snapshotId, sessionId: sessionId);

  /// Aborts a running snapshot. Requires a server store. Returns the prior
  /// status, or `null`.
  Future<SnapshotStatus?> abort(String snapshotId) =>
      _transport.abort(snapshotId);

  /// Releases any resources owned by the underlying transport (e.g. an HTTP
  /// client created by `remoteAgent`). A caller-supplied HTTP client is left
  /// open, since it stays caller-owned. Safe to call on the in-process agent
  /// (a no-op there).
  FutureOr<void> close() => _transport.close();
}
