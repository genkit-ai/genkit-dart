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

import 'package:genkit_openai/src/known_models.dart';
import 'package:genkit_openai/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('modelInfoFor', () {
    test('curated model carries its label, versions and stage', () {
      final info = modelInfoFor('gpt-5.5');

      expect(info.label, 'OpenAI GPT-5.5');
      expect(info.stage, 'stable');
      expect(info.versions, contains('gpt-5.5-2026-04-23'));
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

    test('an uncurated o-series model is described as reasoning', () {
      final info = modelInfoFor('o5-mini');

      expect(info.supports?['systemRole'], false);
      expect(info.supports?['tools'], true);
      expect(info.supports?['media'], true);
    });

    test('every curated model claims constrained generation', () {
      // The models that predated structured outputs have all shut down.
      for (final id in knownChatModels) {
        expect(modelInfoFor(id).supports?['constrained'], isTrue, reason: id);
      }
    });

    test('a dated snapshot resolves to its curated alias', () {
      // Listed in the catalog's own versions.
      expect(modelInfoFor('gpt-4o-2024-08-06').label, 'OpenAI GPT-4o');
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

    test('models carry their stage', () {
      expect(modelInfoFor('gpt-5.5').stage, 'stable');
      expect(modelInfoFor('gpt-4o').stage, 'deprecated');
      expect(modelInfoFor('o3').stage, 'deprecated');
      // Shut down and removed, so there is no stage to carry.
      expect(modelInfoFor('gpt-4').stage, isNull);
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
      expect(supportsVision('gpt-4o-2024-08-06'), true);
      expect(supportsVision('o3'), true);
      expect(supportsVision('gpt-6-astra'), true);
      expect(supportsVision('chatgpt-5.6-latest'), true);
      // Uncurated chat names take the multimodal defaults.
      expect(supportsVision('gpt-5o'), true);
      expect(supportsVision('gpt-6o-mini'), true);
    });

    test('identifies models without image input', () {
      // The text-only chat models have all shut down; what remains is the
      // modalities this plugin does not serve as chat.
      expect(supportsVision('text-embedding-3-small'), false);
      expect(supportsVision('tts-1'), false);
      expect(supportsVision('whisper-1'), false);
    });
  });

  group('supportsTools', () {
    test('identifies models with function calling support', () {
      expect(supportsTools('gpt-4o'), true);
      expect(supportsTools('gpt-4o-mini'), true);
      expect(supportsTools('gpt-5'), true);
      expect(supportsTools('gpt-5.1'), true);
      expect(supportsTools('gpt-5.6-terra'), true);
      expect(supportsTools('o3'), true);
      expect(supportsTools('gpt-6-sol'), true);
      expect(supportsTools('gpt-6-luna'), true);
    });

    test('identifies models without function calling support', () {
      // Chat Completions takes their tools only on the Responses API.
      expect(supportsTools('gpt-6-astra'), false);
      expect(supportsTools('gpt-6.1-sol'), false);
      expect(supportsTools('gpt-6.1-terra'), false);
      // ChatGPT-tuned snapshots do not take tools.
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

    test('classifies search models as chat', () {
      expect(getModelType('gpt-5-search-api'), 'chat');
      expect(getModelType('gpt-5-search-api-2025-10-14'), 'chat');
    });

    test('keeps realtime and live models off the audio paths', () {
      for (final id in [
        'gpt-realtime',
        'gpt-realtime-whisper',
        'gpt-live-1',
        'gpt-live-transcribe',
      ]) {
        expect(getModelType(id), 'realtime', reason: id);
      }
    });

    test(
      'classifies legacy base models and their fine-tunes as completion',
      () {
        for (final id in [
          'davinci-002',
          'babbage-002',
          'ada',
          'curie:ft-acme-2023-06-07-10-19-42',
          'ada:ft-acme-2023-01-01-00-00-00',
        ]) {
          expect(getModelType(id), 'completion', reason: id);
        }
        expect(getModelType('adapter-7b'), 'unknown');
      },
    );

    test('classifies embedders a compat host spells without -ing', () {
      expect(getModelType('text-embedding-3-small'), 'embedding');
      expect(getModelType('nomic-embed-text'), 'embedding');
      expect(getModelType('mxbai-embed-large'), 'embedding');
    });

    test('returns unknown for unrecognized models', () {
      expect(getModelType('my-custom-model'), 'unknown');
      // Matching on `embed` misses a name that carries neither spelling.
      expect(getModelType('bge-m3'), 'unknown');
    });
  });
}
