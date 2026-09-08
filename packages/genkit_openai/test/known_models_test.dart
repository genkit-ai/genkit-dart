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

import 'package:genkit/plugin.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:test/test.dart';

import 'discovery_client.dart';

/// A plugin whose `GET /models` answers with [modelIds] and nothing else.
OpenAIPlugin pluginListing(List<String> modelIds, {String? baseUrl}) =>
    OpenAIPlugin(
      apiKey: 'test-key',
      baseUrl: baseUrl,
      httpClient: discoveryClient([], ids: modelIds),
    );

Map<String, dynamic> modelInfoOf(Action action) =>
    (action.metadata['model'] as Map).cast<String, dynamic>();

Map<String, dynamic> modelMetadataOf(ActionMetadata metadata) =>
    (metadata.metadata['model'] as Map).cast<String, dynamic>();

void main() {
  group('catalog invariants', () {
    test('no two entries claim the same name', () {
      final seen = <String, String>{};
      for (final model in KnownOpenAIModel.values) {
        for (final name in model.versions) {
          expect(
            seen,
            isNot(contains(name)),
            reason: '$name is claimed by both ${seen[name]} and ${model.id}',
          );
          seen[name] = model.id;
        }
      }
    });

    test('every name is lower-case, as the OpenAI catalog is', () {
      for (final model in KnownOpenAIModel.values) {
        for (final name in model.versions) {
          expect(name, name.toLowerCase());
        }
      }
    });

    test('the alias is the first version', () {
      for (final model in KnownOpenAIModel.values) {
        expect(model.versions.first, model.id);
      }
    });

    test('every entry is a chat model, the only modality served', () {
      for (final model in KnownOpenAIModel.values) {
        expect(getModelType(model.id), 'chat', reason: model.id);
      }
    });

    test('only live models advertise a stable stage', () {
      for (final model in KnownOpenAIModel.values) {
        expect(model.info.stage, model.stage.wireName, reason: model.id);
      }
      expect(KnownOpenAIModel.gpt4o.stage, OpenAIModelStage.stable);
      expect(KnownOpenAIModel.gpt35Turbo.stage, OpenAIModelStage.legacy);
      expect(KnownOpenAIModel.gpt45.stage, OpenAIModelStage.deprecated);
    });

    test('every entry resolves to itself', () {
      for (final model in KnownOpenAIModel.values) {
        for (final name in model.versions) {
          expect(knownOpenAIModelFor(name), model, reason: name);
        }
      }
    });

    test('knownOpenAIModels is keyed by the bare alias', () {
      expect(
        knownOpenAIModels.keys,
        unorderedEquals(KnownOpenAIModel.values.map((m) => m.id)),
      );
    });

    test('only structured-output models claim constrained generation', () {
      for (final model in KnownOpenAIModel.values) {
        if (model.supports['constrained'] != true) continue;
        expect(model.supports['output'], contains('json'), reason: model.id);
      }
    });
  });

  group('openAIModelAlias', () {
    test('strips a dated snapshot suffix', () {
      expect(openAIModelAlias('gpt-4o-2024-08-06'), 'gpt-4o');
      expect(openAIModelAlias('o3-2025-04-16'), 'o3');
    });

    test('leaves undated names alone', () {
      expect(openAIModelAlias('gpt-4o'), 'gpt-4o');
      expect(openAIModelAlias('gpt-3.5-turbo-0125'), 'gpt-3.5-turbo-0125');
    });
  });

  group('typed refs', () {
    test('name the curated models under the default namespace', () {
      expect(OpenAIModels.gpt4o.name, 'openai/gpt-4o');
      expect(OpenAIModels.o3Mini.name, 'openai/o3-mini');
      expect(OpenAIModels.gpt56Sol.name, 'openai/gpt-5.6-sol');
    });

    test('match openAI.model() for the same id', () {
      expect(
        OpenAIModels.gpt41Mini.name,
        openAI.model(KnownOpenAIModel.gpt41Mini.id).name,
      );
    });
  });

  group('list', () {
    test('does not list models OpenAI no longer serves', () async {
      final names = modelNames(await pluginListing(['gpt-4o']).list());

      for (final model in KnownOpenAIModel.values) {
        if (model.stage != OpenAIModelStage.deprecated) continue;
        expect(names, isNot(contains('openai/${model.id}')), reason: model.id);
      }
    });

    test('a retired model still resolves with its capabilities', () {
      final action = pluginListing(const []).resolve(.model, 'gpt-4.5');

      expect(modelInfoOf(action!)['supports'], multimodalSupports);
    });

    test('includes curated models missing from discovery', () async {
      final metadata = await pluginListing(['gpt-4o']).list();
      final names = metadata.map((m) => m.name).toSet();

      for (final model in KnownOpenAIModel.values) {
        if (model.stage == OpenAIModelStage.deprecated) continue;
        expect(names, contains('openai/${model.id}'));
      }
    });

    test('does not duplicate curated models returned by discovery', () async {
      final metadata = await pluginListing(['gpt-4o']).list();
      final names = metadata.map((m) => m.name).toList();

      expect(names.where((n) => n == 'openai/gpt-4o'), hasLength(1));
    });

    test('a custom baseUrl keeps the curated capabilities', () async {
      // gpt-4o would not catch this: its curated supports are the same map
      // the generic fallback hands out. A text-only model does.
      final metadata = await pluginListing([
        'gpt-3.5-turbo',
      ], baseUrl: 'https://gateway.ai.cloudflare.com/v1/openai').list();
      final info = modelMetadataOf(metadata.single);

      expect(info['supports'], textOnlyLegacySupports);
      expect((info['supports'] as Map)['media'], isFalse);
    });

    test('a custom baseUrl drops OpenAI\'s deployment details', () async {
      final metadata = await pluginListing([
        'gpt-4o',
      ], baseUrl: 'https://openrouter.ai/api/v1').list();
      final info = modelMetadataOf(metadata.single);

      // The label names OpenAI's offering, the stage tracks OpenAI's
      // retirement schedule, and the versions enumerate what OpenAI serves.
      expect(info.containsKey('label'), isFalse);
      expect(info.containsKey('stage'), isFalse);
      expect(info.containsKey('versions'), isFalse);
    });

    test('an uncurated name on a compat backend takes the defaults', () async {
      final metadata = await pluginListing([
        'llama-3.3-70b-versatile',
      ], baseUrl: 'https://api.groq.com/openai/v1').list();

      expect(modelMetadataOf(metadata.single)['supports'], multimodalSupports);
    });

    test('non-chat models stay filtered out', () async {
      final metadata = await pluginListing([
        'text-embedding-3-small',
        'whisper-1',
        'dall-e-3',
      ]).list();
      final names = metadata.map((m) => m.name).toSet();

      expect(names, isNot(contains('openai/text-embedding-3-small')));
      expect(names, isNot(contains('openai/whisper-1')));
      expect(names, isNot(contains('openai/dall-e-3')));
    });
  });

  group('resolve', () {
    test('an uncurated name resolves with the dynamic defaults', () {
      final action = pluginListing(const []).resolve(.model, 'gpt-9-turbo');

      expect(action, isNotNull);
      final info = modelInfoOf(action!);
      expect(info['supports'], multimodalSupports);
      // No curated label or stage: Model falls back to the action name.
      expect(info['label'], 'openai/gpt-9-turbo');
      expect(info.containsKey('stage'), isFalse);
    });

    test('a curated name resolves with its curated metadata', () {
      final action = pluginListing(const []).resolve(.model, 'o1-mini');

      final info = modelInfoOf(action!);
      expect(info['label'], 'OpenAI o1-mini');
      expect(info['supports'], reasoningPreviewSupports);
    });

    test('non-model action types do not resolve', () {
      expect(pluginListing(const []).resolve(.embedder, 'gpt-4o'), isNull);
    });
  });
}
