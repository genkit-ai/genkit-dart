// Copyright 2025 Google LLC
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

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:test/test.dart';

void main() {
  group('Plugin Handle', () {
    test('creates plugin instance', () {
      final plugin = openAI(apiKey: 'test-key');
      expect(plugin, isNotNull);
    });

    test('creates plugin instance with apiKeyProvider', () {
      final plugin = openAI(apiKeyProvider: () async => 'test-key');
      expect(plugin, isNotNull);
    });

    test('rejects conflicting apiKey + apiKeyProvider', () {
      expect(
        () => openAI(
          apiKey: 'openai-key',
          apiKeyProvider: () async => 'openai-key-provider',
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having(
                (e) => e.message,
                'message',
                'Provide either apiKey or apiKeyProvider, not both.',
              ),
        ),
      );
    });

    test('creates model reference', () {
      final ref = openAI.model('gpt-4o');
      expect(ref.name, 'openai/gpt-4o');
    });
  });

  group('CustomModelDefinition', () {
    test('creates with name and info', () {
      final def = CustomModelDefinition(
        name: 'custom-model',
        info: ModelInfo(label: 'Custom Model', supports: {'multiturn': true}),
      );
      expect(def.name, 'custom-model');
      expect(def.info?.label, 'Custom Model');
    });
  });
}
