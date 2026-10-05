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

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'wire_harness.dart';

void main() {
  setUpAll(setUpFirebaseApp);

  test('generate sends contents on the wire and parses the canned '
      'response', () async {
    final client = WireClient(response: textResponse('hi there'));
    final model = wireModel(client);

    final response = await model(userRequest('hello'));

    final request = client.requests.single;
    expect(request.isStreaming, isFalse);
    expect(
      request.url.path,
      endsWith('/models/gemini-2.5-flash:generateContent'),
    );
    expect(request.headers['x-goog-api-key'], Firebase.app().options.apiKey);
    expect(request.body['contents'], [
      {
        'role': 'user',
        'parts': [containsPair('text', 'hello')],
      },
    ]);
    expect(response.message?.text, 'hi there');
    expect(response.finishReason, FinishReason.stop);
  });

  test('streaming generate yields each SSE chunk and aggregates the '
      'final message', () async {
    final client = WireClient(
      streamChunks: [
        textResponse('Hello, ', finishReason: null),
        textResponse('world'),
      ],
    );
    final model = wireModel(client);
    final chunks = <ModelResponseChunk>[];

    final response = await model(userRequest('hello'), onChunk: chunks.add);

    final request = client.requests.single;
    expect(request.isStreaming, isTrue);
    expect(request.url.queryParameters['alt'], 'sse');
    expect(chunks.map((c) => c.text), ['Hello, ', 'world']);
    expect(response.message?.text, 'Hello, world');
  });
}
