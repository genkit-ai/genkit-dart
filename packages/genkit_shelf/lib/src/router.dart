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

import 'package:genkit/genkit.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'cors.dart';
import 'handler.dart';

final _logger = Logger('genkit_shelf');

/// Serves a set of Genkit actions over HTTP.
///
/// Register actions with [addAction] (and agents with `addAgent` from
/// `package:genkit_shelf/agents.dart`), then either run it as a standalone
/// server with [serve] or mount it into an existing shelf app via [call]:
///
/// ```dart
/// final genkit = GenkitRouter()
///   ..addAction(helloFlow)
///   ..addAction(secureFlow, contextProvider: bearerAuth);
///
/// await genkit.serve();
///
/// // or, inside an existing app:
/// final app = Router()..mount('/api/', genkit.call);
/// ```
///
/// Every route is a POST that speaks the Genkit client protocol (see
/// [shelfHandler]), so `defineRemoteAction`, `defineRemoteModel` and
/// `remoteAgent` from `package:genkit/client.dart` can call it.
final class GenkitRouter {
  GenkitRouter();

  // Exact-match lookup rather than a pattern router: action names may contain
  // '/' (e.g. `googleai/gemini-flash-latest`) or characters that routing
  // packages treat as pattern syntax.
  final _routes = <String, Handler>{};

  /// Serves [action] at POST [path], which defaults to `'/${action.name}'`.
  ///
  /// [contextProvider] builds the action context from the request (typically
  /// from auth headers); throwing from it rejects the request with `403`.
  ///
  /// Throws an [ArgumentError] if [path] doesn't start with `/` or is already
  /// registered on this router.
  void addAction(
    Action action, {
    String? path,
    ContextProvider? contextProvider,
  }) {
    final routePath = path ?? '/${action.name}';
    if (!routePath.startsWith('/')) {
      throw ArgumentError.value(path, 'path', "must start with '/'");
    }
    if (_routes.containsKey(routePath)) {
      throw ArgumentError.value(
        routePath,
        'path',
        'is already registered on this router',
      );
    }
    _routes[routePath] = shelfHandler(action, contextProvider: contextProvider);
  }

  /// Handles [request], so a [GenkitRouter] can be used as a shelf [Handler].
  ///
  /// Paths are matched relative to the request's handler path, so the router
  /// can be mounted under a prefix. Unknown paths get a `404`, which lets a
  /// shelf `Cascade` fall through to the next handler.
  Future<Response> call(Request request) async {
    final handler = _routes['/${request.url.path}'];
    if (handler == null) return Response.notFound('Not found');
    return handler(request);
  }

  /// Starts an HTTP server for the registered routes.
  ///
  /// - [host] defaults to [InternetAddress.anyIPv4], which is what container
  ///   platforms such as Cloud Run expect. Pass
  ///   [InternetAddress.loopbackIPv4] to only accept local connections.
  /// - [port] defaults to the `PORT` environment variable, then `3400`. Pass
  ///   `0` to pick a free port (read it back from [HttpServer.port]).
  /// - [cors] enables CORS handling. When null, no CORS headers are sent and
  ///   browsers on other origins can't call the server.
  ///
  /// Routes added after the server starts are served too.
  Future<HttpServer> serve({
    InternetAddress? host,
    int? port,
    CorsOptions? cors,
  }) async {
    Handler handler = call;
    if (cors != null) {
      handler = const Pipeline()
          .addMiddleware(corsMiddleware(cors))
          .addHandler(handler);
    }
    final server = await io.serve(
      handler,
      host ?? InternetAddress.anyIPv4,
      port ?? int.tryParse(Platform.environment['PORT'] ?? '') ?? 3400,
    );
    _logger.info(
      'Genkit server listening on '
      'http://${server.address.address}:${server.port}',
    );
    for (final path in _routes.keys) {
      _logger.fine('  POST $path');
    }
    return server;
  }
}
