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
/// [AgentChat] / [createAgentApi] core over a transport that implements
/// [AgentTransport].
///
/// Custom state is handled as plain JSON (`dynamic`), mirroring the JS core's
/// `unknown` state. A typed `State` layer can be added by callers on top.
library;

import 'dart:async';

import '../../schema_extensions.dart';
import '../../types.dart';
import 'json_patch.dart';

// ---------------------------------------------------------------------------
// Cancellation (Dart has no AbortSignal/AbortController).
// ---------------------------------------------------------------------------

/// A minimal cooperative cancellation primitive, the Dart stand-in for the
/// Web's `AbortSignal`/`AbortController`.
class CancellationToken {
  final Completer<void> _completer = Completer<void>();

  /// Whether cancellation has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  /// Requests cancellation (idempotent).
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
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
  /// Declares server- vs client-managed state (`'server'` | `'client'`);
  /// auto-detected when left `null`.
  String? stateManagement;

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
  Future<String?> abort(String snapshotId);
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

dynamic _firstData(List<Part>? parts) {
  for (final p in parts ?? const <Part>[]) {
    if (p.isData) return p.data;
  }
  return null;
}

List<ToolRequestPart> _toolRequestParts(List<Part>? parts) => (parts ?? [])
    .where((p) => p.isToolRequest)
    .map((p) => p.toolRequestPart!)
    .toList();

// ---------------------------------------------------------------------------
// AgentInterrupt
// ---------------------------------------------------------------------------

/// A single tool request a turn paused on. `respond`/`restart` are builders:
/// they return the part to put into a `resume` payload; they do not send.
class AgentInterrupt {
  AgentInterrupt(ToolRequestPart part)
    : name = part.toolRequest.name,
      ref = part.toolRequest.ref,
      input = part.toolRequest.input;

  final String name;
  final String? ref;
  final dynamic input;

  /// Builds a `respond` entry for this interrupt. Does not send.
  ToolResponsePart respond(dynamic output) => ToolResponsePart(
    toolResponse: ToolResponse(name: name, ref: ref, output: output),
  );

  /// Builds a `restart` entry re-issuing the original tool request.
  ToolRequestPart restart() => ToolRequestPart(
    toolRequest: ToolRequest(
      name: name,
      ref: ref,
      input: input is Map<String, dynamic>
          ? input as Map<String, dynamic>
          : (input is Map ? (input as Map).cast<String, dynamic>() : null),
    ),
  );
}

// ---------------------------------------------------------------------------
// AgentResponse
// ---------------------------------------------------------------------------

/// The completed result of a turn. Mirrors `GenerateResponse` and adds the
/// agent fields (`snapshotId`, `state`, `artifacts`).
class AgentResponse {
  AgentResponse(
    this._raw,
    this._messages, [
    this._fallbackState,
    this._fallbackSessionId,
  ]);

  final AgentOutput _raw;
  final List<Message> _messages;

  /// Fallback custom-state getter. Server-managed agents (with a store) do not
  /// return `state` on the wire; the chat tracks custom state locally (via
  /// streamed `customPatch` chunks), so we fall back to it here, ensuring
  /// `res.state` matches `chat.state`.
  final dynamic Function()? _fallbackState;

  /// Fallback sessionId getter. Server-managed agents may not echo `sessionId`
  /// on every wire frame; fall back to the chat's tracked sessionId so
  /// `res.sessionId` matches `chat.sessionId`.
  final String? Function()? _fallbackSessionId;

  Message? get message => _raw.message;

  String get text => _partsText(_raw.message?.content);

  String get reasoning => _partsReasoning(_raw.message?.content);

  Media? get media => _firstMedia(_raw.message?.content);

  dynamic get data => _firstData(_raw.message?.content);

  List<ToolRequestPart> get toolRequests =>
      _toolRequestParts(_raw.message?.content);

  List<AgentInterrupt> get interrupts => toolRequests
      .where((p) => p.metadata?['interrupt'] != null)
      .map(AgentInterrupt.new)
      .toList();

  List<Message> get messages => _messages;

  GenerationUsage get usage {
    final raw = _raw.toJson()['usage'];
    return GenerationUsage.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{},
    );
  }

  AgentFinishReason get finishReason =>
      _raw.finishReason ?? AgentFinishReason.unknown;

  String? get finishMessage => _raw.error?.message;

  AgentOutput get raw => _raw;

  String? get snapshotId => _raw.snapshotId;

  /// Stable identifier correlating snapshots/turns of this conversation.
  String? get sessionId => _raw.sessionId ?? _fallbackSessionId?.call();

  dynamic get state {
    final fromWire = _raw.state?.custom;
    // Server-managed agents omit `state` on the wire; fall back to the chat's
    // locally tracked custom state so `res.state == chat.state`.
    return fromWire ?? _fallbackState?.call();
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
class AgentChunk {
  AgentChunk(this._raw, this._previousText);

  final AgentStreamChunk _raw;
  final String _previousText;
  dynamic _custom;

  /// Internal: records the post-patch custom state this chunk reports.
  void setCustom(dynamic custom) => _custom = custom;

  List<Part>? get _content => _raw.modelChunk?.content;

  String get text => _partsText(_content);

  String get reasoning => _partsReasoning(_content);

  String get accumulatedText => _previousText + text;

  List<ToolRequestPart> get toolRequests => _toolRequestParts(_content);

  dynamic get data => _firstData(_content);

  Media? get media => _firstMedia(_content);

  Artifact? get artifact => _raw.artifact;

  /// The full, post-patch custom state. Present only on chunks that carry a
  /// custom-state update; `null` otherwise.
  dynamic get custom => _custom;

  AgentStreamChunk get raw => _raw;
}

// ---------------------------------------------------------------------------
// AgentTurn
// ---------------------------------------------------------------------------

/// A single in-flight turn — the analog of `generateStream`'s
/// `{stream, response}`, plus [abort].
class AgentTurn {
  AgentTurn({
    required this.stream,
    required this.response,
    required void Function() onAbort,
  }) : _onAbort = onAbort;

  /// Chunks as the turn progresses.
  final Stream<AgentChunk> stream;

  /// The completed turn, with generate-style accessors.
  final Future<AgentResponse> response;

  final void Function() _onAbort;

  /// Aborts this in-flight turn.
  void abort() => _onAbort();
}

// ---------------------------------------------------------------------------
// AgentError
// ---------------------------------------------------------------------------

/// Thrown when a turn fails. Carries the last-good state so the session is
/// recoverable.
class AgentError implements Exception {
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
  final dynamic state;
  final String? snapshotId;
  final AgentResponse response;

  @override
  String toString() => 'AgentError($status): $message';
}

// ---------------------------------------------------------------------------
// DetachedTask
// ---------------------------------------------------------------------------

/// A handle to a background (detached) task.
class DetachedTask {
  DetachedTask(this.snapshotId, this._transport);

  final String snapshotId;
  final AgentTransport _transport;

  /// Yields status until a terminal state.
  Stream<SessionSnapshot> poll({int intervalMs = 1000}) async* {
    while (true) {
      final snap = await _transport.getSnapshot(snapshotId: snapshotId);
      if (snap != null) {
        yield snap;
        final status = snap.status;
        if (status != null && _terminalStatuses.contains(status.value)) {
          return;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: intervalMs));
    }
  }

  /// Resolves when the task reaches a terminal state.
  Future<SessionSnapshot> wait({int intervalMs = 1000}) async {
    SessionSnapshot? last;
    await for (final snap in poll(intervalMs: intervalMs)) {
      last = snap;
    }
    if (last == null) {
      throw StateError('Detached task $snapshotId did not produce a snapshot.');
    }
    return last;
  }

  /// Aborts the task.
  Future<String?> abort() => _transport.abort(snapshotId);
}

// ---------------------------------------------------------------------------
// AgentChat
// ---------------------------------------------------------------------------

/// A stateful conversation with an agent. Tracks state across turns so callers
/// do not have to thread `snapshotId`/`state` by hand.
class AgentChat {
  AgentChat(this._transport, [this._connectInit]) {
    final init = _connectInit;
    if (init != null) {
      if (init.snapshotId != null) {
        snapshotId = init.snapshotId;
      }
      final state = init.state;
      if (state != null) {
        _hydrateFromState(state);
      }
    }
  }

  final AgentTransport _transport;
  final AgentInit? _connectInit;

  String? snapshotId;

  /// The server-assigned session id, populated from each turn's
  /// [AgentOutput.sessionId]. Lets a server-managed chat be resumed by
  /// `sessionId` later.
  String? sessionId;
  List<Message> messages = [];
  List<Artifact> artifacts = [];

  SessionState? _clientState;

  dynamic get state => _clientState?.custom;

  /// Replaces the tracked aggregates with (copies of) those carried by a
  /// session state.
  void _hydrateFromState(SessionState? state) {
    _clientState = state;
    messages = state?.messages != null ? [...state!.messages!] : [];
    artifacts = state?.artifacts != null ? [...state!.artifacts!] : [];
  }

  /// Loads aggregates from a server snapshot (used by `loadChat`).

  void loadFromSnapshot(SessionSnapshot snapshot) {
    snapshotId = snapshot.snapshotId;
    _hydrateFromState(snapshot.state);
  }

  /// Builds the init for the next turn from tracked aggregates. Always returns
  /// an object (never `null`) — an empty init is the valid "fresh session".
  AgentInit _buildInit() {
    if (snapshotId != null) {
      return AgentInit(snapshotId: snapshotId);
    }
    if (_clientState != null) {
      return AgentInit(state: _clientState);
    }
    return _connectInit ?? AgentInit();
  }

  /// Applies a completed turn's output to the running aggregates.
  void _applyOutput(AgentOutput raw) {
    if (raw.snapshotId != null) {
      snapshotId = raw.snapshotId;
    }
    if (raw.state != null) {
      _clientState = raw.state;
    }
    if (_transport.stateManagement == null) {
      if (raw.snapshotId != null) {
        _transport.stateManagement = 'server';
      } else if (raw.state != null) {
        _transport.stateManagement = 'client';
      }
    }
    final stateMessages = raw.state?.messages;
    if (stateMessages != null) {
      messages = [...stateMessages];
    } else if (raw.message != null) {
      messages.add(raw.message!);
    }
    // Adopt the server-assigned sessionId so future turns of a server-managed
    // chat resume the same conversation.
    final outSessionId = raw.sessionId;
    if (outSessionId != null) {
      sessionId = outSessionId;
    }

    final stateArtifacts = raw.state?.artifacts;
    if (stateArtifacts != null) {
      artifacts = [...stateArtifacts];
    } else if (raw.artifacts != null && raw.artifacts!.isNotEmpty) {
      for (final a in raw.artifacts!) {
        final name = a.name;
        final idx = name != null
            ? artifacts.indexWhere((x) => x.name == name)
            : -1;
        if (idx >= 0) {
          artifacts[idx] = a;
        } else {
          artifacts.add(a);
        }
      }
    }
  }

  /// Resolves a turn's raw `output` into an [AgentResponse], applying it to the
  /// running aggregates and throwing an [AgentError] on a failed turn. Aborted
  /// turns resolve to a synthetic `aborted` response.
  Future<AgentResponse> _buildResponse(
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
    final response = AgentResponse(
      raw,
      [...messages],
      () => state,
      () => sessionId,
    );
    if (raw.finishReason == AgentFinishReason.failed) {
      throw AgentError(
        message: raw.error?.message ?? 'Agent turn failed.',
        status: raw.error?.status ?? 'UNKNOWN',
        details: raw.error?.details,
        state: raw.state?.custom,
        snapshotId: raw.snapshotId,
        response: response,
      );
    }
    return response;
  }

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
  Future<AgentResponse> send(
    AgentInput input, {
    CancellationToken? cancel,
  }) async {
    final token = cancel ?? CancellationToken();
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

  /// Runs a single turn and returns an [AgentTurn] exposing `.stream` and
  /// `.response`.
  AgentTurn sendStream(AgentInput input, {CancellationToken? cancel}) {
    final token = cancel ?? CancellationToken();
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
    responsePromise.catchError((_) => AgentResponse(AgentOutput(), messages));

    Stream<AgentChunk> buildStream() async* {
      var previousText = '';
      try {
        await for (final raw in turn.stream) {
          final chunk = AgentChunk(raw, previousText);
          previousText = chunk.accumulatedText;
          // Keep the locally tracked custom state live mid-stream by applying
          // each streamed JSON Patch to it; surface the post-patch state on
          // the chunk as `chunk.custom`. The first patch of a turn is a
          // whole-document replace that re-bases onto the server baseline.
          final patch = raw.customPatch;
          if (patch != null) {
            _applyCustomPatch(patch);
            chunk.setCustom(state);
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

    return AgentTurn(
      stream: buildStream(),
      response: responsePromise,
      onAbort: token.cancel,
    );
  }

  /// Resumes after an interrupt. Sugar for `send` with only the resume params.
  Future<AgentResponse> resume(
    AgentResume resume, {
    CancellationToken? cancel,
  }) => send(AgentInput(resume: resume), cancel: cancel);

  /// Streaming resume. Sugar for `sendStream` with only the resume params.
  AgentTurn resumeStream(AgentResume resume, {CancellationToken? cancel}) =>
      sendStream(AgentInput(resume: resume), cancel: cancel);

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
    return DetachedTask(id, _transport);
  }

  /// Aborts the current snapshot.
  Future<String?> abort() async {
    final id = snapshotId;
    if (id == null) return null;
    return _transport.abort(id);
  }

  AgentError _toAgentError(Object e) {
    if (e is AgentError) return e;
    final message = e is Error ? e.toString() : e.toString();
    final match = RegExp(r'^([A-Z_]+):').firstMatch(message);
    final status = match != null ? match.group(1)! : 'UNKNOWN';
    final raw = AgentOutput(
      finishReason: AgentFinishReason.failed,
      error: AgentErrorInfo(status: status, message: message),
    );
    final response = AgentResponse(
      raw,
      [...messages],
      () => _clientState?.custom,
      () => sessionId,
    );
    return AgentError(
      message: message,
      status: status,
      details: e,
      state: _clientState?.custom,
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
class AgentApi {
  AgentApi(this._transport);

  final AgentTransport _transport;

  /// Starts a new chat, optionally attaching via [snapshotId] / [sessionId] /
  /// [state] (provide at most one).
  AgentChat chat({String? snapshotId, String? sessionId, SessionState? state}) {
    if (snapshotId == null && sessionId == null && state == null) {
      return AgentChat(_transport);
    }
    return AgentChat(
      _transport,
      AgentInit(snapshotId: snapshotId, sessionId: sessionId, state: state),
    );
  }

  /// Loads a server snapshot and returns a chat with history restored. Provide
  /// exactly one of [snapshotId] / [sessionId].
  Future<AgentChat> loadChat({String? snapshotId, String? sessionId}) async {
    final snapshot = await _transport.getSnapshot(
      snapshotId: snapshotId,
      sessionId: sessionId,
    );
    if (snapshot == null) {
      final id = snapshotId ?? 'session $sessionId';
      throw StateError('Snapshot $id not found.');
    }
    final chat = AgentChat(_transport);
    chat.loadFromSnapshot(snapshot);
    return chat;
  }

  /// Reads a snapshot without starting a chat. Requires a server store.
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) => _transport.getSnapshot(snapshotId: snapshotId, sessionId: sessionId);

  /// Aborts a running snapshot. Requires a server store.
  Future<String?> abort(String snapshotId) => _transport.abort(snapshotId);
}

/// Composes the [AgentApi] surface over an [AgentTransport]. Shared by the
/// in-process server agent and the HTTP `remoteAgent`.
AgentApi createAgentApi(AgentTransport transport) => AgentApi(transport);

/// Wraps `input` text into an [AgentInput] with a single user message.
AgentInput agentInputFromText(String text) => AgentInput(
  message: Message(
    role: Role.user,
    content: [TextPart(text: text)],
  ),
);
