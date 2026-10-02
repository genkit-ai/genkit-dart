// Copyright 2025 Google LLC
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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:shelf/shelf.dart';

/// Serves a single [action] (flow, model, tool, ...) as a shelf [Handler].
///
/// Speaks the Genkit client protocol (see `actionHandler` in
/// `package:genkit/io.dart`). To serve a whole `GenkitRouter`, use
/// [GenkitRouterShelf.asShelfHandler].
///
/// ```dart
/// router.post('/hello', shelfHandler(helloFlow, contextProvider: bearerAuth));
/// ```
///
/// See `actionHandler` for [sendLegacyErrorFrame]. It is independent of any
/// `GenkitRouter`'s setting, so match it if you use both.
Handler shelfHandler(
  Action action, {
  ContextProvider? contextProvider,
  bool sendLegacyErrorFrame = false,
}) {
  final handler = actionHandler(
    action,
    contextProvider: contextProvider,
    sendLegacyErrorFrame: sendLegacyErrorFrame,
  );
  return (Request request) async => _toShelfResponse(
    await handler(
      // The action doesn't route on the path, so a bad escape is harmless.
      _toGenkitRequest(
        request,
        _decodedPath(request) ?? '/${request.url.path}',
      ),
    ),
  );
}

/// Mounts a [GenkitRouter] into a shelf app.
extension GenkitRouterShelf on GenkitRouter {
  /// This router as a shelf [Handler].
  ///
  /// Paths are matched relative to the request's handler path, so the router
  /// can be mounted under a prefix. Unknown paths get a `404`, which lets a
  /// shelf `Cascade` fall through to the next handler.
  ///
  /// [cors] enables CORS handling (including preflight `OPTIONS`) for this
  /// router's routes, the same as `GenkitRouter.serve(cors: ...)`.
  ///
  /// ```dart
  /// final app = Router()
  ///   ..mount('/api/', genkit.asShelfHandler(cors: const CorsOptions()));
  /// ```
  Handler asShelfHandler({CorsOptions? cors}) {
    Future<GenkitHttpResponse> dispatch(GenkitHttpRequest request) async =>
        await handle(request) ??
        GenkitHttpResponse(
          statusCode: 404,
          headers: const {'content-type': 'text/plain'},
          body: Stream.value(utf8.encode('Not found')),
        );

    return (Request request) async {
      final path = _decodedPath(request);
      // An invalid escape can't name a route.
      if (path == null) return Response.notFound('Not found');
      final genkitRequest = _toGenkitRequest(request, path);
      // CORS wraps the 404 too, so browser code can read it.
      return _toShelfResponse(
        cors == null
            ? await dispatch(genkitRequest)
            : await withCors(cors, genkitRequest, dispatch),
      );
    };
  }
}

/// The mount-relative request path, percent-decoded as
/// [GenkitHttpRequest.path] requires (routes are keyed by action names such
/// as `googleai/gemini-flash-latest`). Null for an invalid escape.
String? _decodedPath(Request request) {
  // `url` is relative to the mount point and has no leading slash.
  final encoded = '/${request.url.path}';
  try {
    return Uri.decodeComponent(encoded);
  } on FormatException {
    // Escapes that aren't valid UTF-8, e.g. `%FF`.
    return null;
    // decodeComponent reports malformed escapes (`%zz`, a trailing `%`) as
    // ArgumentError; that is bad client input here, not a programming error.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return null;
  }
}

GenkitHttpRequest _toGenkitRequest(Request request, String path) =>
    GenkitHttpRequest(
      method: request.method,
      path: path,
      headers: request.headers,
      queryParameters: request.url.queryParameters,
      body: request.read(),
    );

Response _toShelfResponse(GenkitHttpResponse response) => Response(
  response.statusCode,
  body: response.body,
  headers: response.headers,
  // Streamed chunks must reach the client as the action produces them.
  context: const {'shelf.io.buffer_output': false},
);
