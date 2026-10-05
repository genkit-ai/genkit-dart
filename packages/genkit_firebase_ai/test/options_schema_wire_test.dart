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
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';

import 'wire_harness.dart';

void main() {
  setUpAll(setUpFirebaseApp);

  test('GeminiOptions schema does not declare logprobs options', () {
    final properties =
        GeminiOptions.$schema.jsonSchema()['properties']!
            as Map<String, Object?>;

    expect(properties, isNot(contains('responseLogprobs')));
    expect(properties, isNot(contains('logprobs')));
  });

  test('GeminiOptions config is sent as generationConfig', () async {
    final client = WireClient();
    final model = wireModel(client);

    await model(
      userRequest('hello', config: {'temperature': 0.1, 'maxOutputTokens': 5}),
    );

    final generationConfig =
        client.requests.single.body['generationConfig'] as Map<String, dynamic>;
    expect(generationConfig['temperature'], 0.1);
    expect(generationConfig['maxOutputTokens'], 5);
  });
}
