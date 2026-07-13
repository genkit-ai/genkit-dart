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
import 'package:schemantic/schemantic.dart';

import '../../client/client.dart';
import '../../types.dart';
import 'agent_core.dart';

/// Resolves request headers, either statically or per request.
typedef HeadersResolver = FutureOr<Map<String, String>?> Function();

/// Creates a typed client for talking to a Genkit agent over HTTP.
///
/// - [url]: Required. The agent endpoint.
/// - [getSnapshotUrl]: Optional. Defaults to `'$url/getSnapshot'`.
/// - [abortUrl]: Optional. Defaults to `'$url/abort'`.
/// - [headers]: Optional. Static headers, or a function called per request.
/// - [stateManagement]: Optional. Declares server- vs client-managed state;
///   inferred otherwise.
/// - [stateSchema]: Optional. When provided, `chat().state` / `res.state` return
///   parsed `State` instances (e.g. a schemantic-generated class) instead of the
///   raw JSON map. When omitted, state is a bare view cast over the JSON.
/// - [httpClient]: Optional. Provide to control the HTTP client lifecycle. When
///   supplied, the client stays caller-owned and is not closed by [AgentApi.close];
///   when omitted, an internal client is created and closed by [AgentApi.close].
///
/// ```dart
/// final agent = remoteAgent(url: 'http://host/weatherAgent');
/// final chat = agent.chat();
/// final res = await chat.sendText('Weather in Tokyo?');
/// print(res.text);
/// // Release the internally-created HTTP client when done.
/// await agent.close();
/// ```
AgentApi<State> remoteAgent<State>({
  required String url,
  String? getSnapshotUrl,
  String? abortUrl,
  HeadersResolver? headers,
  AgentStateManagement? stateManagement,
  SchemanticType<State>? stateSchema,
  http.Client? httpClient,
}) => AgentApi<State>(
  _HttpAgentTransport(
    url: url,
    getSnapshotUrl: getSnapshotUrl,
    abortUrl: abortUrl,
    headers: headers,
    stateManagement: stateManagement,
    httpClient: httpClient,
  ),
  stateSchema: stateSchema,
);

class _HttpAgentTransport extends AgentTransport {
  _HttpAgentTransport({
    required String url,
    String? getSnapshotUrl,
    String? abortUrl,
    HeadersResolver? headers,
    AgentStateManagement? stateManagement,
    http.Client? httpClient,
  }) : _headers = headers,
       // Track ownership: only close a client we created. A caller-passed
       // client stays caller-owned and must not be closed by us.
       _ownsClient = httpClient == null,
       _httpClient = httpClient ?? http.Client() {
    this.stateManagement = stateManagement;

    _turnAction =
        defineRemoteAction<
          AgentInput,
          AgentOutput,
          AgentStreamChunk,
          AgentInit
        >(
          url: url,
          httpClient: _httpClient,
          outputSchema: AgentOutput.$schema,
          streamSchema: AgentStreamChunk.$schema,
        );

    _snapshotAction =
        defineRemoteAction<Map<String, dynamic>, SessionSnapshot?, void, void>(
          url: getSnapshotUrl ?? '$url/getSnapshot',
          httpClient: _httpClient,
          fromResponse: (d) => d == null
              ? null
              : SessionSnapshot.fromJson((d as Map).cast<String, dynamic>()),
          fromStreamChunk: (_) {},
        );

    _abortAction =
        defineRemoteAction<AgentAbortRequest, AgentAbortResponse, void, void>(
          url: abortUrl ?? '$url/abort',
          httpClient: _httpClient,
          fromResponse: (d) =>
              AgentAbortResponse.fromJson((d as Map).cast<String, dynamic>()),
          fromStreamChunk: (_) {},
        );
  }

  final HeadersResolver? _headers;
  final http.Client _httpClient;
  final bool _ownsClient;

  late final RemoteAction<AgentInput, AgentOutput, AgentStreamChunk, AgentInit>
  _turnAction;
  late final RemoteAction<Map<String, dynamic>, SessionSnapshot?, void, void>
  _snapshotAction;
  late final RemoteAction<AgentAbortRequest, AgentAbortResponse, void, void>
  _abortAction;

  Future<Map<String, String>?> _resolveHeaders() async {
    final headers = _headers;
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
  Future<SnapshotStatus?> abort(String snapshotId) async {
    final headers = await _resolveHeaders();
    final response = await _abortAction.call(
      input: AgentAbortRequest(snapshotId: snapshotId),
      headers: headers,
    );
    return response.status;
  }

  @override
  void close() {
    // Only close the client if we created it; a caller-passed client stays
    // caller-owned.
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}
