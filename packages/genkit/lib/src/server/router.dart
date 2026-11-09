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

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import '../core/action.dart';
import 'action_handler.dart';
import 'cors.dart';
import 'http.dart';
import 'io_adapter.dart';

final _logger = Logger('genkit.server');

/// Serves a set of Genkit actions over HTTP.
///
/// Register actions with [addAction] (and agents with `addAgent` from
/// `package:genkit/experimental_io.dart`), then plug the router into a server:
///
/// ```dart
/// final genkit = GenkitRouter()
///   ..addAction(helloFlow)
///   ..addAction(secureFlow, contextProvider: bearerAuth);
///
/// // Standalone server:
/// await genkit.serve();
///
/// // Or inside your own dart:io server:
/// await for (final request in server) {
///   if (await genkit.handleHttpRequest(request, basePath: '/api')) continue;
///   // ... your own routes
/// }
/// ```
///
/// Other frameworks go through [handle] (`package:genkit_shelf` does this for
/// shelf).
///
/// Every route is a POST that speaks the Genkit client protocol (see
/// [actionHandler]), so `defineRemoteAction`, `defineRemoteModel` and
/// `remoteAgent` from `package:genkit/client.dart` can call it.
final class GenkitRouter {
  /// Creates an empty router.
  ///
  /// [sendLegacyErrorFrame] applies to every route, however the router is
  /// served (see `actionHandler` for when you need it). Single-action builders
  /// (`ioHandler`, `shelfHandler`) take their own flag, so match it there if
  /// you use both.
  GenkitRouter({this.sendLegacyErrorFrame = false});

  /// Whether failed streams end with the legacy `error:` frame that Dart
  /// clients from `package:genkit` 0.17 and earlier understand.
  final bool sendLegacyErrorFrame;

  // Exact-match lookup rather than a pattern router: action names may contain
  // '/' (e.g. `googleai/gemini-flash-latest`) or characters that routing
  // packages treat as pattern syntax.
  final _routes = <String, GenkitHttpHandler>{};

  /// Serves [action] at POST [path], which defaults to `'/${action.name}'`.
  ///
  /// [contextProvider] builds the action context from the request (typically
  /// from auth headers); throwing from it rejects the request.
  ///
  /// Paths match exactly, so `/hello` and `/hello/` would be different routes.
  /// To avoid that trap, a trailing `/` is rejected (except for `/` itself).
  ///
  /// Throws an [ArgumentError] if [path] doesn't start with `/`, ends with
  /// `/`, or is already registered on this router.
  void addAction(
    Action action, {
    String? path,
    ContextProvider? contextProvider,
  }) {
    addRoutes(this, [
      (action: action, path: path ?? '/${action.name}'),
    ], contextProvider: contextProvider);
  }

  /// Handles a framework-neutral [request], matching [GenkitHttpRequest.path]
  /// (decoded) exactly against the registered routes.
  ///
  /// Returns null when no route matches, so framework adapters can fall
  /// through to their own routing (or answer `404`).
  Future<GenkitHttpResponse?> handle(GenkitHttpRequest request) async {
    final handler = _routes[request.path];
    if (handler == null) return null;
    return handler(request);
  }

  /// Handles a `dart:io` [request] if it targets one of the registered
  /// routes, and returns whether it did.
  ///
  /// Routes are matched below [basePath] (e.g. `/api`, so `/api/myFlow` hits
  /// the `/myFlow` route). When this returns false the request is untouched,
  /// so you can route it elsewhere:
  ///
  /// ```dart
  /// await for (final request in server) {
  ///   if (await genkit.handleHttpRequest(request, basePath: '/api')) continue;
  ///   request.response
  ///     ..statusCode = HttpStatus.notFound
  ///     ..close();
  /// }
  /// ```
  ///
  /// [cors] enables CORS handling (including preflight `OPTIONS`) for the
  /// routes of this router.
  ///
  /// Throws an [ArgumentError] if [basePath] is not empty and doesn't start
  /// with `/` or ends with `/`.
  Future<bool> handleHttpRequest(
    HttpRequest request, {
    String basePath = '',
    CorsOptions? cors,
  }) async {
    if (basePath.isNotEmpty &&
        (!basePath.startsWith('/') || basePath.endsWith('/'))) {
      throw ArgumentError.value(
        basePath,
        'basePath',
        "must be empty, or start with '/' and not end with '/'",
      );
    }
    // Route keys are raw action names, so match on the decoded path (e.g.
    // `googleai%2Fgemini-flash-latest`). A bad escape can't name a route.
    final fullPath = decodeRequestPath(request.uri.path);
    if (fullPath == null) return false;
    final String path;
    if (basePath.isEmpty) {
      path = fullPath;
    } else if (fullPath == basePath) {
      path = '/';
    } else if (fullPath.startsWith('$basePath/')) {
      path = fullPath.substring(basePath.length);
    } else {
      return false;
    }
    final handler = _routes[path];
    if (handler == null) return false;

    final genkitRequest = toGenkitHttpRequest(request, path: path);
    final response = cors == null
        ? await handler(genkitRequest)
        : await withCors(cors, genkitRequest, handler);
    await writeHttpResponse(response, request.response);
    return true;
  }

  /// Starts a standalone HTTP server for the registered routes.
  ///
  /// - [host] defaults to [InternetAddress.anyIPv4], which is what container
  ///   platforms such as Cloud Run expect. Pass
  ///   [InternetAddress.loopbackIPv4] to only accept local connections.
  /// - [port] defaults to the `PORT` environment variable, then `3400`. Pass
  ///   `0` to pick a free port (read it back from [HttpServer.port]).
  /// - [cors] enables CORS handling. When null, no CORS headers are sent and
  ///   browsers on other origins can't call the server.
  ///
  /// Unknown paths get a `404`. Routes added after the server starts are
  /// served too. Stop the server with [HttpServer.close].
  ///
  /// The bound address is logged at `INFO` on the `genkit.server` logger
  /// (`package:logging`), which prints nothing until a listener is attached:
  ///
  /// ```dart
  /// Logger.root.onRecord.listen(print);
  /// await genkit.serve(); // Genkit server listening on http://0.0.0.0:3400
  /// ```
  Future<HttpServer> serve({
    InternetAddress? host,
    int? port,
    CorsOptions? cors,
  }) async {
    final server = await HttpServer.bind(
      host ?? InternetAddress.anyIPv4,
      port ?? int.tryParse(Platform.environment['PORT'] ?? '') ?? 3400,
    );

    Future<GenkitHttpResponse> dispatch(GenkitHttpRequest request) async =>
        await handle(request) ?? _notFound();

    server.listen((request) async {
      try {
        final path = decodeRequestPath(request.uri.path);
        if (path == null) {
          await writeHttpResponse(_notFound(), request.response);
          return;
        }
        final genkitRequest = toGenkitHttpRequest(request, path: path);
        // CORS wraps the 404 too, so browser code can read it.
        final response = cors == null
            ? await dispatch(genkitRequest)
            : await withCors(cors, genkitRequest, dispatch);
        await writeHttpResponse(response, request.response);
      } catch (e, st) {
        // actionHandler turns action errors into responses, so this is a
        // transport failure (e.g. the client went away mid-response).
        _logger.warning('Failed to serve ${request.uri.path}', e, st);
      }
    });

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

/// Registers [routes] on [router] all or nothing: every path is validated
/// (see [GenkitRouter.addAction]) before any is added, so a failure leaves the
/// router unchanged.
///
/// Internal (not exported from `io.dart`); `addAgent` uses it to register an
/// agent's turn and companion routes as one unit.
void addRoutes(
  GenkitRouter router,
  List<({Action action, String path})> routes, {
  ContextProvider? contextProvider,
}) {
  final seen = <String>{};
  for (final (action: _, :path) in routes) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', "must start with '/'");
    }
    if (path.length > 1 && path.endsWith('/')) {
      throw ArgumentError.value(path, 'path', "must not end with '/'");
    }
    if (router._routes.containsKey(path) || !seen.add(path)) {
      throw ArgumentError.value(
        path,
        'path',
        'is already registered on this router',
      );
    }
  }
  for (final (:action, :path) in routes) {
    router._routes[path] = actionHandler(
      action,
      contextProvider: contextProvider,
      sendLegacyErrorFrame: router.sendLegacyErrorFrame,
    );
  }
}

/// Percent-decodes a request path (`/googleai%2Fgemini-flash-latest` to
/// `/googleai/gemini-flash-latest`), the form [GenkitHttpRequest.path] uses.
/// Returns null for a path that isn't valid percent-encoded UTF-8; no route
/// can match it, so callers answer `404`.
String? decodeRequestPath(String encodedPath) {
  try {
    return Uri.decodeComponent(encodedPath);
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

GenkitHttpResponse _notFound() => GenkitHttpResponse(
  statusCode: HttpStatus.notFound,
  headers: const {'content-type': 'text/plain'},
  body: Stream.value(utf8.encode('Not found')),
);
