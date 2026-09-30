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

import 'package:shelf/shelf.dart';

/// CORS settings for `GenkitRouter.serve`.
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

/// Shelf middleware applying [options]; answers preflight `OPTIONS` itself.
Middleware corsMiddleware(CorsOptions options) {
  final allowAny = options.allowedOrigins.contains('*');

  Map<String, String> headersFor(Request request) {
    final origin = request.headers['origin'];
    final String allowOrigin;
    if (allowAny) {
      allowOrigin = '*';
    } else if (origin != null && options.allowedOrigins.contains(origin)) {
      allowOrigin = origin;
    } else {
      return const {};
    }
    return {
      'Access-Control-Allow-Origin': allowOrigin,
      // The response depends on the request origin, so caches must key on it.
      if (!allowAny) 'Vary': 'Origin',
      if (options.exposedHeaders.isNotEmpty)
        'Access-Control-Expose-Headers': options.exposedHeaders.join(', '),
    };
  }

  return (inner) => (request) async {
    final headers = headersFor(request);
    if (request.method == 'OPTIONS') {
      return Response(
        HttpStatus.noContent,
        headers: {
          ...headers,
          if (headers.isNotEmpty) ...{
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            if (options.allowedHeaders.isNotEmpty)
              'Access-Control-Allow-Headers': options.allowedHeaders.join(', '),
          },
        },
      );
    }
    final response = await inner(request);
    if (headers.isEmpty) return response;
    // `change` replaces headers by name, so append to an existing `Vary` (e.g.
    // `Accept-Encoding` from compression middleware) instead of clobbering it.
    final existingVary = response.headers['vary'];
    final vary = headers['Vary'];
    // `change` keeps the response context, so streaming responses stay
    // unbuffered.
    return response.change(
      headers: {
        ...headers,
        if (vary != null && existingVary != null)
          'Vary': _appendVary(existingVary, vary),
      },
    );
  };
}

String _appendVary(String existing, String value) {
  final names = existing.split(',').map((v) => v.trim().toLowerCase());
  if (names.contains('*') || names.contains(value.toLowerCase())) {
    return existing;
  }
  return '$existing, $value';
}
