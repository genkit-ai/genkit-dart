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

import 'package:http/http.dart' as http;

/// Rewrites a chat-completions request body on its way out.
///
/// The last resort, and used for one thing: a field the request type cannot
/// express. `ChatCompletionCreateRequest.toJson()` is a closed literal with no
/// extras map, and `OpenAIClient` accepts no custom interceptors, so a host
/// that reads a shape `openai_dart` does not model — DeepSeek nests
/// `reasoning_effort` inside a `thinking` object where OpenAI has it at the top
/// level — can only be served after the SDK has encoded the body.
///
/// Both the buffered and the streaming chat calls build an `http.Request` and
/// send it through this client, so one decorator covers both.
class ChatBodyClient extends http.BaseClient {
  ChatBodyClient(this._inner, this._rewrite);

  final http.Client _inner;
  final Map<String, dynamic> Function(Map<String, dynamic> body) _rewrite;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request is! http.Request ||
        request.method != 'POST' ||
        !request.url.path.endsWith('/chat/completions')) {
      return _inner.send(request);
    }

    // Only the SDK's own encoded requests reach this path, so a body that is
    // not a JSON object should be impossible - but a decorator that throws on
    // a surprise is worse than one that gets out of the way.
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(request.body);
      if (parsed is! Map) return _inner.send(request);
      decoded = parsed.cast<String, dynamic>();
    } on FormatException {
      return _inner.send(request);
    }

    final rewritten = _rewrite(decoded);
    final replacement = http.Request(request.method, request.url)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      // content-length is deliberately not copied: the body setter recomputes
      // it, and a stale one would truncate the request.
      ..headers.addAll({
        for (final header in request.headers.entries)
          if (header.key.toLowerCase() != 'content-length')
            header.key: header.value,
      })
      // After the headers, so it agrees with the content-type charset just
      // copied, and before the body, which is encoded with it.
      ..encoding = request.encoding
      ..body = jsonEncode(rewritten);

    return _inner.send(replacement);
  }

  @override
  void close() => _inner.close();
}
