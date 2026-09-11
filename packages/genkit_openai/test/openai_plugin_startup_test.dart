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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/openai_plugin.dart' show OpenAIPlugin;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'discovery_client.dart';

/// An environment with no API key in it.
///
/// The package's own `integration_test.dart` expects `OPENAI_API_KEY`
/// exported, so the no-key tests below must not read the real environment or
/// they pass or fail depending on the developer's shell.
String? noEnv(String name) => null;

/// A client that records every request and refuses them all.
///
/// Startup must not touch the network, so a test that passes with this client
/// installed proves no request was made - and [requests] shows what was tried
/// when one is.
class RecordingFailClient {
  final List<String> requests = [];

  MockClient get client => MockClient((request) async {
    requests.add('${request.method} ${request.url}');
    throw http.ClientException('network is unavailable in this test');
  });
}

/// Rejects discovery with a 401, as a bad or expired key would.
///
/// Preferred over a thrown exception where a request is actually expected: the
/// SDK retries transport errors with backoff, which makes the test slow.
MockClient unauthorizedClient(List<String> requests) {
  return MockClient((request) async {
    requests.add('${request.method} ${request.url}');
    return http.Response(
      jsonEncode({
        'error': {'message': 'Incorrect API key provided'},
      }),
      401,
    );
  });
}

void main() {
  group('offline startup', () {
    test('init does no I/O and does not throw without a key', () async {
      final recorder = RecordingFailClient();
      final plugin = OpenAIPlugin(httpClient: recorder.client);

      final actions = await plugin.init();

      expect(actions, isEmpty);
      expect(
        recorder.requests,
        isEmpty,
        reason: 'init() must not touch the network',
      );
    });

    test('init registers custom models without a key', () async {
      final recorder = RecordingFailClient();
      final plugin = OpenAIPlugin(
        httpClient: recorder.client,
        customModels: [CustomModelDefinition(name: 'my-model')],
      );

      final actions = await plugin.init();

      expect(actions, hasLength(1));
      expect(actions.first.name, 'openai/my-model');
      expect(recorder.requests, isEmpty);
    });

    test('listActions succeeds with no key and no network', () async {
      // This is the regression: previously init() threw here, which made
      // /api/__health and /api/actions return 500 and the Dev UI unable to
      // connect at all.
      final recorder = RecordingFailClient();
      final ai = Genkit(
        plugins: [OpenAIPlugin(httpClient: recorder.client, configVar: noEnv)],
      );

      final actions = await ai.registry.listActions();
      final names = actions
          .where((a) => a.actionType == .model)
          .map((a) => a.name);

      expect(names, containsAll(knownChatModels.map((id) => 'openai/$id')));
      expect(
        recorder.requests,
        isEmpty,
        reason: 'discovery must be skipped when no key is available',
      );

      await ai.shutdown();
    });

    test('a model resolves and generates without startup discovery', () async {
      final requests = <String>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKey: 'test-key',
            httpClient: MockClient((request) async {
              requests.add(request.url.path);
              return http.Response(
                jsonEncode({
                  'id': 'chatcmpl-test',
                  'object': 'chat.completion',
                  'created': 0,
                  'model': 'gpt-4o',
                  'choices': [
                    {
                      'index': 0,
                      'message': {'role': 'assistant', 'content': 'ok'},
                      'finish_reason': 'stop',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ],
      );

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'hi',
      );

      expect(response.text, 'ok');
      expect(
        requests.where((p) => p.endsWith('/models')),
        isEmpty,
        reason: 'a plain generate must not trigger model discovery',
      );

      await ai.shutdown();
    });
  });

  group('list degrades instead of throwing', () {
    test('falls back to the catalog when discovery fails', () async {
      final requests = <String>[];
      final plugin = OpenAIPlugin(
        apiKey: 'test-key',
        httpClient: unauthorizedClient(requests),
      );

      final metadata = await plugin.list();

      expect(
        requests,
        isNotEmpty,
        reason: 'with a key present, discovery should be attempted',
      );
      expect(
        modelNames(metadata),
        containsAll(knownChatModels.map((id) => 'openai/$id')),
      );
    });

    test('enriches the catalog with discovered models', () async {
      final requests = <String>[];
      final plugin = OpenAIPlugin(
        apiKey: 'test-key',
        httpClient: discoveryClient(requests, ids: ['gpt-5-preview']),
      );

      final names = modelNames(await plugin.list());

      expect(names, contains('openai/gpt-5-preview'));
      expect(names, contains('openai/gpt-4o'));
    });

    test(
      'does not duplicate a model that is both curated and discovered',
      () async {
        final requests = <String>[];
        final plugin = OpenAIPlugin(
          apiKey: 'test-key',
          httpClient: discoveryClient(requests, ids: ['gpt-4o']),
        );

        final metadata = await plugin.list();
        final matching = metadata.where((m) => m.name == 'openai/gpt-4o');

        expect(matching, hasLength(1));
      },
    );

    test('custom models are listed', () async {
      // Previously list() omitted them entirely.
      final plugin = OpenAIPlugin(
        apiKey: 'test-key',
        httpClient: unauthorizedClient(<String>[]),
        customModels: [
          CustomModelDefinition(
            name: 'llama-3.3-70b',
            info: ModelInfo(label: 'Llama 3.3 70B'),
          ),
        ],
      );

      final metadata = await plugin.list();
      final custom = metadata.firstWhere(
        (m) => m.name == 'openai/llama-3.3-70b',
      );

      expect(
        (custom.metadata['model'] as Map)['label'],
        'Llama 3.3 70B',
        reason: 'the caller-supplied ModelInfo should win over heuristics',
      );
    });

    test('non-chat discovered models are still filtered out', () async {
      final requests = <String>[];
      final plugin = OpenAIPlugin(
        apiKey: 'test-key',
        httpClient: discoveryClient(
          requests,
          ids: ['gpt-4o', 'text-embedding-3-small', 'dall-e-3'],
        ),
      );

      final names = modelNames(await plugin.list());

      expect(names, contains('openai/gpt-4o'));
      expect(names, isNot(contains('openai/text-embedding-3-small')));
      expect(names, isNot(contains('openai/dall-e-3')));
    });
  });

  group('catalog metadata', () {
    test('every listed model is a chat model with curated capabilities', () {
      // A listed id described by the wrong capabilities is worse than one
      // that is missing - e.g. advertising media:false for a multimodal model
      // makes Genkit reject image inputs.
      for (final id in knownChatModels) {
        expect(getModelType(id), 'chat', reason: '$id should classify as chat');

        final info = modelInfoFor(id);
        expect(
          knownOpenAIModelFor(id),
          isNotNull,
          reason: '$id is listed, so it must carry curated metadata',
        );
        expect(info.supports, isNotNull);
        expect(info.label, isNotNull, reason: '$id should have a label');
      }
    });

    test('every listed model is one OpenAI still serves', () {
      for (final id in knownChatModels) {
        expect(
          knownOpenAIModelFor(id)!.stage,
          isNot(OpenAIModelStage.deprecated),
          reason: '$id is retired; listing it offers a name that 404s',
        );
      }
    });

    test('the catalog lists aliases, not dated snapshots', () {
      for (final id in knownChatModels) {
        expect(
          RegExp(r'-\d{4}-\d{2}-\d{2}$').hasMatch(id),
          isFalse,
          reason: '$id is a dated snapshot; discovery surfaces those',
        );
      }
    });

    test('the ChatGPT-tuned snapshots take no tools', () {
      // These were absent while capabilities came from name matching, which
      // could not describe a chat model that takes no tools. The catalog can.
      // Only the live one is listed; chatgpt-4o-latest went with the 4o line.
      for (final id in ['gpt-5-chat-latest', 'chatgpt-4o-latest']) {
        expect(modelInfoFor(id).supports?['tools'], isFalse, reason: id);
        expect(modelInfoFor(id).supports?['media'], isTrue, reason: id);
      }
      expect(knownChatModels, contains('gpt-5-chat-latest'));
      expect(knownChatModels, isNot(contains('chatgpt-4o-latest')));
    });

    test('the current multimodal families advertise media input', () {
      // Pins the #414 fix: name matching reported media:false for every
      // family from 4.1 on, which made those models unusable for vision in
      // any consumer that reads the metadata.
      for (final id in [
        'gpt-4.1',
        'gpt-4.1-mini',
        'gpt-5',
        'gpt-5-mini',
        'gpt-5.1',
        'gpt-5.4',
        'gpt-5.5',
        'gpt-5.6-sol',
        'gpt-4o',
      ]) {
        expect(modelInfoFor(id).supports?['media'], isTrue, reason: id);
      }

      // ...and the text-only ones are still text-only, so the assertion above
      // cannot be satisfied by making everything multimodal.
      for (final id in ['gpt-4', 'gpt-3.5-turbo', 'o3-mini']) {
        expect(modelInfoFor(id).supports?['media'], isFalse, reason: id);
      }
    });
  });

  group('apiKeyProvider is handled defensively during listing', () {
    test('a throwing provider degrades to the catalog', () async {
      // Key resolution happens inside list()'s try/catch. If it did not, a
      // provider blip (expired credentials, a failed token fetch) would take
      // the whole listing down instead of degrading.
      final plugin = OpenAIPlugin(
        apiKeyProvider: () async =>
            throw StateError('token endpoint unavailable'),
        httpClient: RecordingFailClient().client,
      );

      final metadata = await plugin.list();

      expect(
        modelNames(metadata),
        containsAll(knownChatModels.map((id) => 'openai/$id')),
      );
    });

    test('the provider is invoked once per listing, not twice', () async {
      // list() checks for a key and then builds a client. Resolving twice
      // would double the cost for a provider that mints a token per call.
      var calls = 0;
      final requests = <String>[];
      final plugin = OpenAIPlugin(
        apiKeyProvider: () async {
          calls++;
          return 'minted-key';
        },
        httpClient: discoveryClient(requests, ids: ['gpt-4o']),
      );

      await plugin.list();

      expect(calls, 1);
    });

    test('init never asks for a key at all', () async {
      var calls = 0;
      final plugin = OpenAIPlugin(
        apiKeyProvider: () async {
          calls++;
          return 'minted-key';
        },
        httpClient: RecordingFailClient().client,
        customModels: [CustomModelDefinition(name: 'my-model')],
      );

      await plugin.init();

      expect(calls, 0, reason: 'startup must not need credentials');
    });
  });

  group('custom hosts', () {
    test('discovery is attempted against a custom baseUrl', () async {
      final requests = <String>[];
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'test-key',
        baseUrl: 'https://api.groq.test/openai/v1',
        httpClient: discoveryClient(requests, ids: ['llama-3.3-70b']),
      );

      final names = modelNames(await plugin.list());

      expect(
        requests.any((r) => r.contains('api.groq.test')),
        isTrue,
        reason: 'compatible hosts often do serve /models',
      );
      expect(names, contains('groq/llama-3.3-70b'));
    });

    test('a host without /models still lists its custom models', () async {
      final plugin = OpenAIPlugin(
        name: 'local',
        apiKey: 'test-key',
        baseUrl: 'http://127.0.0.1:9/v1',
        httpClient: MockClient(
          (request) async => http.Response('no such endpoint', 404),
        ),
        customModels: [CustomModelDefinition(name: 'my-local-model')],
      );

      final names = modelNames(await plugin.list());

      expect(names, {'local/my-local-model'});
      // The curated catalog is OpenAI's. A local llama.cpp-style host has no
      // gpt-4o, so listing 'local/gpt-4o' would only hand the Dev UI a 404.
      expect(names, isNot(contains('local/gpt-4o')));
    });
  });

  group('api key resolution', () {
    test('a missing key still fails at generate time', () async {
      // The startup requirement is gone; the call-time requirement stays.
      // Since #413, generate() reports a model error as a failed response
      // rather than throwing, so the requirement shows up there.
      final recorder = RecordingFailClient();
      final ai = Genkit(
        plugins: [OpenAIPlugin(httpClient: recorder.client, configVar: noEnv)],
      );

      final response = await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'hi',
      );

      expect(response.finishReason, FinishReason.failed);
      expect(response.error, isNotNull);
      expect(response.error!.status, StatusCodes.INVALID_ARGUMENT.name);
      expect(response.error!.message, contains('API key is required'));

      await ai.shutdown();
    });

    test('apiKeyProvider takes precedence over apiKey', () async {
      final seen = <String>[];
      final ai = Genkit(
        plugins: [
          openAI(
            apiKeyProvider: () async => 'from-provider',
            httpClient: MockClient((request) async {
              seen.add(request.headers['authorization'] ?? '');
              return http.Response(
                jsonEncode({
                  'id': 'x',
                  'object': 'chat.completion',
                  'created': 0,
                  'model': 'gpt-4o',
                  'choices': [
                    {
                      'index': 0,
                      'message': {'role': 'assistant', 'content': 'ok'},
                      'finish_reason': 'stop',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ],
      );

      await ai.generate(model: openAI.model('gpt-4o'), prompt: 'hi');

      expect(seen.single, 'Bearer from-provider');

      await ai.shutdown();
    });
  });
}
