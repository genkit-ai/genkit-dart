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

import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Maps an error from `firebase_ai` or the transport to a [GenkitException].
///
/// The gRPC status in the error body wins, since several gRPC codes share an
/// HTTP status and `firebase_ai` picks its exception class from the message
/// text alone. The HTTP status comes next, then the exception class.
///
/// [errorMessage] is the `error.message` of the response body. It replaces
/// the raw body that `firebase_ai` puts in the message of a non-streaming
/// server error, and the raw body moves to [GenkitException.details].
GenkitException toGenkitException(
  Object e,
  StackTrace stack, {
  int? httpStatus,
  String? errorStatus,
  String? errorMessage,
}) {
  if (e is GenkitException) return e;
  bool usable(StatusCode? s) =>
      s != null && s != StatusCode.ok && s != StatusCode.unknown;
  final fromBody = errorStatus == null
      ? null
      : StatusCode.fromWireName(errorStatus);
  final fromHttp = switch (httpStatus ?? _handshakeStatus(e)) {
    final int code => StatusCode.fromHttpStatus(code),
    null => null,
  };
  final status = switch (e) {
    _ when usable(fromBody) => fromBody!,
    _ when usable(fromHttp) => fromHttp!,
    // The server closes a Live socket with 1007 when it rejects the session
    // setup (an unsupported config or model), which a retry would not fix.
    _ when _liveCloseCode(e) == 1007 => StatusCode.invalidArgument,
    // For these two close reasons firebase_ai replaces the whole message,
    // close code included, with its own text.
    _ when '$e'.contains(_liveSessionExpired) => StatusCode.deadlineExceeded,
    _ when '$e'.contains(_liveSessionLimit) => StatusCode.resourceExhausted,
    fai.QuotaExceeded() => StatusCode.resourceExhausted,
    fai.InvalidApiKey() => StatusCode.invalidArgument,
    fai.ServiceApiNotEnabled() => StatusCode.permissionDenied,
    fai.UnsupportedUserLocation() => StatusCode.failedPrecondition,
    http.ClientException() => StatusCode.unavailable,
    WebSocketChannelException() => StatusCode.unavailable,
    // firebase_ai could not parse the response, so a retry would fail too.
    fai.FirebaseAISdkException() => StatusCode.unknown,
    _ => StatusCode.internal,
  };
  final cause = switch (e) {
    WebSocketChannelException(:final message?)
        when _apiKeyParam.hasMatch(message) =>
      WebSocketChannelException(
        message.replaceAllMapped(_apiKeyParam, (m) => '${m[1]}<redacted>'),
      ),
    _ => e,
  };
  final rawServerError = switch (e) {
    fai.FirebaseAIException(:final message)
        when errorMessage != null && message.startsWith('Server Error [') =>
      message,
    _ => null,
  };
  return GenkitException(
    switch (e) {
      _ when rawServerError != null => errorMessage!,
      fai.FirebaseAIException(:final message) => message,
      fai.FirebaseAISdkException(:final message) => message,
      _ => cause.toString(),
    },
    status: status,
    details: rawServerError,
    cause: cause,
    stackTrace: stack,
  );
}

/// The HTTP status of a rejected live WebSocket handshake, if [e] is one.
int? _handshakeStatus(Object e) => switch (e) {
  WebSocketChannelException(:final message?) => int.tryParse(
    _handshakeHttpStatus.firstMatch(message)?[1] ?? '',
  ),
  _ => null,
};

final _handshakeHttpStatus = RegExp(r'HTTP status code: (\d+)');

/// The close code of a Live session the server closed, if [e] is one.
///
/// firebase_ai doesn't export its `LiveWebSocketClosedException`, so this
/// reads the code from the message.
int? _liveCloseCode(Object e) =>
    int.tryParse(_liveClosed.firstMatch('$e')?[1] ?? '');

final _liveClosed = RegExp(r'WebSocket Closed, closeCode: (\d+)');

/// What firebase_ai reports for a close reason with DEADLINE_EXCEEDED.
const _liveSessionExpired = 'The current live session has expired.';

/// What firebase_ai reports for a close reason with RESOURCE_EXHAUSTED.
const _liveSessionLimit = 'maximum number of concurrent sessions';

/// The live URI carries the API key as a query parameter.
final _apiKeyParam = RegExp(r'([?&]key=)[\w-]+');
