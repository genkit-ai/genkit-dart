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
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_vertexai/genkit_vertexai.dart' show vertexAI;
import 'package:genkit_vertexai/src/known_models.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  VertexAiPluginImpl plugin({MockHttpClient? client}) => VertexAiPluginImpl(
    projectId: 'my-project',
    location: 'us-central1',
    authClient: client ?? MockHttpClient(),
  );

  Map<String, dynamic> modelInfoOf(Action action) =>
      (action.metadata['model'] as Map).cast<String, dynamic>();

  group('known model resolution', () {
    for (final MapEntry(key: id, value: curated)
        in vertexAiKnownModels.entries) {
      test('$id resolves with curated metadata', () {
        final action = plugin().resolve(.model, id);

        expect(action, isNotNull);
        final info = modelInfoOf(action!);
        expect(info['label'], curated.label);
        expect(info['stage'], curated.stage);
        expect(
          (info['supports'] as Map).cast<String, dynamic>(),
          curated.supports,
        );
      });
    }

    test('unknown model falls back to common metadata', () {
      final action = plugin().resolve(.model, 'gemini-unknown-model');

      expect(action, isNotNull);
      final info = modelInfoOf(action!);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);
      // Model defaults the label to the action name when not curated.
      expect(info['label'], 'vertexai/gemini-unknown-model');
    });

    test('un-curated Vertex -tts name resolves with the TTS profile', () {
      final action = plugin().resolve(.model, 'gemini-2.5-flash-tts') as Model;

      expect(action.customOptions, same(GeminiTtsOptions.$schema));
      final info = modelInfoOf(action);
      expect(info['supports'], {
        'multiturn': false,
        'media': false,
        'tools': false,
        'toolChoice': false,
        'systemRole': false,
        'constrained': false,
        'output': ['media'],
      });
      expect(info.containsKey('stage'), isFalse);
    });

    test('gemma is uncurated on Vertex and takes the Gemini path', () {
      final action = plugin().resolve(.model, 'gemma-4-31b-it') as Model;

      expect(action.customOptions, same(GeminiOptions.$schema));
      final info = modelInfoOf(action);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);
      expect(info['label'], 'vertexai/gemma-4-31b-it');
    });
  });

  group('vertexAiKnownModels', () {
    test('curates every Gemini family, not Gemma', () {
      expect(vertexAiKnownModels.keys, everyElement(startsWith('gemini-')));
      expect({
        for (final id in vertexAiKnownModels.keys) GeminiModelFamily.of(id),
      }, GeminiModelFamily.values.toSet());
    });

    test('keeps its own list, independent of the Gemini API catalog', () {
      // The JS vertexAI lists (KNOWN_*_MODELS and HIDDEN_MODELS). The two
      // lists change separately: models come and go differently on the two
      // endpoints.
      expect(vertexAiKnownModels.keys, {
        'gemini-4-argon',
        'gemini-4-argon-cyber-permissive',
        'gemini-3.8-flash',
        'gemini-3.8-flash-cyber',
        'gemini-3.7-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-3.1-pro-preview',
        'gemini-3.1-pro-preview-customtools',
        'gemini-3-flash-preview',
        'gemini-nano-banana-2.1',
        'gemini-3.1-flash-lite-image',
        'gemini-3.1-flash-image',
        'gemini-3-pro-image',
        'gemini-2.5-flash-image',
        'gemini-3.8-flash-tts',
        'gemini-3.8-flash-lite-tts',
        'gemini-omni-1.1-flash-preview',
        'gemini-omni-flash-preview',
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
      });
      // Left out, as in JS (shuts down Nov 19 2026).
      expect(vertexAiKnownModels, isNot(contains('gemini-3.6-flash')));
    });

    test('hidden models match the JS vertexAI HIDDEN_MODELS', () {
      final hidden = {
        for (final model in KnownVertexGeminiModel.values)
          if (model.hidden) model.id: model.stage,
      };
      expect(hidden, {
        'gemini-2.5-pro': GeminiModelStage.deprecated,
        'gemini-2.5-flash': GeminiModelStage.deprecated,
        'gemini-2.5-flash-lite': GeminiModelStage.deprecated,
      });
    });

    test('does not take googleAI stages', () {
      // Hidden on googleAI (deprecated), stable here.
      for (final id in ['gemini-3.5-flash', 'gemini-3.1-flash-image']) {
        expect(vertexAiKnownModels[id]?.stage, 'stable', reason: id);
      }
      // legacy on googleAI, deprecated here.
      expect(vertexAiKnownModels['gemini-2.5-pro']?.stage, 'deprecated');
    });

    test('gives Nano Banana 2.1 the full image profile (unlike googleAI)', () {
      // JS vertexAI keeps the default image `supports` for it; googleAI turns
      // off constrained output.
      expect(
        vertexAiKnownModels['gemini-nano-banana-2.1']?.supports,
        GeminiModelFamily.image.supports,
      );
      expect(
        knownGeminiModels['gemini-nano-banana-2.1']?.supports?['constrained'],
        isFalse,
      );
    });

    test('handles carry their family options type', () {
      expect(vertexAI.gemini('x').customOptions, same(GeminiOptions.$schema));
      expect(
        vertexAI.geminiImage('x').customOptions,
        same(GeminiImageOptions.$schema),
      );
      expect(
        vertexAI.geminiTts('x').customOptions,
        same(GeminiTtsOptions.$schema),
      );
      expect(
        vertexAI.geminiVideo('x').customOptions,
        same(GeminiVideoOptions.$schema),
      );
      expect(
        vertexAI.geminiTts('gemini-3.8-flash-tts').name,
        'vertexai/gemini-3.8-flash-tts',
      );
    });

    test('resolves curated TTS and video models with their options type', () {
      for (final (id, options) in [
        ('gemini-3.8-flash-tts', GeminiTtsOptions.$schema),
        ('gemini-omni-1.1-flash-preview', GeminiVideoOptions.$schema),
        ('gemini-nano-banana-2.1', GeminiImageOptions.$schema),
      ]) {
        final action = plugin().resolve(.model, id) as Model;
        expect(action.customOptions, same(options), reason: id);
      }
    });

    for (final model in KnownVertexGeminiModel.values) {
      test('${model.id} carries its label, stage and family profile', () {
        final info = model.info;
        expect(info.label, model.label);
        expect(info.stage, model.stage.wireName);
        expect(info.supports, model.family.supports);
        expect(GeminiModelFamily.of(model.id), model.family);
        expect(model.hidden, model.stage != GeminiModelStage.stable);
      });
    }
  });

  group('vertexUsesInteractions', () {
    test('known models pinned to generateContent match JS', () {
      expect(
        {
          for (final MapEntry(:key, :value)
              in vertexAiKnownInteractions.entries)
            if (!value) key,
        },
        {
          'gemini-3.8-flash-cyber',
          'gemini-3.5-flash',
          'gemini-3.1-flash-lite',
          'gemini-3.1-pro-preview',
          'gemini-3.1-pro-preview-customtools',
          'gemini-3-flash-preview',
          'gemini-nano-banana-2.1',
          'gemini-3.1-flash-lite-image',
          'gemini-3.1-flash-image',
          'gemini-3-pro-image',
          'gemini-2.5-flash-image',
          'gemini-3.8-flash-tts',
          'gemini-3.8-flash-lite-tts',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
        },
      );
      for (final id in vertexAiKnownInteractions.keys) {
        expect(
          vertexUsesInteractions(id),
          vertexAiKnownInteractions[id],
          reason: id,
        );
      }
    });

    test('known Interactions models and unlisted names use Interactions', () {
      for (final name in [
        'gemini-3.8-flash',
        'gemini-3.7-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.6-flash',
        'gemini-4-argon',
        'gemini-4-argon-cyber-permissive',
        'gemini-omni-1.1-flash-preview',
        'gemini-omni-flash-preview',
        'gemini-omni-2-flash',
        'gemini-future-model',
      ]) {
        expect(vertexUsesInteractions(name), isTrue, reason: name);
      }
    });

    test('unlisted image and TTS names stay on generateContent', () {
      for (final name in [
        'gemini-nano-banana-3',
        'gemini-9-flash-image',
        'gemini-9-flash-tts',
        'gemini-2.5-flash-tts',
      ]) {
        expect(vertexUsesInteractions(name), isFalse, reason: name);
      }
    });
  });

  group('list', () {
    test('gives a discovered Vertex -tts model the TTS profile', () async {
      final client = MockHttpClient(
        publisherModelsResponse:
            '{"publisherModels": ['
            '{"name": "publishers/google/models/gemini-2.5-flash-tts"}]}',
      );
      final actions = await plugin(client: client).list();
      final discovered = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-2.5-flash-tts',
      );

      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['supports'], geminiTtsSupports);
      expect(info.containsKey('stage'), isFalse);
      final options = (info['customOptions'] as Map).cast<String, dynamic>();
      expect(options['properties'], contains('speechConfig'));
    });

    test('includes curated models missing from discovery', () async {
      final client = MockHttpClient(
        publisherModelsResponse: '{"publisherModels": []}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('vertexai/gemini-2.5-pro'));
      for (final id in vertexAiKnownModels.keys) {
        expect(names, contains('vertexai/$id'));
      }

      final curated = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-3.5-flash',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test('does not duplicate curated models returned by discovery', () async {
      final client = MockHttpClient(
        publisherModelsResponse:
            '{"publisherModels": ['
            '{"name": "publishers/google/models/gemini-3.5-flash"}, '
            '{"name": "publishers/google/models/gemini-2.5-pro"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(
        names.where((n) => n == 'vertexai/gemini-3.5-flash'),
        hasLength(1),
      );

      // Discovered entry still carries the curated metadata.
      final discovered = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-3.5-flash',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test('falls back to the curated catalog when discovery fails', () async {
      final client = MockHttpClient(
        publisherModelsStatus: 500,
        publisherModelsResponse:
            '{"error": {"message": "boom", "status": "INTERNAL"}}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      for (final id in vertexAiKnownModels.keys) {
        expect(names, contains('vertexai/$id'));
      }
      // Only the curated embedders (like googleAI).
      expect(
        names.where((n) => n.contains('embedding')),
        unorderedEquals([
          for (final id in vertexAiKnownEmbedders.keys) 'vertexai/$id',
        ]),
      );
      final curated = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-3.5-flash',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test(
      'falls back to the curated catalog when the project id is invalid',
      () async {
        final client = MockHttpClient();
        final actions = await VertexAiPluginImpl(
          projectId: 'not a valid project id',
          location: 'us-central1',
          authClient: client,
        ).list();
        final names = actions.map((a) => a.name).toList();

        expect(client.requestUrls, isEmpty);
        for (final id in vertexAiKnownModels.keys) {
          expect(names, contains('vertexai/$id'));
        }
      },
    );
  });
}
