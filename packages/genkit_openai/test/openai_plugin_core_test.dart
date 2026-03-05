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
  group('OpenAIOptions', () {
    test('parses temperature', () {
      final options = OpenAIOptions.$schema.parse({'temperature': 0.7});
      expect(options.temperature, 0.7);
    });

    test('parses maxTokens', () {
      final options = OpenAIOptions.$schema.parse({'maxTokens': 100});
      expect(options.maxTokens, 100);
    });

    test('parses jsonMode', () {
      final options = OpenAIOptions.$schema.parse({'jsonMode': true});
      expect(options.jsonMode, true);
    });

    test('parses stop sequences', () {
      final options = OpenAIOptions.$schema.parse({
        'stop': ['stop1', 'stop2'],
      });
      expect(options.stop, ['stop1', 'stop2']);
    });

    test('creates default options', () {
      final options = OpenAIOptions();
      expect(options.temperature, isNull);
      expect(options.maxTokens, isNull);
    });
  });

  group('Plugin Handle', () {
    test('creates plugin instance', () {
      final plugin = openAI(apiKey: 'test-key');
      expect(plugin, isNotNull);
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
