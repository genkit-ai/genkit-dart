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

/// Rewrites a chat-completions request body on its way out, and the reply on
/// its way back.
///
/// The last resort, and used for one thing: a field the request or response
/// types cannot express. `ChatCompletionCreateRequest.toJson()` is a closed
/// literal with no extras map, and `OpenAIClient` accepts no custom
/// interceptors, so a host that reads a shape `openai_dart` does not model —
/// DeepSeek takes a `thinking` object beside the `reasoning_effort` every host
/// reads, to say which mode the effort applies to — can only be served after
/// the SDK has encoded the body. Likewise a reply the SDK cannot parse —
/// Mistral's `content` as an array of chunks — has to be rewritten before the
/// SDK decodes it.
///
/// Both the buffered and the streaming chat calls build an `http.Request` and
/// send it through this client, so one decorator covers both.
class ChatBodyClient extends http.BaseClient {
  ChatBodyClient(this._inner, {this.rewriteRequest, this.rewriteReply});

  final http.Client _inner;

  /// Rewrites the decoded request body, or null to send it as encoded.
  final Map<String, dynamic> Function(Map<String, dynamic> body)?
  rewriteRequest;

  /// Rewrites a decoded reply - the whole completion, or each streamed chunk -
  /// or null to hand the SDK the reply as received.
  final Map<String, dynamic> Function(Map<String, dynamic> reply)? rewriteReply;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is! http.Request ||
        request.method != 'POST' ||
        !request.url.path.endsWith('/chat/completions')) {
      return _inner.send(request);
    }

    final response = await _inner.send(_rewrittenRequest(request));
    final rewrite = rewriteReply;
    // An error body is the SDK's to report as it came.
    if (rewrite == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      return response;
    }
    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/event-stream')) {
      return _withBody(response, _rewriteEvents(response.stream, rewrite));
    }
    final body = await response.stream.bytesToString();
    return _withBody(
      response,
      Stream.value(utf8.encode(_rewriteJson(body, rewrite) ?? body)),
    );
  }

  http.BaseRequest _rewrittenRequest(http.Request request) {
    final rewrite = rewriteRequest;
    if (rewrite == null) return request;

    // Only the SDK's own encoded requests reach this path, so a body that is
    // not a JSON object should be impossible - but a decorator that throws on
    // a surprise is worse than one that gets out of the way.
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(request.body);
      if (parsed is! Map) return request;
      decoded = parsed.cast<String, dynamic>();
    } on FormatException {
      return request;
    }

    final rewritten = rewrite(decoded);
    return http.Request(request.method, request.url)
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
  }

  /// [json] rewritten, or null when it is not a JSON object.
  static String? _rewriteJson(
    String json,
    Map<String, dynamic> Function(Map<String, dynamic>) rewrite,
  ) {
    try {
      final parsed = jsonDecode(json);
      if (parsed is! Map) return null;
      return jsonEncode(rewrite(parsed.cast<String, dynamic>()));
    } on FormatException {
      return null;
    }
  }

  /// Rewrites each `data:` line of an SSE stream, leaving every other line -
  /// the blank ones that end an event, `[DONE]` - as it was.
  static Stream<List<int>> _rewriteEvents(
    Stream<List<int>> events,
    Map<String, dynamic> Function(Map<String, dynamic>) rewrite,
  ) => events
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((line) {
        if (!line.startsWith('data:')) return line;
        final payload = line.substring('data:'.length).trim();
        final rewritten = _rewriteJson(payload, rewrite);
        return rewritten == null ? line : 'data: $rewritten';
      })
      .map((line) => utf8.encode('$line\n'));

  /// [response] with [body] in place of its own, and no content-length, which
  /// the rewrite has made stale.
  static http.StreamedResponse _withBody(
    http.StreamedResponse response,
    Stream<List<int>> body,
  ) => http.StreamedResponse(
    body,
    response.statusCode,
    request: response.request,
    headers: {
      for (final header in response.headers.entries)
        if (header.key.toLowerCase() != 'content-length')
          header.key: header.value,
    },
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );

  @override
  void close() => _inner.close();
}
