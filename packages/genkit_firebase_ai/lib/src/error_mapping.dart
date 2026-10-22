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
GenkitException toGenkitException(
  Object e,
  StackTrace stack, {
  int? httpStatus,
  String? errorStatus,
}) {
  if (e is GenkitException) return e;
  bool usable(StatusCode? s) =>
      s != null && s != StatusCode.ok && s != StatusCode.unknown;
  final fromBody = errorStatus == null
      ? null
      : StatusCode.fromWireName(errorStatus);
  final fromHttp = httpStatus == null
      ? null
      : StatusCode.fromHttpStatus(httpStatus);
  final status = switch (e) {
    _ when usable(fromBody) => fromBody!,
    _ when usable(fromHttp) => fromHttp!,
    fai.QuotaExceeded() => StatusCode.resourceExhausted,
    fai.InvalidApiKey() => StatusCode.invalidArgument,
    fai.ServiceApiNotEnabled() => StatusCode.permissionDenied,
    fai.UnsupportedUserLocation() => StatusCode.failedPrecondition,
    http.ClientException() => StatusCode.unavailable,
    WebSocketChannelException() => StatusCode.unavailable,
    _ => StatusCode.internal,
  };
  return GenkitException(
    switch (e) {
      fai.FirebaseAIException(:final message) => message,
      fai.FirebaseAISdkException(:final message) => message,
      _ => e.toString(),
    },
    status: status,
    cause: e,
    stackTrace: stack,
  );
}
