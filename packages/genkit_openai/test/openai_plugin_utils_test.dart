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

import 'package:genkit_openai/genkit_openai.dart';
import 'package:test/test.dart';

void main() {
  group('modelInfoFor', () {
    test('curated model carries its label, versions and stage', () {
      final info = modelInfoFor('gpt-4o');

      expect(info.label, 'OpenAI GPT-4o');
      expect(info.stage, 'stable');
      expect(info.versions, contains('gpt-4o-2024-08-06'));
      expect(info.supports, multimodalSupports);
    });

    // Advisory metadata only: nothing in genkit core reads `systemRole`, and
    // the converter still puts a `system` message on the wire.
    test('reasoning models do not advertise a system role', () {
      final info = modelInfoFor('o3');

      expect(info.supports?['systemRole'], false);
      expect(info.supports?['tools'], true);
      expect(info.supports?['media'], true);
    });

    test('o3-mini is text-only', () {
      final info = modelInfoFor('o3-mini');

      expect(info.supports?['systemRole'], false);
      expect(info.supports?['tools'], true);
      expect(info.supports?['media'], false);
    });

    test('models predating structured outputs claim no constrained', () {
      expect(modelInfoFor('gpt-4o').supports, contains('constrained'));
      expect(
        modelInfoFor('gpt-4-turbo').supports?.containsKey('constrained'),
        isFalse,
      );
      expect(
        modelInfoFor('gpt-3.5-turbo').supports?.containsKey('constrained'),
        isFalse,
      );
    });

    test('a dated snapshot resolves to its curated alias', () {
      // Listed in the catalog's own versions.
      expect(modelInfoFor('gpt-4o-2024-05-13').label, 'OpenAI GPT-4o');
      // Not listed: matched by stripping the dated suffix, so a snapshot
      // released after this version of the plugin still lands on its alias.
      expect(
        modelInfoFor('gpt-5.6-sol-2026-06-01').label,
        'OpenAI GPT-5.6 Sol',
      );
    });

    test('lookup is case-insensitive', () {
      expect(modelInfoFor('GPT-4O').label, 'OpenAI GPT-4o');
    });

    test('an uncurated chat model takes the multimodal defaults', () {
      final info = modelInfoFor('gpt-9-turbo');

      expect(info.label, isNull);
      expect(info.stage, isNull);
      expect(info.supports, multimodalSupports);
    });

    test('an uncurated non-chat model claims no chat capabilities', () {
      expect(modelInfoFor('text-embedding-3-small').supports, nonChatSupports);
      expect(modelInfoFor('whisper-1').supports, nonChatSupports);
    });

    test('an uncurated ChatGPT-tuned snapshot withholds tools', () {
      expect(modelInfoFor('chatgpt-5.6-latest').supports?['tools'], false);
      expect(modelInfoFor('chatgpt-5.6-latest').supports?['media'], true);
    });

    test('retired models keep their stage', () {
      expect(modelInfoFor('gpt-4o').stage, 'stable');
      expect(modelInfoFor('gpt-4').stage, 'legacy');
      expect(modelInfoFor('o1-preview').stage, 'deprecated');
      expect(modelInfoFor('gpt-4.5').stage, 'deprecated');
    });

    test('curated metadata is not mutable through the returned info', () {
      expect(
        () => modelInfoFor('gpt-4o').supports!['tools'] = false,
        throwsUnsupportedError,
      );
    });
  });

  group('supportsVision', () {
    test('identifies vision models', () {
      expect(supportsVision('gpt-4o'), true);
      expect(supportsVision('gpt-4o-mini'), true);
      expect(supportsVision('gpt-4o-2024-05-13'), true);
      expect(supportsVision('gpt-4-turbo'), true);
      expect(supportsVision('gpt-4-1106-preview'), true);
      expect(supportsVision('gpt-4-0125-preview'), true);
      expect(supportsVision('gpt-4-vision'), true);
      expect(supportsVision('gpt-4-vision-preview'), true);
      expect(supportsVision('o1'), true);
      expect(supportsVision('o3'), true);
      expect(supportsVision('chatgpt-4o-latest'), true);
      // Uncurated chat names take the multimodal defaults.
      expect(supportsVision('gpt-5o'), true);
      expect(supportsVision('gpt-6o-mini'), true);
    });

    test('identifies text-only models', () {
      expect(supportsVision('o1-mini'), false);
      expect(supportsVision('o1-preview'), false);
      expect(supportsVision('o3-mini'), false);
      expect(supportsVision('gpt-3.5-turbo'), false);
      expect(supportsVision('gpt-4'), false);
      expect(supportsVision('text-embedding-3-small'), false);
      // Undated snapshots, which the alias regex cannot reach: they resolve
      // only because the catalog lists them.
      expect(supportsVision('gpt-3.5-turbo-16k'), false);
      expect(supportsVision('gpt-3.5-turbo-0613'), false);
      expect(supportsVision('gpt-4-0314'), false);
      expect(supportsVision('gpt-4-32k-0314'), false);
      // Azure spells gpt-3.5-turbo without the dot, snapshots included.
      expect(supportsVision('gpt-35-turbo'), false);
      expect(supportsVision('gpt-35-turbo-16k'), false);
      expect(supportsVision('gpt-35-turbo-0125'), false);
      expect(supportsVision('gpt-35-turbo-16k-0613'), false);
    });
  });

  group('supportsTools', () {
    test('identifies models with function calling support', () {
      expect(supportsTools('gpt-4'), true);
      expect(supportsTools('gpt-4o'), true);
      expect(supportsTools('gpt-4o-mini'), true);
      expect(supportsTools('gpt-4-turbo'), true);
      expect(supportsTools('gpt-3.5-turbo'), true);
      expect(supportsTools('gpt-5'), true);
      expect(supportsTools('gpt-5.1'), true);
      expect(supportsTools('o1'), true);
      expect(supportsTools('o3-mini'), true);
    });

    test('identifies models without function calling support', () {
      // o1-mini and o1-preview never had function calling.
      expect(supportsTools('o1-mini'), false);
      expect(supportsTools('o1-preview'), false);
      // ChatGPT-tuned snapshots do not take tools, curated or not.
      expect(supportsTools('chatgpt-4o-latest'), false);
      expect(supportsTools('gpt-5-chat-latest'), false);
      expect(supportsTools('chatgpt-5-latest'), false);
      expect(supportsTools('chatgpt-4.1-latest'), false);
      // Non-chat modalities, which this plugin does not serve.
      expect(supportsTools('gpt-3.5-turbo-instruct'), false);
      expect(supportsTools('davinci-002'), false);
      expect(supportsTools('babbage-002'), false);
      expect(supportsTools('text-embedding-3-small'), false);
      expect(supportsTools('text-embedding-3-large'), false);
      expect(supportsTools('tts-1'), false);
      expect(supportsTools('tts-1-hd'), false);
      expect(supportsTools('whisper-1'), false);
      expect(supportsTools('dall-e-3'), false);
      expect(supportsTools('dall-e-2'), false);
      expect(supportsTools('omni-moderation-latest'), false);
      expect(supportsTools('sora-2'), false);
    });
  });

  group('getModelType', () {
    test('classifies chat models', () {
      expect(getModelType('gpt-4o'), 'chat');
      expect(getModelType('chatgpt-4o-latest'), 'chat');
    });

    test('classifies non-chat models', () {
      expect(getModelType('dall-e-3'), 'image');
      expect(getModelType('sora-2'), 'video');
      expect(getModelType('whisper-1'), 'audio');
    });

    test('returns unknown for unrecognized models', () {
      expect(getModelType('my-custom-model'), 'unknown');
    });
  });
}
