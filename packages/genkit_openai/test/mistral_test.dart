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

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/known_mistral_models.dart';
import 'package:genkit_openai/src/known_models.dart' show multimodalSupports;
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:genkit_openai/src/provider.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'fake_openai_server.dart';
import 'recording_client.dart';

void main() {
  group('catalog', () {
    test('the exported collections cannot be mutated', () {
      expect(() => knownMistralChatModels.add('x'), throwsUnsupportedError);
      expect(
        () => knownMistralModels['x'] = knownMistralModels.values.first,
        throwsUnsupportedError,
      );
    });

    test('every curated model takes tools and a schema', () {
      // Mistral serves json_schema on every chat model, so `constrained` is
      // honest across the catalog, unlike DeepSeek's.
      for (final model in KnownMistralModel.values) {
        final supports = mistralModelInfoFor(model.id).supports!;
        expect(supports['tools'], isTrue, reason: model.id);
        expect(supports['constrained'], isTrue, reason: model.id);
      }
    });

    test('only Codestral is text only', () {
      for (final model in KnownMistralModel.values) {
        expect(
          model.supports['media'],
          model != KnownMistralModel.codestral,
          reason: model.id,
        );
      }
    });

    test('the Magistral models are not curated', () {
      // They answer with `thinking` chunks in a content array, which the
      // plugin does not read yet.
      expect(knownMistralModelFor('magistral-medium-latest'), isNull);
      expect(knownMistralModelFor('magistral-small-latest'), isNull);
    });

    test('lookup is case-insensitive', () {
      expect(
        knownMistralModelFor('Mistral-Small-Latest'),
        KnownMistralModel.mistralSmall,
      );
    });

    test('an uncurated name claims only what every Mistral model has', () {
      final info = mistralModelInfoFor('ministral-8b-latest');

      expect(info.label, isNull);
      expect(info.supports?['tools'], isTrue);
      expect(info.supports?['constrained'], isTrue);
      expect(info.supports?['media'], isFalse);
    });

    test('curated metadata is not mutable through the returned info', () {
      expect(
        () => mistralModelInfoFor('mistral-small-latest').supports!['tools'] =
            false,
        throwsUnsupportedError,
      );
    });
  });

  group('plugin wiring', () {
    test('dials Mistral without being told where it lives', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          mistral(apiKey: 'm-key', httpClient: recordingClient(requests)),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
      );

      expect(requests.single.url.host, 'api.mistral.ai');
      expect(requests.single.url.path, '/v1/chat/completions');
      expect(requests.single.headers['authorization'], 'Bearer m-key');
    });

    test('the versionless spelling still reaches /v1', () async {
      // Mistral publishes `/v1` only. Matching on the host makes
      // `https://api.mistral.ai` Mistral's own, so its URL goes on the wire
      // rather than the caller's, which would 404.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          mistral(
            apiKey: 'm-key',
            baseUrl: 'https://api.mistral.ai',
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
      );

      expect(requests.single.url.path, '/v1/chat/completions');
    });

    test('another host is dialled exactly as written', () async {
      // Nothing is canonicalised for a host we do not recognise: the caller's
      // gateway may well serve the path they gave.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          mistral(
            apiKey: 'm-key',
            baseUrl: 'https://gateway.test/mistral',
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
      );

      expect(requests.single.url.host, 'gateway.test');
      expect(requests.single.url.path, '/mistral/chat/completions');
    });

    test('reads MISTRAL_API_KEY, and says so when it is missing', () async {
      final requests = <http.Request>[];
      final fromEnv = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: mistralProvider,
            configVar: (name) => name == 'MISTRAL_API_KEY' ? 'from-env' : null,
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(fromEnv.shutdown);

      await fromEnv.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
      );

      expect(requests.single.headers['authorization'], 'Bearer from-env');

      final keyless = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: mistralProvider,
            configVar: (name) => name == 'OPENAI_API_KEY' ? 'openai-env' : null,
            httpClient: recordingClient([]),
          ),
        ],
      );
      addTearDown(keyless.shutdown);

      final response = await keyless.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
      );

      expect(response.finishReason, FinishReason.failed);
      expect(response.error?.message, contains('MISTRAL_API_KEY'));
      expect(response.error?.message, isNot(contains('OPENAI_API_KEY')));
    });

    test('lists its own catalog, not another provider\'s', () async {
      final plugin = OpenAIPlugin(
        provider: mistralProvider,
        apiKey: 'm-key',
        httpClient: recordingClient([], modelIds: ['mistral-small-latest']),
      );

      final metadata = await plugin.list();
      final models = metadata
          .where((m) => m.actionType == ActionType.model)
          .map((m) => m.name)
          .toSet();
      final embedders = metadata
          .where((m) => m.actionType == ActionType.embedder)
          .map((m) => m.name)
          .toSet();

      expect(models, contains('mistral/mistral-large-latest'));
      expect(models, contains('mistral/codestral-latest'));
      expect(models.any((n) => n.contains('gpt-')), isFalse);
      expect(models.any((n) => n.contains('tts')), isFalse);
      expect(models.any((n) => n.contains('whisper')), isFalse);
      expect(embedders, {'mistral/mistral-embed', 'mistral/codestral-embed'});
    });

    test('a gateway keeps the capabilities but not the deployment', () async {
      final plugin = OpenAIPlugin(
        provider: mistralProvider,
        apiKey: 'm-key',
        baseUrl: 'https://gateway.example/v1',
        httpClient: recordingClient([], modelIds: ['mistral-large-latest']),
      );

      final metadata = (await plugin.list()).single;
      final info = (metadata.metadata['model'] as Map).cast<String, dynamic>();

      expect(metadata.name, 'mistral/mistral-large-latest');
      expect(info['supports'], multimodalSupports);
      expect(info.containsKey('label'), isFalse);
      expect(info.containsKey('versions'), isFalse);
    });

    test('refuses an effort before the request goes out', () async {
      // A model that thinks answers with `thinking` chunks the plugin cannot
      // parse, so the effort is refused locally rather than spent on a reply
      // that fails.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(response.finishReason, FinishReason.failed);
      expect(
        response.error?.message,
        contains('mistral-small-latest does not accept reasoningEffort'),
      );
      expect(requests, isEmpty);
    });

    test('Magistral, Z.ai GLM and OCR are filtered out of discovery', () async {
      // Mistral lists them, so leaving them out of the curated catalog is not
      // enough: discovery would put them straight back. GLM answers with
      // thinking chunks whatever `reasoning_effort` says.
      final plugin = OpenAIPlugin(
        provider: mistralProvider,
        apiKey: 'm-key',
        httpClient: recordingClient(
          [],
          modelIds: [
            'mistral-small-latest',
            'magistral-medium-latest',
            'magistral-small-2509',
            'zai-glm-5-3',
            'zai-glm-5-3-flash',
            'mistral-ocr-latest',
          ],
        ),
      );

      final names = (await plugin.list()).map((m) => m.name).toSet();

      expect(names, contains('mistral/mistral-small-latest'));
      expect(names, isNot(contains('mistral/magistral-medium-latest')));
      expect(names, isNot(contains('mistral/magistral-small-2509')));
      expect(names, isNot(contains('mistral/zai-glm-5-3')));
      expect(names, isNot(contains('mistral/zai-glm-5-3-flash')));
      expect(names, isNot(contains('mistral/mistral-ocr-latest')));
    });

    test('a name it declines still resolves when asked for', () {
      final plugin = OpenAIPlugin(provider: mistralProvider, apiKey: 'm-key');

      expect(plugin.resolve(.model, 'magistral-medium-latest'), isNotNull);
    });
  });

  group('request dialect', () {
    Future<Map<String, dynamic>> bodyFor(OpenAIChatOptions config) async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        config: config,
      );
      return chatBodyOf(requests);
    }

    test('sends the seed as random_seed', () async {
      final body = await bodyFor(OpenAIChatOptions(seed: 42));

      expect(body['random_seed'], 42);
      expect(body, isNot(contains('seed')));
    });

    test('adds no random_seed when no seed was asked for', () async {
      final body = await bodyFor(OpenAIChatOptions(temperature: 0.2));

      expect(body, isNot(contains('random_seed')));
      expect(body['temperature'], 0.2);
    });

    test('sends max_tokens, never max_completion_tokens', () async {
      final body = await bodyFor(OpenAIChatOptions(maxTokens: 128));

      expect(body['max_tokens'], 128);
      expect(body, isNot(contains('max_completion_tokens')));
    });

    test('drops user, which Mistral does not define', () async {
      final body = await bodyFor(OpenAIChatOptions(user: 'end-user-1'));

      expect(body, isNot(contains('user')));
    });

    test('drops verbosity, which Mistral does not define', () async {
      final body = await bodyFor(OpenAIChatOptions(verbosity: 'low'));

      expect(body, isNot(contains('verbosity')));
    });

    test('drops stream_options on a stream', () async {
      // The plugin always asks for usage on a stream; Mistral's schema has no
      // stream_options and rejects the request outright.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: streamingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final stream = ai.generateStream(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        config: OpenAIChatOptions(seed: 7, user: 'u', maxTokens: 64),
      );
      await stream.drain<void>();

      final body = chatBodyOf(requests);
      expect(body['stream'], isTrue);
      expect(body, isNot(contains('stream_options')));
      expect(body, isNot(contains('user')));
      expect(body, isNot(contains('seed')));
      expect(body['random_seed'], 7);
      expect(body['max_tokens'], 64);
    });

    test('sends a JSON schema, which Mistral accepts', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'give me json',
        outputFormat: 'json',
        outputSchema: .string(),
      );

      final body = chatBodyOf(requests);
      final format = (body['response_format'] as Map).cast<String, dynamic>();
      expect(format['type'], 'json_schema');
      expect(body['messages'], hasLength(1));
    });

    test('tools and tool_choice go out unchanged', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'lookup',
        description: 'look something up',
        fn: (input, ctx) async => .response({'ok': true}),
      );

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        toolNames: ['lookup'],
        toolChoice: .required,
      );

      final body = chatBodyOf(requests);
      final tool = (body['tools'] as List).single as Map;
      expect((tool['function'] as Map)['name'], 'lookup');
      expect(body['tool_choice'], 'required');
    });

    test('the rewrite leaves every other field alone', () {
      final body = {
        'model': 'mistral-small-latest',
        'messages': const [],
        'temperature': 0.5,
        'seed': 1,
        'user': 'u',
        'verbosity': 'low',
        'stream': true,
        'stream_options': const {'include_usage': true},
      };

      expect(mistralChatBody(body), {
        'model': 'mistral-small-latest',
        'messages': const [],
        'temperature': 0.5,
        'stream': true,
        'random_seed': 1,
      });
    });

    test('OpenAI keeps its own spellings', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        prompt: 'hi',
        config: OpenAIChatOptions(
          seed: 3,
          user: 'u',
          maxTokens: 10,
          verbosity: 'low',
        ),
      );

      final body = chatBodyOf(requests);
      expect(body['seed'], 3);
      expect(body['user'], 'u');
      expect(body['verbosity'], 'low');
      expect(body['max_completion_tokens'], 10);
      expect(body, isNot(contains('random_seed')));
    });
  });

  group('against the fake server', () {
    // Every test above hands the plugin an httpClient. These let it build its
    // own, which is the client real users get and the one the body rewrite
    // has to wrap.
    late FakeOpenAIServer server;

    setUp(() async {
      server = await FakeOpenAIServer.start(expectedApiKey: 'm-key');
      addTearDown(server.stop);
    });

    test('a buffered call reaches the wire in Mistral\'s dialect', () async {
      server.enqueue(FakeResponse.json(chatCompletion(content: 'bonjour')));
      final ai = Genkit(
        plugins: [mistral(apiKey: 'm-key', baseUrl: server.baseUrl)],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        config: OpenAIChatOptions(seed: 42, user: 'u', maxTokens: 64),
      );

      expect(response.text, 'bonjour');
      expect(server.requests.single.path, '/v1/chat/completions');
      final body = server.chatRequestBodies.single;
      expect(body['random_seed'], 42);
      expect(body['max_tokens'], 64);
      expect(body, isNot(contains('seed')));
      expect(body, isNot(contains('user')));
      expect(body, isNot(contains('max_completion_tokens')));
      // A stale content-length from the original body would truncate this.
      expect(body['messages'], hasLength(1));
    });

    test('a stream reaches the wire without stream_options', () async {
      server.enqueue(
        FakeResponse.sse([
          chatChunk(content: 'Bon'),
          chatChunk(content: 'jour'),
          chatChunk(finishReason: 'stop'),
        ]),
      );
      final ai = Genkit(
        plugins: [mistral(apiKey: 'm-key', baseUrl: server.baseUrl)],
      );
      addTearDown(ai.shutdown);

      final streamed = StringBuffer();
      final stream = ai.generateStream(
        model: mistral.model('mistral-small-latest'),
        prompt: 'hi',
        config: OpenAIChatOptions(seed: 7),
      );
      await for (final chunk in stream) {
        for (final part in chunk.content) {
          if (part.isText) streamed.write(part.text);
        }
      }

      expect(streamed.toString(), 'Bonjour');
      expect((await stream.onResult).text, 'Bonjour');
      final body = server.chatRequestBodies.single;
      expect(body['stream'], isTrue);
      expect(body, isNot(contains('stream_options')));
      expect(body['random_seed'], 7);
    });

    test('embeds through /v1/embeddings', () async {
      server.enqueue(
        FakeResponse.json({
          'object': 'list',
          'model': 'mistral-embed',
          'data': [
            {
              'object': 'embedding',
              'index': 0,
              'embedding': [0.1, 0.2, 0.3],
            },
          ],
          'usage': {'prompt_tokens': 1, 'total_tokens': 1},
        }),
      );
      final ai = Genkit(
        plugins: [mistral(apiKey: 'm-key', baseUrl: server.baseUrl)],
      );
      addTearDown(ai.shutdown);

      final embeddings = await ai.embed(
        embedder: mistral.embedder('mistral-embed'),
        document: DocumentData(content: [TextPart(text: 'hello')]),
      );

      expect(embeddings.single.embedding, [0.1, 0.2, 0.3]);
      final request = server.requests.single;
      expect(request.path, '/v1/embeddings');
      expect(request.body['model'], 'mistral-embed');
      expect(request.body, isNot(contains('dimensions')));
    });
  });
}
