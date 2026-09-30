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
  return (Request request) async =>
      _toShelfResponse(await handler(_toGenkitRequest(request)));
}

/// Mounts a [GenkitRouter] into a shelf app.
extension GenkitRouterShelf on GenkitRouter {
  /// This router as a shelf [Handler].
  ///
  /// Paths are matched relative to the request's handler path, so the router
  /// can be mounted under a prefix. Unknown paths get a `404`, which lets a
  /// shelf `Cascade` fall through to the next handler.
  ///
  /// ```dart
  /// final app = Router()..mount('/api/', genkit.asShelfHandler);
  /// ```
  Handler get asShelfHandler => (Request request) async {
    final response = await handle(_toGenkitRequest(request));
    return response == null
        ? Response.notFound('Not found')
        : _toShelfResponse(response);
  };
}

GenkitHttpRequest _toGenkitRequest(Request request) => GenkitHttpRequest(
  method: request.method,
  // `url` is relative to the mount point and has no leading slash.
  path: '/${request.url.path}',
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
