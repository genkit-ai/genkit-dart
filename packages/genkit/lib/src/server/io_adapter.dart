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

import 'dart:io';

import '../core/action.dart';
import 'action_handler.dart';
import 'http.dart';

/// Serves a single [action] as a `dart:io` request handler, the `dart:io`
/// counterpart of Go's `genkit.Handler`.
///
/// ```dart
/// final handleHello = ioHandler(helloFlow, contextProvider: bearerAuth);
///
/// await for (final request in server) {
///   if (request.uri.path == '/hello') {
///     await handleHello(request);
///   }
/// }
/// ```
///
/// The handler answers every request it gets (non-POST requests with `405`);
/// routing is up to the caller. See `GenkitRouter` to serve several actions.
///
/// See [actionHandler] for [sendLegacyErrorFrame]. It is independent of any
/// `GenkitRouter`'s setting, so match it if you use both.
Future<void> Function(HttpRequest request) ioHandler(
  Action action, {
  ContextProvider? contextProvider,
  bool sendLegacyErrorFrame = false,
}) {
  final handler = actionHandler(
    action,
    contextProvider: contextProvider,
    sendLegacyErrorFrame: sendLegacyErrorFrame,
  );
  return (HttpRequest request) async {
    final response = await handler(
      toGenkitHttpRequest(request, path: request.uri.path),
    );
    await writeHttpResponse(response, request.response);
  };
}

/// Wraps a `dart:io` [request] as a [GenkitHttpRequest] with the given
/// (mount-relative) [path].
GenkitHttpRequest toGenkitHttpRequest(
  HttpRequest request, {
  required String path,
}) {
  final headers = <String, String>{};
  request.headers.forEach((name, values) => headers[name] = values.join(', '));
  return GenkitHttpRequest(
    method: request.method,
    path: path,
    headers: headers,
    queryParameters: request.uri.queryParameters,
    body: request,
  );
}

/// Writes [response] to [out] and closes it.
///
/// Output is unbuffered so streamed chunks reach the client as the action
/// produces them.
Future<void> writeHttpResponse(
  GenkitHttpResponse response,
  HttpResponse out,
) async {
  out
    ..bufferOutput = false
    ..statusCode = response.statusCode;
  response.headers.forEach(out.headers.set);
  try {
    await out.addStream(response.body);
  } finally {
    await out.close();
  }
}
