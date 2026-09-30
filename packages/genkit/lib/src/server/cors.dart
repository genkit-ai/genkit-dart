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

import 'http.dart';

/// CORS settings for `GenkitRouter.serve` and `GenkitRouter.handleHttpRequest`.
///
/// ```dart
/// await genkit.serve(
///   cors: const CorsOptions(allowedOrigins: ['https://myapp.dev']),
/// );
/// ```
final class CorsOptions {
  const CorsOptions({
    this.allowedOrigins = const ['*'],
    this.allowedHeaders = const ['Content-Type', 'Authorization'],
    this.exposedHeaders = const ['x-genkit-trace-id', 'x-genkit-span-id'],
  });

  /// Origins allowed to call the server, e.g. `https://myapp.dev`.
  ///
  /// `'*'` allows any origin. Otherwise a matching request `Origin` is echoed
  /// back, and requests from other origins get no CORS headers (so the browser
  /// blocks them).
  final List<String> allowedOrigins;

  /// Request headers browsers may send (`Access-Control-Allow-Headers`).
  final List<String> allowedHeaders;

  /// Response headers browser code may read (`Access-Control-Expose-Headers`).
  final List<String> exposedHeaders;
}

/// Applies [options] around [inner]; answers preflight `OPTIONS` itself.
Future<GenkitHttpResponse> withCors(
  CorsOptions options,
  GenkitHttpRequest request,
  GenkitHttpHandler inner,
) async {
  final allowAny = options.allowedOrigins.contains('*');
  final origin = request.headers['origin'];
  final String? allowOrigin;
  if (allowAny) {
    allowOrigin = '*';
  } else if (origin != null && options.allowedOrigins.contains(origin)) {
    allowOrigin = origin;
  } else {
    allowOrigin = null;
  }
  final headers = <String, String>{
    if (allowOrigin != null) ...{
      'access-control-allow-origin': allowOrigin,
      // The response depends on the request origin, so caches must key on it.
      if (!allowAny) 'vary': 'Origin',
      if (options.exposedHeaders.isNotEmpty)
        'access-control-expose-headers': options.exposedHeaders.join(', '),
    },
  };

  if (request.method == 'OPTIONS') {
    return GenkitHttpResponse(
      statusCode: 204,
      headers: {
        ...headers,
        if (headers.isNotEmpty) ...{
          'access-control-allow-methods': 'POST, OPTIONS',
          if (options.allowedHeaders.isNotEmpty)
            'access-control-allow-headers': options.allowedHeaders.join(', '),
        },
      },
    );
  }

  final response = await inner(request);
  if (headers.isEmpty) return response;
  final existingVary = response.headers['vary'];
  final vary = headers['vary'];
  return GenkitHttpResponse(
    statusCode: response.statusCode,
    headers: {
      ...response.headers,
      ...headers,
      // Append to an existing `Vary` (e.g. `Accept-Encoding`) instead of
      // clobbering it.
      if (vary != null && existingVary != null)
        'vary': appendVary(existingVary, vary),
    },
    body: response.body,
  );
}

/// Adds [value] to a `Vary` header value unless it's already covered.
String appendVary(String existing, String value) {
  final names = existing.split(',').map((v) => v.trim().toLowerCase());
  if (names.contains('*') || names.contains(value.toLowerCase())) {
    return existing;
  }
  return '$existing, $value';
}
