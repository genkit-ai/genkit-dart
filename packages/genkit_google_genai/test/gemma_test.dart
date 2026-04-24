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
import 'package:genkit/src/schema.dart' show toJsonSchema;
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/common_plugin.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('GemmaOptions schema', () {
    test('round-trips temperature at cap', () {
      final options = GemmaOptions.$schema.parse({'temperature': 1.0});
      expect(options.temperature, 1.0);
    });

    test('JSON schema caps temperature at 1.0', () {
      final schema = toJsonSchema(type: GemmaOptions.$schema);
      final defs = schema[r'$defs'] as Map<String, dynamic>;
      final gemma = defs['GemmaOptions'] as Map<String, dynamic>;
      final props = gemma['properties'] as Map<String, dynamic>;
      final temp = props['temperature'] as Map<String, dynamic>;
      expect(temp['maximum'], 1.0);
    });
  });

  group('model family predicates', () {
    test('isGemmaModelName', () {
      expect(isGemmaModelName('gemma-3-1b-it'), isTrue);
      expect(isGemmaModelName('gemma-4-31b-it'), isTrue);
      expect(isGemmaModelName('gemini-2.5-pro'), isFalse);
      expect(isGemmaModelName('text-embedding-004'), isFalse);
    });

    test('isGemma3ModelName', () {
      expect(isGemma3ModelName('gemma-3-1b-it'), isTrue);
      expect(isGemma3ModelName('gemma-3-12b-it'), isTrue);
      expect(isGemma3ModelName('gemma-3-27b-it'), isTrue);
      expect(isGemma3ModelName('gemma-3-4b-it'), isTrue);
      expect(isGemma3ModelName('gemma-3n-e4b-it'), isTrue);
      expect(isGemma3ModelName('gemma-4-31b-it'), isFalse);
      expect(isGemma3ModelName('gemini-2.5-pro'), isFalse);
    });
  });

  group('stripReasoningParts', () {
    test('drops reasoning parts', () {
      final messages = [
        Message(
          role: Role.model,
          content: [
            ReasoningPart(reasoning: 'thinking...'),
            TextPart(text: 'answer'),
          ],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.content, hasLength(1));
      expect(stripped.first.content.first.text, 'answer');
    });

    test('drops parts whose metadata carries thoughtSignature', () {
      final messages = [
        Message(
          role: Role.model,
          content: [
            TextPart(text: 'hidden', metadata: {'thoughtSignature': 'sig'}),
            TextPart(text: 'visible'),
          ],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped.first.content, hasLength(1));
      expect(stripped.first.content.first.text, 'visible');
    });

    test('drops messages that become empty', () {
      final messages = [
        Message(
          role: Role.model,
          content: [ReasoningPart(reasoning: 'only thought')],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.role, Role.user);
    });

    test('leaves non-gemma-affected parts alone', () {
      final messages = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hello')],
        ),
      ];
      final stripped = stripReasoningParts(messages);
      expect(stripped, hasLength(1));
      expect(stripped.first.content.first.text, 'hello');
    });
  });

  group('plugin handle', () {
    test('googleAI.gemma returns a ModelRef with GemmaOptions schema', () {
      final ref = googleAI.gemma('gemma-3-1b-it');
      expect(ref.name, 'googleai/gemma-3-1b-it');
      expect(ref.customOptions, same(GemmaOptions.$schema));
    });
  });

  group('GoogleGenAiPluginImpl.resolve for gemma models', () {
    Map<String, dynamic>? supportsOf(String modelName) {
      final plugin = GoogleGenAiPluginImpl();
      final action = plugin.resolve('model', modelName);
      expect(action, isNotNull);
      expect(action!.name, 'googleai/$modelName');
      final model = action.metadata['model'] as Map<String, dynamic>;
      return model['supports'] as Map<String, dynamic>?;
    }

    test('gemma-3 models advertise systemRole: false', () {
      for (final name in const [
        'gemma-3-1b-it',
        'gemma-3-4b-it',
        'gemma-3-12b-it',
        'gemma-3-27b-it',
        'gemma-3n-e4b-it',
      ]) {
        expect(supportsOf(name)?['systemRole'], isFalse, reason: name);
      }
    });

    test('gemma-4 models keep systemRole: true', () {
      expect(supportsOf('gemma-4-31b-it')?['systemRole'], isTrue);
      expect(supportsOf('gemma-4-26b-a4b-it')?['systemRole'], isTrue);
    });

    test('gemma models advertise constrained: no-tools', () {
      expect(supportsOf('gemma-3-1b-it')?['constrained'], 'no-tools');
    });
  });
}
