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

/// Headers and keys HTTP cannot carry are refused when the plugin is built,
/// naming the header and never its value.
library;

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:test/test.dart';

import 'fake_server.dart';
import 'test_types.dart';

Matcher refusedNaming(String header, {required String secret}) => throwsA(
  isA<GenkitException>()
      .having((e) => e.status, 'status', StatusCode.failedPrecondition)
      .having((e) => e.message, 'message', contains(header))
      .having((e) => e.message, 'message', isNot(contains(secret)))
      .having((e) => e.toString(), 'toString', isNot(contains(secret))),
);

void main() {
  test('a key with a control byte is refused, unquoted, before any call', () {
    final server = FakeServer();
    expect(
      () => SystemOne(
        provider: 'p',
        baseUrl: 'https://decisions.test',
        apiKey: 'sk-secret\n',
        httpClient: server.client,
      ),
      refusedNaming('the Authorization header', secret: 'sk-secret'),
    );
    expect(
      () => SystemOne.typeSafe(apiKey: 'sk-secretĀ', httpClient: server.client),
      refusedNaming('the Authorization header', secret: 'sk-secret'),
    );
    expect(server.calls, 0);
  });

  test('a header value with CR is refused, unquoted', () {
    expect(
      () => SystemOne(
        provider: 'p',
        baseUrl: 'https://decisions.test',
        headers: {'X-Tenant': 'tenant-secret\r\nInjected: 1'},
      ),
      refusedNaming('the X-Tenant header', secret: 'tenant-secret'),
    );
  });

  test('a header name that is not a token is refused', () {
    expect(
      () => SystemOne(
        provider: 'p',
        baseUrl: 'https://decisions.test',
        headers: {'bad name': 'v'},
      ),
      refusedNaming('a header cannot be sent', secret: 'bad name'),
    );
  });

  test('a transport header is refused', () {
    for (final name in ['Host', 'content-length', 'Transfer-Encoding']) {
      expect(
        () => SystemOne(
          provider: 'p',
          baseUrl: 'https://decisions.test',
          headers: {name: 'x'},
        ),
        refusedNaming('the $name header', secret: '\u0000'),
      );
    }
  });

  test('a tab in a value is allowed, and the key is sent as given', () async {
    final server = FakeServer();
    final plugin = SystemOne(
      provider: 'p',
      baseUrl: 'https://decisions.test',
      apiKey: ' key ',
      headers: {'X-Note': 'a\tb'},
      httpClient: server.client,
    );
    final ai = Genkit(isDevEnv: false, plugins: [plugin], promptDir: null);
    addTearDown(ai.shutdown);
    await ai.generate(
      model: plugin.modelRef('m'),
      prompt: 'x',
      outputSchema: Triage.$schema,
    );
    // An explicit key is not trimmed; only values read from the environment
    // are.
    expect(server.last.$1.headers['Authorization'], 'Bearer  key ');
    expect(server.last.$1.headers['X-Note'], 'a\tb');
  });

  test("a lower-case authorization header gives way to the key's", () async {
    final server = FakeServer();
    final plugin = SystemOne(
      provider: 'p',
      baseUrl: 'https://decisions.test',
      apiKey: 'key',
      headers: {'authorization': 'Basic other'},
      httpClient: server.client,
    );
    final ai = Genkit(isDevEnv: false, plugins: [plugin], promptDir: null);
    addTearDown(ai.shutdown);
    await ai.generate(
      model: plugin.modelRef('m'),
      prompt: 'x',
      outputSchema: Triage.$schema,
    );
    final headers = server.last.$1.headers;
    expect(headers['Authorization'], 'Bearer key');
    expect(
      headers.entries.where((e) => e.key.toLowerCase() == 'authorization'),
      hasLength(1),
    );
  });
}
