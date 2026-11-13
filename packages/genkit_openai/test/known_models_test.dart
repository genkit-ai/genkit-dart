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
import 'package:genkit_openai/src/known_models.dart';
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:genkit_openai/src/utils.dart';
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
    test('the exported collections cannot be mutated', () {
      expect(() => knownChatModels.add('x'), throwsUnsupportedError);
      expect(
        () => knownOpenAIModels['x'] = knownOpenAIModels.values.first,
        throwsUnsupportedError,
      );
    });

    test(
      'every o-series model with settable effort is marked as reasoning',
      () {
        // Catches an o-series entry added without `reasons`, which would then
        // be refused a parameter it accepts.
        for (final model in KnownOpenAIModel.values) {
          if (model.supports != reasoningSupports) continue;
          expect(model.reasons, isTrue, reason: model.id);
        }
      },
    );

    test('the GPT-5 and GPT-6 families reason, bar the ChatGPT-tuned '
        'snapshot and the search model', () {
      for (final model in KnownOpenAIModel.values) {
        if (!model.id.startsWith('gpt-5') && !model.id.startsWith('gpt-6')) {
          continue;
        }
        expect(
          model.reasons,
          !{'gpt-5-chat-latest', 'gpt-5-search-api'}.contains(model.id),
          reason: model.id,
        );
      }
    });

    test('no model that predates reasoning claims to reason', () {
      for (final id in ['gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4.1-mini']) {
        expect(knownOpenAIModelFor(id)!.reasons, isFalse, reason: id);
      }
    });

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

    test('the stage is carried into ModelInfo', () {
      for (final model in KnownOpenAIModel.values) {
        expect(model.info.stage, model.stage.wireName, reason: model.id);
      }
      expect(KnownOpenAIModel.gpt55.stage, OpenAIModelStage.stable);
      expect(KnownOpenAIModel.gpt6Sol.stage, OpenAIModelStage.stable);
    });

    test('models with an announced shutdown are deprecated', () {
      // Still served until the date, so still listed.
      for (final id in [
        // 2026-12-11
        'gpt-5', 'gpt-5-mini', 'gpt-5-nano', 'o3',
        // 2027-01-14
        'gpt-4.1', 'gpt-4.1-mini', 'gpt-4o', 'gpt-4o-mini',
        // 2027-04-01
        'gpt-5.1', 'gpt-5.4-nano',
      ]) {
        expect(
          knownOpenAIModelFor(id)!.stage,
          OpenAIModelStage.deprecated,
          reason: id,
        );
        expect(knownChatModels, contains(id), reason: id);
      }
    });

    test('models OpenAI has shut down are not curated', () {
      for (final id in [
        // 2026-07-23
        'gpt-5-chat-latest',
        // 2026-10-23
        'gpt-4.1-nano', 'o4-mini', 'o3-mini', 'o1', 'gpt-4-turbo', 'gpt-4',
        'gpt-3.5-turbo',
        // earlier
        'gpt-4.5', 'chatgpt-4o-latest', 'o1-mini', 'o1-preview', 'gpt-4-32k',
        'gpt-4-vision-preview', 'gpt-4-0125-preview', 'gpt-4-1106-preview',
      ]) {
        expect(knownOpenAIModelFor(id), isNull, reason: id);
      }
      // gpt-4o outlives its first snapshot, gpt-4o-2024-05-13, which is no
      // longer one of its versions.
      expect(
        KnownOpenAIModel.gpt4o.versions,
        isNot(contains('gpt-4o-2024-05-13')),
      );
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
      expect(openAIModelAlias('gpt-4-0613'), 'gpt-4-0613');
    });
  });

  group('Azure spellings', () {
    test('normalisation only touches the dotted-version prefix', () {
      expect(openAIModelSpelling('gpt-4o'), 'gpt-4o');
      expect(openAIModelSpelling('gpt-35-turbo'), 'gpt-3.5-turbo');
      expect(openAIModelSpelling('o3-mini'), 'o3-mini');
    });

    test('the dotless family reaches the retired gpt-3.5-turbo on a compat '
        'host', () {
      for (final deployment in [
        'gpt-35-turbo',
        'gpt-35-turbo-16k',
        'gpt-35-turbo-0125',
        'gpt-35-turbo-1106',
        'gpt-35-turbo-0613',
        'gpt-35-turbo-16k-0613',
      ]) {
        expect(
          compatModelInfo(deployment).supports,
          _textOnlyJson,
          reason: deployment,
        );
      }
    });
  });

  group('retired models on a compat host', () {
    // The capabilities these names had while curated, so a gateway that
    // still serves one keeps describing it as before.
    const pinned = <String, Map<String, dynamic>>{
      'gpt-3.5-turbo': _textOnlyJson,
      'gpt-3.5-turbo-0125': _textOnlyJson,
      'gpt-3.5-turbo-16k': _textOnlyJson,
      'gpt-4': _textOnlyNoJson,
      'gpt-4-0613': _textOnlyNoJson,
      'gpt-4-0314': _textOnlyNoJson,
      'gpt-4-32k': _textOnlyNoJson,
      'gpt-4-32k-0613': _textOnlyNoJson,
      'o1': _reasoningVision,
      'o1-2024-12-17': _reasoningVision,
      'o4-mini': _reasoningVision,
      'o4-mini-2025-04-16': _reasoningVision,
      'o3-mini': _reasoningTextOnly,
      'o3-mini-2025-01-31': _reasoningTextOnly,
      'o1-mini': _reasoningPreview,
      'o1-mini-2024-09-12': _reasoningPreview,
      'o1-preview': _reasoningPreview,
      'gpt-4-turbo': _visionNoConstrained,
      'gpt-4-turbo-2024-04-09': _visionNoConstrained,
      'gpt-4-turbo-preview': _visionNoConstrained,
      'gpt-4-0125-preview': _visionNoConstrained,
      'gpt-4-1106-preview': _visionNoConstrained,
      'gpt-4-vision-preview': _visionNoTools,
      'gpt-4-1106-vision-preview': _visionNoTools,
      'gpt-4-vision': _visionNoTools,
      'chatgpt-4o-latest': _visionNoTools,
      'gpt-5-chat-latest': _visionNoTools,
      'gpt-4.5': _current,
      'gpt-4.5-preview': _current,
      'gpt-4.1-nano': _current,
      'gpt-4.1-nano-2025-04-14': _current,
    };

    test('keep the capabilities they had while curated', () {
      pinned.forEach((name, supports) {
        expect(compatModelInfo(name).supports, supports, reason: name);
      });
    });

    test('match case-insensitively', () {
      expect(compatModelInfo('GPT-4').supports, _textOnlyNoJson);
    });

    test('carry no OpenAI deployment details', () {
      for (final name in pinned.keys) {
        final info = compatModelInfo(name);
        expect(info.label, isNull, reason: name);
        expect(info.stage, isNull, reason: name);
        expect(info.versions, isNull, reason: name);
      }
    });

    test('are not listed or curated for OpenAI itself', () {
      for (final name in pinned.keys) {
        expect(knownChatModels, isNot(contains(name)), reason: name);
        expect(knownOpenAIModelFor(name), isNull, reason: name);
      }
      // OpenAI answers model_not_found for them, so its own host takes the
      // generic fallback.
      expect(modelInfoFor('gpt-3.5-turbo').supports, multimodalSupports);
      expect(modelInfoFor('o1-mini').supports, reasoningSupports);
    });

    test('resolve on a compat plugin with the pinned capabilities', () {
      final plugin = pluginListing(
        const [],
        baseUrl: 'https://my-gateway.example.com/v1',
      );
      for (final name in ['gpt-3.5-turbo', 'gpt-4', 'o1-mini', 'o3-mini']) {
        final action = plugin.resolve(.model, name);
        expect(modelInfoOf(action!)['supports'], pinned[name], reason: name);
      }
    });
  });

  group('handle refs', () {
    test('name models under the default namespace', () {
      expect(openAI.model('gpt-5.6-sol').name, 'openai/gpt-5.6-sol');
      expect(openAI.model('gpt-5.5', namespace: 'azure').name, 'azure/gpt-5.5');
    });
  });

  group('list', () {
    test('lists deprecated models until they shut down', () async {
      final names = modelNames(await pluginListing(['gpt-4o']).list());

      for (final model in KnownOpenAIModel.values) {
        expect(names, contains('openai/${model.id}'), reason: model.id);
      }
      expect(names, contains('openai/gpt-5'));
      expect(names, isNot(contains('openai/gpt-4')));
    });

    test('a removed model still resolves by name, with the defaults', () {
      // Removing a shut-down model takes it out of the catalog and the
      // listing, not out of reach: resolve builds any name, and OpenAI is
      // left to answer for it.
      for (final id in ['gpt-4', 'gpt-3.5-turbo', 'gpt-4.5', 'o1-mini']) {
        final action = pluginListing(const []).resolve(.model, id);

        expect(action, isNotNull, reason: id);
        expect(modelInfoOf(action!).containsKey('stage'), isFalse, reason: id);
      }
    });

    test('Responses-only models are dropped from discovery', () async {
      final names = modelNames(
        await pluginListing([
          'gpt-5.5-pro',
          'gpt-5.5-pro-2026-04-23',
          'gpt-5.2-pro',
          'o3-pro',
          'gpt-5.6-cyber',
          'gpt-oss-120b',
          'gpt-daybreak-blue-latest',
          'gpt-6-rosalind',
          'gpt-rosalind-research',
          'gpt-5.3-codex',
          'gpt-6-cyber',
          'gpt-6-sol',
        ]).list(),
      );

      for (final id in [
        'gpt-5.5-pro',
        'gpt-5.5-pro-2026-04-23',
        'gpt-5.2-pro',
        'o3-pro',
        'gpt-5.6-cyber',
        'gpt-oss-120b',
        'gpt-daybreak-blue-latest',
        'gpt-6-rosalind',
        'gpt-rosalind-research',
        // Classified as a code model, so dropped before the Responses rule.
        'gpt-5.3-codex',
      ]) {
        expect(names, isNot(contains('openai/$id')), reason: id);
      }
      // gpt-6-cyber, unlike gpt-5.6-cyber, is served by Chat Completions.
      expect(names, containsAll(['openai/gpt-6-cyber', 'openai/gpt-6-sol']));
    });

    test('a compat backend keeps its -pro models', () async {
      // The rule describes OpenAI's catalog; a gateway may well serve a
      // `-pro` name over chat completions.
      final metadata = await pluginListing([
        'qwen-pro',
      ], baseUrl: 'https://my-gateway.example.com/v1').list();

      expect(modelNames(metadata), ['openai/qwen-pro']);
    });

    test('includes curated models missing from discovery', () async {
      final metadata = await pluginListing(['gpt-4o']).list();
      final names = metadata.map((m) => m.name).toSet();

      for (final model in KnownOpenAIModel.values) {
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
      // the generic fallback hands out. A model without chat tools does.
      final metadata = await pluginListing([
        'gpt-6-astra',
      ], baseUrl: 'https://gateway.ai.cloudflare.com/v1/openai').list();
      final info = modelMetadataOf(metadata.single);

      expect(info['supports'], multimodalNoChatToolsSupports);
      expect((info['supports'] as Map)['tools'], isFalse);
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

    test('OpenAI\'s own baseUrl keeps them', () async {
      // Both spellings dial the same host, so naming it explicitly is not a
      // compat backend and must not cost the curated catalog.
      final metadata = await pluginListing([
        'gpt-4o',
      ], baseUrl: 'https://api.openai.com/v1').list();
      final info = modelMetadataOf(
        metadata.firstWhere((m) => m.name == 'openai/gpt-4o'),
      );

      expect(info['label'], isNotNull);
      expect(info['stage'], isNotNull);
      expect(info.containsKey('versions'), isTrue);
      expect(
        modelNames(metadata),
        containsAll(knownChatModels.map((id) => 'openai/$id')),
      );
    });

    test('OpenAI\'s own baseUrl keeps the audio catalogs too', () async {
      // Same host, so the speech and transcription ids follow the chat
      // catalog rather than being withheld as a compat backend's would be.
      final names = modelNames(
        await pluginListing([
          'gpt-4o',
        ], baseUrl: 'https://api.openai.com/v1').list(),
      );

      expect(names, contains('openai/tts-1'));
      expect(names, contains('openai/whisper-1'));
    });

    test('an uncurated o-series name on a compat backend is not read as '
        'OpenAI\'s', () async {
      // `o`-and-a-digit is OpenAI's naming, not another host's.
      final metadata = await pluginListing([
        'o5-mini',
      ], baseUrl: 'https://api.groq.com/openai/v1').list();

      expect(modelMetadataOf(metadata.single)['supports'], multimodalSupports);
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
      final models = modelNames(metadata);

      // The embedder is listed as an embedder and whisper as a transcription
      // model, both with their own options schema; image generation is a
      // modality this plugin does not serve at all.
      expect(models, isNot(contains('openai/text-embedding-3-small')));
      expect(
        embedderNames(metadata),
        contains('openai/text-embedding-3-small'),
      );
      expect(models, contains('openai/whisper-1'));
      expect(
        modelMetadataOf(
          metadata.firstWhere((m) => m.name == 'openai/whisper-1'),
        )['supports'],
        containsPair('media', true),
      );
      expect(models, isNot(contains('openai/dall-e-3')));
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
      final action = pluginListing(const []).resolve(.model, 'gpt-6-astra');

      final info = modelInfoOf(action!);
      expect(info['label'], 'OpenAI GPT-6 Astra');
      expect(info['supports'], multimodalNoChatToolsSupports);
    });

    test('action types this plugin does not serve do not resolve', () {
      expect(pluginListing(const []).resolve(.evaluator, 'gpt-4o'), isNull);
    });
  });

  group('GPT-6', () {
    test('every model is curated, listed and reasons', () {
      for (final id in [
        'gpt-6-astra',
        'gpt-6-sol',
        'gpt-6-luna',
        'gpt-6.1-sol',
        'gpt-6.1-terra',
      ]) {
        final model = knownOpenAIModelFor(id);
        expect(model, isNotNull, reason: id);
        expect(model!.stage, OpenAIModelStage.stable, reason: id);
        expect(model.reasons, isTrue, reason: id);
        expect(knownChatModels, contains(id), reason: id);
        expect(supportsVision(id), isTrue, reason: id);
        expect(model.supports['constrained'], isTrue, reason: id);
      }
    });

    test('only gpt-6-sol and gpt-6-luna advertise tools', () {
      expect(supportsTools('gpt-6-sol'), isTrue);
      expect(supportsTools('gpt-6-luna'), isTrue);
      expect(supportsTools('gpt-6-astra'), isFalse);
      expect(supportsTools('gpt-6.1-sol'), isFalse);
      expect(supportsTools('gpt-6.1-terra'), isFalse);
    });
  });

  group('gpt-5-search-api', () {
    test('is curated without tools, image input or reasoning', () {
      for (final id in ['gpt-5-search-api', 'gpt-5-search-api-2025-10-14']) {
        final model = knownOpenAIModelFor(id);
        expect(model, KnownOpenAIModel.gpt5SearchApi, reason: id);
        expect(supportsTools(id), isFalse, reason: id);
        expect(supportsVision(id), isFalse, reason: id);
        expect(openAIModelReasons(id), isFalse, reason: id);
        expect(model!.supports['constrained'], isTrue, reason: id);
      }
    });
  });

  _fixtureDiscoveryTests();

  group('uncurated reasoning models', () {
    test('an o-series name reasons and takes no system role', () {
      expect(knownOpenAIModelFor('o5-mini'), isNull);
      expect(openAIModelReasons('o5-mini'), isTrue);
      expect(modelInfoFor('o5-mini').supports, reasoningSupports);
      expect(modelInfoFor('o5-mini').supports?['systemRole'], isFalse);
    });

    test('a GPT name from generation 5 on reasons', () {
      for (final id in ['gpt-5.7', 'gpt-6.2-terra', 'gpt-7', 'gpt-9-turbo']) {
        expect(openAIModelReasons(id), isTrue, reason: id);
        expect(modelInfoFor(id).supports, multimodalSupports, reason: id);
      }
    });

    test('older, ChatGPT-tuned and non-OpenAI names make no claim', () {
      for (final id in [
        'gpt-4.2',
        'gpt-6-chat-latest',
        'chatgpt-6-latest',
        'gpt-oss-120b',
        'llama-3.3-70b-versatile',
        'text-embedding-3-small',
      ]) {
        expect(openAIModelReasons(id), isNull, reason: id);
      }
    });

    test('a curated entry answers for itself', () {
      expect(openAIModelReasons('gpt-4o'), isFalse);
      expect(openAIModelReasons('gpt-5.5-2026-04-23'), isTrue);
    });

    test('a retired entry answers for itself', () {
      for (final id in [
        'gpt-4',
        'gpt-4-0613',
        'gpt-3.5-turbo',
        'gpt-35-turbo',
        'gpt-4-turbo',
        'o1-mini',
        'o1-preview',
      ]) {
        expect(knownOpenAIModelFor(id), isNull, reason: id);
        expect(openAIModelReasons(id), isFalse, reason: id);
      }
      for (final id in ['o1', 'o3-mini', 'o4-mini-2025-04-16']) {
        expect(openAIModelReasons(id), isTrue, reason: id);
      }
    });
  });
}

/// Ids discovery lists as chat models.
const _fixtureChat = [
  'chat-latest',
  'gpt-4.1',
  'gpt-4.1-2025-04-14',
  'gpt-4.1-mini',
  'gpt-4.1-mini-2025-04-14',
  'gpt-4o',
  'gpt-4o-2024-08-06',
  'gpt-4o-2024-11-20',
  'gpt-4o-mini',
  'gpt-4o-mini-2024-07-18',
  'gpt-5',
  'gpt-5-2025-08-07',
  'gpt-5-mini',
  'gpt-5-mini-2025-08-07',
  'gpt-5-nano',
  'gpt-5-nano-2025-08-07',
  'gpt-5-search-api',
  'gpt-5-search-api-2025-10-14',
  'gpt-5.1',
  'gpt-5.1-2025-11-13',
  'gpt-5.2',
  'gpt-5.2-2025-12-11',
  'gpt-5.4',
  'gpt-5.4-2026-03-05',
  'gpt-5.4-mini',
  'gpt-5.4-mini-2026-03-17',
  'gpt-5.4-nano',
  'gpt-5.4-nano-2026-03-17',
  'gpt-5.5',
  'gpt-5.5-2026-04-23',
  'gpt-5.6-sol',
  'gpt-5.6-terra',
  'gpt-5.6-luna',
  'gpt-6-sol',
  'gpt-6-luna',
  'gpt-6-astra',
  'gpt-6.1-sol',
  'gpt-6.1-terra',
  'gpt-6-cyber',
  'o3',
  'o3-2025-04-16',
  'ft:gpt-4o-mini-2024-07-18:acme::abc123',
];

/// Ids discovery does not list at all.
const _fixtureHidden = [
  'gpt-5-pro',
  'gpt-5-pro-2025-10-06',
  'gpt-5.2-pro',
  'gpt-5.2-pro-2025-12-11',
  'gpt-5.4-pro',
  'gpt-5.4-pro-2026-03-05',
  'gpt-5.5-pro',
  'gpt-5.5-pro-2026-04-23',
  'o3-pro',
  'o3-pro-2025-06-10',
  'gpt-5.3-codex',
  'gpt-5.6-cyber',
  'gpt-6-rosalind',
  'gpt-rosalind-research',
  'gpt-daybreak-1',
  'gpt-audio',
  'gpt-audio-1.5',
  'gpt-audio-2025-08-28',
  'gpt-audio-mini',
  'gpt-audio-mini-2025-12-15',
  'gpt-live-1',
  'gpt-live-transcribe',
  'gpt-realtime',
  'gpt-realtime-1.5',
  'gpt-realtime-2',
  'gpt-realtime-2.1',
  'gpt-realtime-2.1-mini',
  'gpt-realtime-2025-08-28',
  'gpt-realtime-mini',
  'gpt-realtime-mini-2025-12-15',
  'gpt-realtime-translate',
  'gpt-realtime-whisper',
  'omni-moderation-2024-09-26',
  'omni-moderation-latest',
  'davinci-002',
  'babbage-002',
  'curie:ft-acme-2023-06-07-10-19-42',
  'davinci:ft-acme-2023-01-01-00-00-00',
];

/// Ids discovery may list, but never as chat models.
const _fixtureOther = [
  'text-embedding-3-large',
  'text-embedding-3-small',
  'text-embedding-ada-002',
  'tts-1',
  'tts-1-1106',
  'tts-1-hd',
  'tts-1-hd-1106',
  'gpt-4o-mini-tts',
  'gpt-4o-mini-tts-2025-03-20',
  'gpt-4o-mini-tts-2025-12-15',
  'whisper-1',
  'gpt-transcribe',
  'gpt-4o-transcribe',
  'gpt-4o-transcribe-diarize',
  'gpt-4o-mini-transcribe',
  'gpt-4o-mini-transcribe-2025-03-20',
  'gpt-4o-mini-transcribe-2025-12-15',
  'gpt-image-1-mini',
  'gpt-image-1.5',
  'gpt-image-2',
  'gpt-image-2-2026-04-21',
  'gpt-image-2.5-flare',
  'gpt-image-2.5-flare-2026-09-08',
  'gpt-image-2.5-sunburst',
  'gpt-image-2.5-sunburst-2026-09-08',
  'gpt-image-2.6-flare',
  'gpt-image-2.6-sunburst',
  'chatgpt-image-latest',
];

/// Chat models that advertise no tools.
const _fixtureNoTools = {
  'gpt-6-astra',
  'gpt-6.1-sol',
  'gpt-6.1-terra',
  'gpt-5-search-api',
  'gpt-5-search-api-2025-10-14',
};

/// Discovery against a `GET /models` that returns every fixture id at once.
void _fixtureDiscoveryTests() {
  group('discovery fixture', () {
    late List<ActionMetadata> listing;
    late Set<String> chatModels;

    setUpAll(() async {
      listing = await pluginListing([
        ..._fixtureChat,
        ..._fixtureHidden,
        ..._fixtureOther,
      ]).list();
      final chatOptions = modelMetadataOf(
        listing.firstWhere((m) => m.name == 'openai/gpt-5.5'),
      )['customOptions'];
      chatModels = {
        for (final m in listing)
          if (m.actionType == ActionType.model &&
              equals(
                chatOptions,
              ).matches(modelMetadataOf(m)['customOptions'], {}))
            m.name,
      };
    });

    for (final id in _fixtureChat) {
      test('$id is listed as a chat model', () {
        expect(chatModels, contains('openai/$id'));
        final supports =
            modelMetadataOf(
                  listing.firstWhere((m) => m.name == 'openai/$id'),
                )['supports']
                as Map;
        expect(supports['tools'], !_fixtureNoTools.contains(id));
      });
    }

    for (final id in _fixtureHidden) {
      test('$id is not listed', () {
        expect(listing.map((m) => m.name), isNot(contains('openai/$id')));
      });
    }

    for (final id in _fixtureOther) {
      test('$id is not listed as a chat model', () {
        expect(chatModels, isNot(contains('openai/$id')));
      });
    }
  });
}

const _textOnlyJson = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
};

const _textOnlyNoJson = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text'],
};

const _reasoningVision = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
  'constrained': true,
};

const _reasoningTextOnly = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': true,
  'toolChoice': true,
  'media': false,
  'output': ['text', 'json'],
  'constrained': true,
};

const _reasoningPreview = <String, dynamic>{
  'multiturn': true,
  'systemRole': false,
  'tools': false,
  'media': false,
  'output': ['text'],
};

const _visionNoConstrained = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
};

const _visionNoTools = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': false,
  'media': true,
  'output': ['text'],
};

const _current = <String, dynamic>{
  'multiturn': true,
  'systemRole': true,
  'tools': true,
  'toolChoice': true,
  'media': true,
  'output': ['text', 'json'],
  'constrained': true,
};
