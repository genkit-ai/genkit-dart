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

/// HTTP client for talking to a Genkit agent served over HTTP.
///
/// Ported from the Genkit JS `client/agent.ts`. Composes the same browser-safe
/// [AgentApi] / [AgentChat] core (`agent_core.dart`) over an [AgentTransport]
/// that reuses the shared Genkit client ([RemoteAction] / `streamFlow`). The
/// wire body matches the JS client: `{ "data": <input>, "init": <init> }`.
library;

import 'dart:async';

import 'package:http/http.dart' as http;

import '../../client/client.dart';
import '../../types.dart';
import 'agent_core.dart';

/// Resolves request headers, either statically or per request.
typedef HeadersResolver = FutureOr<Map<String, String>?> Function();

/// Options for [remoteAgent].
class RemoteAgentOptions {
  RemoteAgentOptions({
    required this.url,
    this.getSnapshotUrl,
    this.abortUrl,
    this.headers,
    this.stateManagement,
    this.httpClient,
  });

  /// Required. The agent endpoint.
  final String url;

  /// Optional. Defaults to `'$url/getSnapshot'`.
  final String? getSnapshotUrl;

  /// Optional. Defaults to `'$url/abort'`.
  final String? abortUrl;

  /// Optional. Static headers, or a function called per request.
  final HeadersResolver? headers;

  /// Optional. Declares server- vs client-managed state; inferred otherwise.
  final String? stateManagement;

  /// Optional. Provide to control the HTTP client lifecycle.
  final http.Client? httpClient;
}

/// Creates a typed client for talking to a Genkit agent over HTTP.
///
/// ```dart
/// final agent = remoteAgent(RemoteAgentOptions(url: 'http://host/weatherAgent'));
/// final chat = agent.chat();
/// final res = await chat.send(agentInputFromText('Weather in Tokyo?'));
/// print(res.text);
/// ```
AgentApi remoteAgent(RemoteAgentOptions options) =>
    createAgentApi(_HttpAgentTransport(options));

class _HttpAgentTransport extends AgentTransport {
  _HttpAgentTransport(this._options)
    : _httpClient = _options.httpClient ?? http.Client() {
    stateManagement = _options.stateManagement;

    _turnAction =
        defineRemoteAction<
          AgentInput,
          AgentOutput,
          AgentStreamChunk,
          AgentInit
        >(
          url: _options.url,
          httpClient: _httpClient,
          outputSchema: AgentOutput.$schema,
          streamSchema: AgentStreamChunk.$schema,
        );

    _snapshotAction =
        defineRemoteAction<Map<String, dynamic>, SessionSnapshot?, void, void>(
          url: _options.getSnapshotUrl ?? '${_options.url}/getSnapshot',
          httpClient: _httpClient,
          fromResponse: (d) => d == null
              ? null
              : SessionSnapshot.fromJson((d as Map).cast<String, dynamic>()),
          fromStreamChunk: (_) {},
        );

    _abortAction =
        defineRemoteAction<AgentAbortRequest, AgentAbortResponse, void, void>(
          url: _options.abortUrl ?? '${_options.url}/abort',
          httpClient: _httpClient,
          fromResponse: (d) =>
              AgentAbortResponse.fromJson((d as Map).cast<String, dynamic>()),
          fromStreamChunk: (_) {},
        );
  }

  final RemoteAgentOptions _options;
  final http.Client _httpClient;

  late final RemoteAction<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>
  _turnAction;
  late final RemoteAction<Map<String, dynamic>, SessionSnapshot?, void, void>
  _snapshotAction;
  late final RemoteAction<AgentAbortRequest, AgentAbortResponse, void, void>
  _abortAction;

  Future<Map<String, String>?> _resolveHeaders() async {
    final headers = _options.headers;
    if (headers == null) return null;
    return headers();
  }

  @override
  TurnStream runTurn(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  }) {
    final controller = StreamController<AgentStreamChunk>();
    final outputCompleter = Completer<AgentOutput>();

    () async {
      StreamSubscription<AgentStreamChunk>? sub;
      try {
        final headers = await _resolveHeaders();
        final actionStream = _turnAction.stream(
          input: input,
          init: init,
          headers: headers,
        );

        // Abort cooperatively when the caller cancels.
        unawaited(
          cancel.whenCancelled.then((_) {
            sub?.cancel();
            if (!controller.isClosed) controller.close();
          }),
        );

        sub = actionStream.listen(
          (chunk) {
            if (!controller.isClosed) controller.add(chunk);
          },
          onError: (Object e, StackTrace s) {
            if (!controller.isClosed) controller.addError(e, s);
          },
        );

        try {
          final output = await actionStream.onResult;
          if (!outputCompleter.isCompleted) outputCompleter.complete(output);
        } catch (e, s) {
          if (!outputCompleter.isCompleted) {
            outputCompleter.completeError(e, s);
          }
        }
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
        if (!outputCompleter.isCompleted) {
          outputCompleter.completeError(e, s);
        }
      } finally {
        await sub?.cancel();
        if (!controller.isClosed) await controller.close();
      }
    }();

    return (stream: controller.stream, output: outputCompleter.future);
  }

  @override
  Future<AgentOutput>? run(
    AgentInput input,
    AgentInit init, {
    required CancellationToken cancel,
  }) {
    // Opt out of the non-streaming fast path: `send()` should always run the
    // turn over the streaming transport and drain the stream so a server-managed
    // agent's `customPatch` chunks are applied to the chat's tracked state. The
    // turn output is still available via [runTurn]'s `output` future.
    return null;
  }

  @override
  Future<SessionSnapshot?> getSnapshot({
    String? snapshotId,
    String? sessionId,
  }) async {
    final headers = await _resolveHeaders();
    final lookup = <String, dynamic>{
      'snapshotId': ?snapshotId,
      'sessionId': ?sessionId,
    };
    return _snapshotAction.call(input: lookup, headers: headers);
  }

  @override
  Future<String?> abort(String snapshotId) async {
    final headers = await _resolveHeaders();
    final response = await _abortAction.call(
      input: AgentAbortRequest(snapshotId: snapshotId),
      headers: headers,
    );
    return response.status?.value;
  }
}
