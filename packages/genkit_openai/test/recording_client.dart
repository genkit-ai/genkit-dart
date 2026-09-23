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

/// A `MockClient` that records what a provider plugin put on the wire.
///
/// The provider suites all ask the same question - what did the plugin send -
/// and differ only in which host they point at, so the client and the body
/// accessor live here rather than once per suite. Bodies are built by
/// `fake_openai_server.dart`, which the socket-level tests already share.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_openai_server.dart';

/// Records every request the plugin sends and answers with a canned reply.
///
/// `GET /models` answers with [modelIds]; anything else gets a chat completion
/// saying [content].
MockClient recordingClient(
  List<http.Request> requests, {
  List<String> modelIds = const [],
  String content = 'ok',
}) {
  return MockClient((request) async {
    requests.add(request);
    final body = request.url.path.endsWith('/models')
        ? modelList(modelIds)
        : chatCompletion(content: content);
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// Answers a streaming chat request with a single SSE frame.
MockClient streamingClient(List<http.Request> requests) {
  return MockClient((request) async {
    requests.add(request);
    final frame = jsonEncode(chatChunk(content: 'ok', finishReason: 'stop'));
    return http.Response(
      'data: $frame\n\ndata: [DONE]\n\n',
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
}

/// The decoded body of the first chat-completions request in [requests].
Map<String, dynamic> chatBodyOf(List<http.Request> requests) =>
    (jsonDecode(
              requests
                  .firstWhere((r) => r.url.path.endsWith('/chat/completions'))
                  .body,
            )
            as Map)
        .cast<String, dynamic>();
