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

import 'dart:async';

import '../exception.dart';

/// A framework-neutral HTTP request, the input of a [GenkitHttpHandler].
///
/// Dart HTTP stacks don't share a request type (`dart:io` has `HttpRequest`,
/// shelf has `Request`, ...), so Genkit's HTTP layer speaks this minimal shape
/// and adapters translate to and from it. `GenkitRouter.handleHttpRequest`
/// and `ioHandler` are the built-in `dart:io` adapters; `package:genkit_shelf`
/// is the shelf one.
final class GenkitHttpRequest {
  GenkitHttpRequest({
    required this.method,
    required this.path,
    Map<String, String> headers = const {},
    this.queryParameters = const {},
    Stream<List<int>>? body,
  }) : headers = {
         for (final MapEntry(:key, :value) in headers.entries)
           key.toLowerCase(): value,
       },
       body = body ?? const Stream.empty();

  /// The HTTP method, e.g. `POST`.
  final String method;

  /// The request path relative to where the handler is mounted, starting with
  /// `/` (e.g. `/myFlow` for a router mounted at `/api` receiving
  /// `/api/myFlow`).
  final String path;

  /// Request headers with lowercased names. Repeated headers are joined with
  /// `, `.
  final Map<String, String> headers;

  /// Decoded query parameters.
  final Map<String, String> queryParameters;

  /// The raw request body. Can be listened to once.
  final Stream<List<int>> body;
}

/// A framework-neutral HTTP response, the output of a [GenkitHttpHandler].
///
/// Header names are lowercase. Streaming responses have no `content-length`
/// and emit [body] chunks as the action produces them, so adapters must not
/// buffer the body.
final class GenkitHttpResponse {
  GenkitHttpResponse({
    required this.statusCode,
    this.headers = const {},
    Stream<List<int>>? body,
  }) : body = body ?? const Stream.empty();

  final int statusCode;

  /// Response headers with lowercase names.
  final Map<String, String> headers;

  /// The response body. Can be listened to once.
  final Stream<List<int>> body;
}

/// Handles one [GenkitHttpRequest]. See `actionHandler`.
typedef GenkitHttpHandler =
    Future<GenkitHttpResponse> Function(GenkitHttpRequest request);

/// What a [ContextProvider] sees of the incoming request.
///
/// Deliberately framework-neutral (and shaped like `RequestData` in Genkit JS
/// and Go) so the same auth code works with `dart:io`, shelf, or any other
/// adapter.
final class RequestData {
  RequestData({
    required this.method,
    required this.headers,
    required this.input,
  });

  /// The HTTP method, e.g. `POST`.
  final String method;

  /// Request headers with lowercased names, e.g. `headers['authorization']`.
  final Map<String, String> headers;

  /// The action input from the request body, already parsed with the action's
  /// input schema (null when the body has no `data`).
  final Object? input;
}

/// Builds the action context for a request, typically from auth headers.
///
/// What it returns becomes the action context (`ctx.context` in the action).
/// Throwing rejects the request before the action runs: a [GenkitException]
/// is answered with its own status (e.g. `UNAUTHENTICATED` becomes `401`),
/// anything else with `403 PERMISSION_DENIED`.
///
/// ```dart
/// Future<Map<String, dynamic>> bearerAuth(RequestData request) async {
///   final user = await verifyToken(request.headers['authorization']);
///   if (user == null) {
///     throw GenkitException('Unauthorized', status: StatusCode.unauthenticated);
///   }
///   return {'userId': user.id};
/// }
/// ```
typedef ContextProvider =
    FutureOr<Map<String, dynamic>> Function(RequestData request);
