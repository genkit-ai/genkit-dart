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
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

import 'wire_harness.dart';

void main() {
  setUpAll(setUpFirebaseApp);

  String projectPath() =>
      '/v1beta/projects/${Firebase.app().options.projectId}';

  test('geminiEnterprise targets the Agent Platform endpoint in the given '
      'location', () async {
    final client = WireClient();
    final model = wireModel(
      client,
      provider: const FirebaseAiProvider.geminiEnterprise(
        location: 'europe-west1',
      ),
    );

    await model(userRequest('hello'));

    expect(client.requests.single.url.host, 'firebasevertexai.googleapis.com');
    expect(
      client.requests.single.url.path,
      '${projectPath()}/locations/europe-west1/publishers/google'
      '/models/gemini-2.5-flash:generateContent',
    );
  });

  test('geminiEnterprise without a location uses global', () async {
    final client = WireClient();
    final model = wireModel(
      client,
      provider: const FirebaseAiProvider.geminiEnterprise(),
    );

    await model(userRequest('hello'));

    expect(client.requests.single.url.host, 'firebasevertexai.googleapis.com');
    expect(
      client.requests.single.url.path,
      '${projectPath()}/locations/global/publishers/google'
      '/models/gemini-2.5-flash:generateContent',
    );
  });

  test('googleAI targets the Gemini Developer API endpoint', () async {
    final client = WireClient();
    final model = wireModel(client);

    await model(userRequest('hello'));

    expect(client.requests.single.url.host, 'firebasevertexai.googleapis.com');
    expect(
      client.requests.single.url.path,
      '${projectPath()}/models/gemini-2.5-flash:generateContent',
    );
  });
}
