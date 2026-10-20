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

import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:http/http.dart' as http;

import 'wire_harness.dart';

void main() {
  setUpAll(setUpFirebaseApp);

  group('custom httpClient', () {
    test('is used and not closed after generate', () async {
      final client = WireClient();

      await wireModel(client)(userRequest('hello'));

      expect(client.requests.single.isStreaming, isFalse);
      expect(client.closed, isFalse);
    });

    test('is used and not closed after a streamed generate', () async {
      final client = WireClient();

      await wireModel(client)(userRequest('hello'), onChunk: (_) {});

      expect(client.requests.single.isStreaming, isTrue);
      expect(client.closed, isFalse);
    });
  });

  group('default httpClient', () {
    // Routes the plugin's own `http.Client()` to the given WireClient.
    Future<ModelResponse> generate(
      WireClient client, {
      StreamingCallback<ModelResponseChunk>? onChunk,
    }) {
      final model = firebaseAI().resolve(.model, 'gemini-2.5-flash') as Model;
      return http.runWithClient(
        () => model(userRequest('hello'), onChunk: onChunk),
        () => client,
      );
    }

    test('is closed after generate', () async {
      final client = WireClient();

      await generate(client);

      expect(client.requests.single.isStreaming, isFalse);
      expect(client.closed, isTrue);
    });

    test('is closed after a streamed generate', () async {
      final client = WireClient();

      await generate(client, onChunk: (_) {});

      expect(client.requests.single.isStreaming, isTrue);
      expect(client.closed, isTrue);
    });

    test('is closed when the request fails', () async {
      final client = WireClient(
        statusCode: 500,
        response: {
          'error': {'code': 500, 'message': 'boom', 'status': 'INTERNAL'},
        },
      );

      await expectLater(generate(client), throwsA(anything));

      expect(client.requests, hasLength(1));
      expect(client.closed, isTrue);
    });

    test('is a new client per request', () async {
      final first = WireClient();
      final second = WireClient();

      await generate(first);
      await generate(second);

      expect(first.requests, hasLength(1));
      expect(second.requests, hasLength(1));
      expect(first.closed && second.closed, isTrue);
    });
  });
}
