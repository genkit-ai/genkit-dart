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

/// Wire-level test harness for the Firebase AI plugin.
///
/// Requests run through the real plugin and the real `firebase_ai`
/// `GenerativeModel`; only the HTTP transport is replaced by [WireClient].
/// The [fcore.FirebaseApp] is backed by `firebase_core`'s platform mocks, so
/// App Check and Auth are never registered and their headers are never sent.
/// Live (bidi) models use a WebSocket and are out of reach of this harness.
library;

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' as fcore;
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:http/http.dart' as http;

// TODO(#366): consolidate with the shared wire harness once it lands.

/// A request [WireClient] received.
class CapturedRequest {
  CapturedRequest(this.url, this.headers, this.body);

  /// The full request URL, including any `alt=sse` query parameter.
  final Uri url;

  /// The request headers as sent.
  final Map<String, String> headers;

  /// The decoded JSON request body.
  final Map<String, dynamic> body;

  /// Whether this was a `streamGenerateContent` request.
  bool get isStreaming => url.path.endsWith(':streamGenerateContent');
}

/// A fake `http.Client` that records every request and serves canned
/// `GenerateContentResponse` JSON.
///
/// Non-streaming requests get [response]. Streaming requests get each entry
/// of [streamChunks] as one SSE `data:` line, unless [statusCode] is not 200,
/// in which case they also get [response], as the real API does for errors.
class WireClient extends http.BaseClient {
  WireClient({
    Map<String, dynamic>? response,
    List<Map<String, dynamic>>? streamChunks,
    this.statusCode = 200,
  }) : response = response ?? textResponse('ok'),
       streamChunks = streamChunks ?? [textResponse('ok')];

  /// Body returned for `generateContent`.
  final Map<String, dynamic> response;

  /// Chunks returned, in order, for `streamGenerateContent`.
  final List<Map<String, dynamic>> streamChunks;

  /// HTTP status returned for every request.
  final int statusCode;

  /// Requests seen so far, oldest first.
  final List<CapturedRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    final captured = CapturedRequest(
      request.url,
      Map.of(request.headers),
      (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>(),
    );
    requests.add(captured);

    if (captured.isStreaming && statusCode == 200) {
      final sse = streamChunks.map((c) => 'data: ${jsonEncode(c)}\r\n\r\n');
      return http.StreamedResponse(
        Stream.fromIterable(sse.map(utf8.encode)),
        statusCode,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    if (captured.isStreaming ||
        captured.url.path.endsWith(':generateContent')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(response))),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }
    throw StateError('Unexpected request: ${request.url}');
  }
}

/// A single-candidate `GenerateContentResponse` whose only part is [text].
Map<String, dynamic> textResponse(
  String text, {
  String? finishReason = 'STOP',
}) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': ?finishReason,
    },
  ],
};

/// Initializes a mocked default [fcore.FirebaseApp].
///
/// Call from `setUpAll`; `firebase_ai` reads the app's options to build the
/// request URL and API key header.
Future<void> setUpFirebaseApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  await fcore.Firebase.initializeApp();
}

/// The plugin's [Model] for [modelName], with all HTTP sent to [client].
Model wireModel(
  WireClient client, {
  String modelName = 'gemini-2.5-flash',
  FirebaseAiProvider provider = const FirebaseAiProvider.googleAI(),
}) {
  final plugin = firebaseAI(httpClient: client, provider: provider);
  return plugin.resolve(.model, modelName)! as Model;
}

/// A single user-turn [ModelRequest] with [text].
ModelRequest userRequest(String text, {Map<String, dynamic>? config}) =>
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: text)],
        ),
      ],
      config: config,
    );
