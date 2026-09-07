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

/// A stand-in for an OpenAI-compatible host, ported from the JS plugin's
/// `tests/fake_openai_server.ts`.
///
/// This binds a real socket rather than injecting a `MockClient` because the
/// compat path is precisely the part a mock cannot vouch for: every other test
/// in this package hands the plugin an `httpClient`, so the client the plugin
/// builds for itself - the one real users get, and the only thing that turns
/// `baseUrl` into an actual connection - is never exercised. Pointing the
/// plugin at `server.baseUrl` with no `httpClient` proves the URL is dialed,
/// the auth and custom headers survive the SDK's interceptor chain, and SSE is
/// parsed off a genuinely chunked socket.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request as the fake host saw it.
class RecordedRequest {
  /// HTTP method, e.g. `POST`.
  final String method;

  /// Request path, e.g. `/v1/chat/completions`.
  final String path;

  /// Request headers, lower-cased by `dart:io`.
  final Map<String, String> headers;

  /// The raw request body.
  final String rawBody;

  RecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
    required this.rawBody,
  });

  /// The body decoded as JSON, or an empty map when there was no body.
  Map<String, dynamic> get body => rawBody.isEmpty
      ? const {}
      : (jsonDecode(rawBody) as Map).cast<String, dynamic>();

  @override
  String toString() => '$method $path';
}

/// A canned reply for the fake host to serve.
class FakeResponse {
  /// HTTP status to write.
  final int statusCode;

  /// JSON-encodable body, for non-streaming replies.
  final Object? body;

  /// Extra response headers.
  final Map<String, String> headers;

  /// Whether to serve this reply as an SSE stream.
  final bool stream;

  /// SSE payloads, each written as one `data:` frame, followed by `[DONE]`.
  final List<Object>? chunks;

  /// Verbatim SSE frames, for wire shapes [chunks] cannot express. No `[DONE]`
  /// frame is appended.
  final List<String>? rawSse;

  const FakeResponse({
    this.statusCode = 200,
    this.body,
    this.headers = const {},
    this.stream = false,
    this.chunks,
    this.rawSse,
  });

  /// A JSON reply with the given [body] and [statusCode].
  const FakeResponse.json(Object body, {int statusCode = 200})
    : this(body: body, statusCode: statusCode);

  /// An OpenAI-style error reply, as a compatible host returns on failure.
  factory FakeResponse.error(int statusCode, String message) {
    return FakeResponse(
      statusCode: statusCode,
      body: {
        'error': {'message': message, 'type': 'invalid_request_error'},
      },
    );
  }

  /// An SSE reply built from [chunks].
  const FakeResponse.sse(List<Object> chunks)
    : this(stream: true, chunks: chunks);
}

/// An OpenAI-compatible host backed by a real [HttpServer] on an ephemeral
/// port.
///
/// Queued replies are served in order; once the queue drains, a path-aware
/// default keeps tests that do not care about the response body short. When
/// `expectedApiKey` is set, any request without a matching bearer token gets
/// the same 401 shape OpenAI returns.
class FakeOpenAIServer {
  FakeOpenAIServer._(this._server, this._expectedApiKey) {
    unawaited(_serve());
  }

  final HttpServer _server;
  final String? _expectedApiKey;
  final List<FakeResponse> _queued = [];

  /// Every request the host received, in order.
  final List<RecordedRequest> requests = [];

  /// Anything thrown while serving a request.
  ///
  /// A handler that dies leaves the client staring at a closed socket, which
  /// surfaces in the test as an opaque transport error a long way from the
  /// cause. These are printed as they happen so the real reason is on screen.
  final List<Object> handlerErrors = [];

  /// Binds a fake host on an ephemeral loopback port.
  ///
  /// Pass [expectedApiKey] to have the host reject any other bearer token with
  /// a 401, the way a real provider would.
  static Future<FakeOpenAIServer> start({String? expectedApiKey}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeOpenAIServer._(server, expectedApiKey);
  }

  /// The base URL to hand the plugin, including the `/v1` prefix that
  /// OpenAI-compatible hosts conventionally serve under.
  String get baseUrl => 'http://127.0.0.1:${_server.port}/v1';

  /// Queues [response] to be served to the next request.
  void enqueue(FakeResponse response) => _queued.add(response);

  /// Stops the host, dropping any in-flight connections.
  Future<void> stop() => _server.close(force: true);

  /// The bodies of every chat-completions request received.
  List<Map<String, dynamic>> get chatRequestBodies => [
    for (final r in requests)
      if (r.path.endsWith('/chat/completions')) r.body,
  ];

  Future<void> _serve() async {
    await for (final request in _server) {
      try {
        await _handle(request);
      } catch (e, stackTrace) {
        // Usually the client hung up or the test ended, which is harmless. A
        // bug in this harness lands here too, so make it visible rather than
        // letting the test fail with an unexplained transport error.
        handlerErrors.add(e);
        stderr.writeln(
          'FakeOpenAIServer failed to serve a request: $e\n$stackTrace',
        );
      }
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final rawBody = await utf8.decoder.bind(request).join();
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));

    requests.add(
      RecordedRequest(
        method: request.method,
        path: request.uri.path,
        headers: headers,
        rawBody: rawBody,
      ),
    );

    final expected = _expectedApiKey;
    if (expected != null &&
        request.headers.value('authorization') != 'Bearer $expected') {
      await _writeJson(request.response, 401, {
        'error': {
          'message': 'Incorrect API key provided',
          'type': 'invalid_request_error',
          'param': null,
          'code': 'invalid_api_key',
        },
      });
      return;
    }

    final response = _queued.isNotEmpty
        ? _queued.removeAt(0)
        : _defaultFor(request.uri.path);

    if (response.stream) {
      await _writeSse(request.response, response);
    } else {
      await _writeJson(
        request.response,
        response.statusCode,
        response.body,
        extraHeaders: response.headers,
      );
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Object? body, {
    Map<String, String> extraHeaders = const {},
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    extraHeaders.forEach(response.headers.set);
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _writeSse(HttpResponse response, FakeResponse spec) async {
    response.statusCode = spec.statusCode;
    response.headers.set('content-type', 'text/event-stream');
    response.headers.set('cache-control', 'no-cache');
    spec.headers.forEach(response.headers.set);

    final rawSse = spec.rawSse;
    if (rawSse != null) {
      for (final frame in rawSse) {
        response.write(frame);
        await response.flush();
      }
      await response.close();
      return;
    }

    for (final chunk in spec.chunks ?? const []) {
      response.write('data: ${jsonEncode(chunk)}\n\n');
      await response.flush();
    }
    response.write('data: [DONE]\n\n');
    await response.close();
  }

  FakeResponse _defaultFor(String path) {
    if (path.endsWith('/models')) return FakeResponse.json(modelList(const []));
    return FakeResponse.json(chatCompletion(content: 'default response'));
  }
}

/// Builds a `chat.completion` body, the shape a compatible host must return.
Map<String, dynamic> chatCompletion({
  String content = 'ok',
  String model = 'test-model',
  String finishReason = 'stop',
  List<Map<String, dynamic>>? toolCalls,
  Map<String, dynamic>? usage,
}) {
  return {
    'id': 'chatcmpl-fake',
    'object': 'chat.completion',
    'created': 0,
    'model': model,
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': content,
          'tool_calls': ?toolCalls,
        },
        'finish_reason': finishReason,
      },
    ],
    'usage': ?usage,
  };
}

/// Builds one `chat.completion.chunk` frame for [FakeResponse.sse].
Map<String, dynamic> chatChunk({
  String? content,
  String model = 'test-model',
  String? finishReason,
}) {
  return {
    'id': 'chatcmpl-fake',
    'object': 'chat.completion.chunk',
    'created': 0,
    'model': model,
    'choices': [
      {
        'index': 0,
        'delta': {'content': ?content},
        'finish_reason': finishReason,
      },
    ],
  };
}

/// Builds a `GET /models` listing over [ids].
Map<String, dynamic> modelList(List<String> ids) {
  return {
    'object': 'list',
    'data': [
      for (final id in ids)
        {'id': id, 'object': 'model', 'created': 0, 'owned_by': 'fake'},
    ],
  };
}
