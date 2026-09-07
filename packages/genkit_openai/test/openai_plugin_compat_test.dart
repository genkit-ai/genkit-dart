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

/// Coverage for the OpenAI-compatible path: `baseUrl`, `headers`, and
/// `CustomModelDefinition`.
///
/// The README advertises Groq, xAI, DeepSeek and Together AI, but nothing
/// tested that a `baseUrl` was ever dialed. These tests run the plugin against
/// a real loopback host with no injected `httpClient`, so they exercise the
/// client the plugin builds for itself - the same one a compat user gets.
library;

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/known_models.dart' show knownChatModels;
import 'package:genkit_openai/src/openai_plugin.dart' show OpenAIPlugin;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fake_openai_server.dart';

Set<String> modelNames(List<ActionMetadata> metadata) =>
    metadata.map((m) => m.name).toSet();

/// A Groq-shaped model definition, matching the README's example.
CustomModelDefinition llama() => CustomModelDefinition(
  name: 'llama-3.3-70b-versatile',
  info: ModelInfo(
    label: 'Llama 3.3 70B',
    supports: {'multiturn': true, 'tools': true, 'systemRole': true},
  ),
);

void main() {
  late FakeOpenAIServer server;

  Future<FakeOpenAIServer> startServer({String? expectedApiKey}) async {
    final started = await FakeOpenAIServer.start(
      expectedApiKey: expectedApiKey,
    );
    addTearDown(started.stop);
    return started;
  }

  group('baseUrl routing', () {
    setUp(() async {
      server = await startServer();
    });

    test('generate reaches the compat host, not api.openai.com', () async {
      server.enqueue(FakeResponse.json(chatCompletion(content: 'from groq')));
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'groq',
            apiKey: 'groq-key',
            baseUrl: server.baseUrl,
            models: [llama()],
          ),
        ],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'Hello!',
      );

      expect(response.text, 'from groq');
      expect(server.requests, hasLength(1));
      expect(server.requests.single.method, 'POST');
      expect(server.requests.single.path, '/v1/chat/completions');
    });

    test('the custom model id is what goes on the wire', () async {
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'groq',
            apiKey: 'groq-key',
            baseUrl: server.baseUrl,
            models: [llama()],
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'Hello!',
      );

      expect(
        server.chatRequestBodies.single['model'],
        'llama-3.3-70b-versatile',
      );
    });

    test('a model the host never advertised still resolves', () async {
      // Compat hosts often serve no /models at all, and their catalogs move
      // faster than this plugin releases. resolve() must not gate on discovery.
      final ai = Genkit(
        plugins: [
          openAI(name: 'deepseek', apiKey: 'ds-key', baseUrl: server.baseUrl),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('deepseek-reasoner', namespace: 'deepseek'),
        prompt: 'Hello!',
      );

      expect(server.chatRequestBodies.single['model'], 'deepseek-reasoner');
    });

    test('streaming works against a compat host', () async {
      server.enqueue(
        FakeResponse.sse([
          chatChunk(content: 'Hel'),
          chatChunk(content: 'lo'),
          chatChunk(finishReason: 'stop'),
        ]),
      );
      final ai = Genkit(
        plugins: [
          openAI(name: 'xai', apiKey: 'xai-key', baseUrl: server.baseUrl),
        ],
      );
      addTearDown(ai.shutdown);

      final streamed = StringBuffer();
      final stream = ai.generateStream(
        model: openAI.model('grok-4', namespace: 'xai'),
        prompt: 'Say hello',
      );
      await for (final chunk in stream) {
        for (final part in chunk.content) {
          if (part.isText) streamed.write(part.text);
        }
      }

      expect(streamed.toString(), 'Hello');
      expect((await stream.onResult).text, 'Hello');
      expect(server.chatRequestBodies.single['stream'], true);
    });

    test('a tool call round-trips through a compat host', () async {
      // Tool calling is where compatible hosts diverge most, and the README's
      // Groq example advertises `'tools': true`. Two exchanges: the host asks
      // for the tool, then sees the result come back as a `tool` message.
      server.enqueue(
        FakeResponse.json(
          chatCompletion(
            content: '',
            finishReason: 'tool_calls',
            toolCalls: [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {
                  'name': 'getWeather',
                  'arguments': '{"location":"Boston"}',
                },
              },
            ],
          ),
        ),
      );
      server.enqueue(
        FakeResponse.json(
          chatCompletion(
            content: 'It is 72F in Boston.',
            usage: {
              'prompt_tokens': 11,
              'completion_tokens': 7,
              'total_tokens': 18,
            },
          ),
        ),
      );

      final ai = Genkit(
        plugins: [
          openAI(
            name: 'groq',
            apiKey: 'groq-key',
            baseUrl: server.baseUrl,
            models: [llama()],
          ),
        ],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'getWeather',
        description: 'Get the weather for a location',
        fn: (input, ctx) async => .response({'temperature': 72}),
      );

      final response = await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'What is the weather in Boston?',
        toolNames: ['getWeather'],
      );

      expect(response.text, 'It is 72F in Boston.');
      expect(response.usage?.inputTokens, 11);
      expect(response.usage?.outputTokens, 7);

      final bodies = server.chatRequestBodies;
      expect(bodies, hasLength(2), reason: 'one call out, one result back');
      final tools = (bodies.first['tools'] as List)
          .cast<Map<String, dynamic>>();
      final function = tools.single['function'] as Map<String, dynamic>;
      expect(function['name'], 'getWeather');
      // The second turn must carry the tool result the host asked for.
      final followUpRoles = (bodies[1]['messages'] as List)
          .cast<Map<String, dynamic>>()
          .map((m) => m['role'])
          .toList();
      expect(followUpRoles, contains('tool'));
    });

    test('a stream with no [DONE] sentinel still completes', () async {
      // Not every compatible host terminates the stream the way OpenAI does;
      // some just close the socket. Written with rawSse so the frames are
      // verbatim - the chunks helper always appends [DONE].
      server.enqueue(
        FakeResponse(
          stream: true,
          rawSse: [
            'data: ${jsonEncode(chatChunk(content: 'par'))}\n\n',
            'data: ${jsonEncode(chatChunk(content: 'tial'))}\n\n',
            'data: ${jsonEncode(chatChunk(finishReason: 'stop'))}\n\n',
          ],
        ),
      );
      final ai = Genkit(
        plugins: [
          openAI(name: 'xai', apiKey: 'xai-key', baseUrl: server.baseUrl),
        ],
      );
      addTearDown(ai.shutdown);

      final stream = ai.generateStream(
        model: openAI.model('grok-4', namespace: 'xai'),
        prompt: 'Say hello',
      );
      await stream.drain<void>();

      expect((await stream.onResult).text, 'partial');
    });
  });

  group('authentication against a compat host', () {
    test('the configured key is sent as a bearer token', () async {
      server = await startServer(expectedApiKey: 'groq-key');
      final ai = Genkit(
        plugins: [
          openAI(name: 'groq', apiKey: 'groq-key', baseUrl: server.baseUrl),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'Hello!',
      );

      expect(
        server.requests.single.headers['authorization'],
        'Bearer groq-key',
      );
    });

    test('apiKeyProvider is honored on the compat path', () async {
      server = await startServer(expectedApiKey: 'minted-token');
      var calls = 0;
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'groq',
            apiKeyProvider: () async {
              calls++;
              return 'minted-token';
            },
            baseUrl: server.baseUrl,
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'Hello!',
      );

      expect(calls, 1);
      expect(
        server.requests.single.headers['authorization'],
        'Bearer minted-token',
      );
    });

    test('a rejected key surfaces as UNAUTHENTICATED', () async {
      server = await startServer(expectedApiKey: 'right-key');
      final ai = Genkit(
        plugins: [
          openAI(name: 'groq', apiKey: 'wrong-key', baseUrl: server.baseUrl),
        ],
      );
      addTearDown(ai.shutdown);

      await expectLater(
        ai.generate(
          model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
          prompt: 'Hello!',
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.UNAUTHENTICATED)
              .having(
                (e) => e.toString(),
                'message',
                contains('Incorrect API key provided'),
              ),
        ),
      );
    });
  });

  group('custom headers', () {
    setUp(() async {
      server = await startServer();
    });

    test('reach the compat host on generate', () async {
      final ai = Genkit(
        plugins: [
          openAI(
            name: 'openrouter',
            apiKey: 'or-key',
            baseUrl: server.baseUrl,
            headers: {
              'HTTP-Referer': 'https://example.com',
              'X-Title': 'Genkit Dart',
            },
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('gpt-4o', namespace: 'openrouter'),
        prompt: 'Hello!',
      );

      final headers = server.requests.single.headers;
      expect(headers['http-referer'], 'https://example.com');
      expect(headers['x-title'], 'Genkit Dart');
      // The SDK's own auth header must survive alongside them.
      expect(headers['authorization'], 'Bearer or-key');
    });

    test('reach the compat host on model discovery', () async {
      final plugin = OpenAIPlugin(
        name: 'openrouter',
        apiKey: 'or-key',
        baseUrl: server.baseUrl,
        headers: {'X-Title': 'Genkit Dart'},
      );

      await plugin.list();

      expect(server.requests.single.path, '/v1/models');
      expect(server.requests.single.headers['x-title'], 'Genkit Dart');
    });
  });

  group('CustomModelDefinition', () {
    setUp(() async {
      server = await startServer();
    });

    test('is registered by init(), before any discovery', () async {
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: server.baseUrl,
        customModels: [llama()],
      );

      final actions = await plugin.init();

      expect(actions.map((a) => a.name), ['groq/llama-3.3-70b-versatile']);
      expect(
        server.requests,
        isEmpty,
        reason: 'init() must not touch the compat host either',
      );
    });

    test('its ModelInfo overrides the id-based heuristics', () async {
      // 'llama-3.3-70b-versatile' matches no OpenAI naming rule, so without
      // the override the listing would describe it by guesswork.
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: server.baseUrl,
        customModels: [llama()],
      );

      final metadata = await plugin.list();
      final llamaMeta = metadata.singleWhere(
        (m) => m.name == 'groq/llama-3.3-70b-versatile',
      );

      final info = llamaMeta.metadata['model'] as Map<String, dynamic>;
      expect(info['label'], 'Llama 3.3 70B');
      expect((info['supports'] as Map)['tools'], true);
    });

    test('is listed even when the host serves no /models', () async {
      server.enqueue(FakeResponse.error(404, 'Not Found'));
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: server.baseUrl,
        customModels: [llama()],
      );

      final names = modelNames(await plugin.list());

      expect(names, contains('groq/llama-3.3-70b-versatile'));
    });

    test('is listed alongside models the host does advertise', () async {
      server.enqueue(
        FakeResponse.json(modelList(['llama-3.1-8b-instant', 'gemma2-9b-it'])),
      );
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: server.baseUrl,
        customModels: [llama()],
      );

      final names = modelNames(await plugin.list());

      expect(
        names,
        containsAll([
          'groq/llama-3.3-70b-versatile',
          'groq/llama-3.1-8b-instant',
          'groq/gemma2-9b-it',
        ]),
      );
    });

    test('listing is namespaced by the plugin name', () async {
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: server.baseUrl,
        customModels: [llama()],
      );

      final names = modelNames(await plugin.list());

      expect(names.every((n) => n.startsWith('groq/')), isTrue);
      expect(names, isNot(contains('openai/gpt-4o')));
    });
  });

  group('multiple backends side by side', () {
    test('each plugin dials its own host with its own key', () async {
      final groq = await startServer(expectedApiKey: 'groq-key');
      final deepseek = await startServer(expectedApiKey: 'ds-key');
      groq.enqueue(FakeResponse.json(chatCompletion(content: 'from groq')));
      deepseek.enqueue(
        FakeResponse.json(chatCompletion(content: 'from deepseek')),
      );

      final ai = Genkit(
        plugins: [
          openAI(
            name: 'groq',
            apiKey: 'groq-key',
            baseUrl: groq.baseUrl,
            models: [llama()],
          ),
          openAI(
            name: 'deepseek',
            apiKey: 'ds-key',
            baseUrl: deepseek.baseUrl,
            models: [CustomModelDefinition(name: 'deepseek-chat')],
          ),
        ],
      );
      addTearDown(ai.shutdown);

      final a = await ai.generate(
        model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
        prompt: 'Hello!',
      );
      final b = await ai.generate(
        model: openAI.model('deepseek-chat', namespace: 'deepseek'),
        prompt: 'Hello!',
      );

      expect(a.text, 'from groq');
      expect(b.text, 'from deepseek');
      expect(groq.requests, hasLength(1));
      expect(deepseek.requests, hasLength(1));
      expect(groq.chatRequestBodies.single['model'], 'llama-3.3-70b-versatile');
      expect(deepseek.chatRequestBodies.single['model'], 'deepseek-chat');
    });

    test('a compat backend never claims the openai namespace', () async {
      final compat = await startServer();
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: compat.baseUrl,
        customModels: [llama()],
      );

      final names = modelNames(await plugin.list());

      expect(names.every((n) => n.startsWith('groq/')), isTrue);
    });

    test('a compat backend does not list the curated OpenAI catalog', () async {
      // Regression: list() merged the curated catalog in unconditionally, so
      // a Groq backend advertised 'groq/gpt-5.5', 'groq/o3' and fifteen more
      // models Groq has never served - all of them a 404 from the Dev UI.
      final compat = await startServer();
      compat.enqueue(FakeResponse.json(modelList(['llama-3.1-8b-instant'])));
      final plugin = OpenAIPlugin(
        name: 'groq',
        apiKey: 'groq-key',
        baseUrl: compat.baseUrl,
        customModels: [llama()],
      );

      final names = modelNames(await plugin.list());

      expect(names, {
        'groq/llama-3.1-8b-instant',
        'groq/llama-3.3-70b-versatile',
      });
      for (final curated in knownChatModels) {
        expect(names, isNot(contains('groq/$curated')));
      }
    });

    test('the default OpenAI backend still gets the curated catalog', () async {
      // The counterpart to the test above: withholding the catalog from compat
      // backends must not withhold it from the backend it was written for.
      //
      // This is the one test here that injects a client - with no baseUrl to
      // redirect it, the real api.openai.com is the alternative, and a test
      // suite must not dial the internet.
      final plugin = OpenAIPlugin(
        apiKey: 'test-key',
        httpClient: MockClient(
          (_) async => http.Response('{"error":{"message":"nope"}}', 401),
        ),
      );

      final names = modelNames(await plugin.list());

      expect(names, containsAll(knownChatModels.map((id) => 'openai/$id')));
    });
  });

  group('compat host errors map to Genkit statuses', () {
    const cases = <int, StatusCodes>{
      400: StatusCodes.INVALID_ARGUMENT,
      401: StatusCodes.UNAUTHENTICATED,
      403: StatusCodes.PERMISSION_DENIED,
      404: StatusCodes.NOT_FOUND,
      500: StatusCodes.INTERNAL,
    };

    cases.forEach((statusCode, expected) {
      test('$statusCode becomes ${expected.name}', () async {
        // 429 is deliberately absent: the SDK retries it with exponential
        // backoff, which would add ~7s to this suite for one assertion.
        final host = await startServer();
        host.enqueue(FakeResponse.error(statusCode, 'compat host said no'));
        final ai = Genkit(
          plugins: [
            openAI(name: 'groq', apiKey: 'groq-key', baseUrl: host.baseUrl),
          ],
        );
        addTearDown(ai.shutdown);

        await expectLater(
          ai.generate(
            model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
            prompt: 'Hello!',
          ),
          throwsA(
            isA<GenkitException>().having((e) => e.status, 'status', expected),
          ),
        );
      });
    });

    test('an unreachable host fails at generate, not at startup', () async {
      final dead = await FakeOpenAIServer.start();
      final baseUrl = dead.baseUrl;
      await dead.stop();

      final ai = Genkit(
        plugins: [openAI(name: 'groq', apiKey: 'groq-key', baseUrl: baseUrl)],
      );
      addTearDown(ai.shutdown);

      // Startup and listing survive a host that is not there at all. This
      // takes ~7s: discovery is a GET, so the SDK retries the refused
      // connection three times with exponential backoff before list() gives
      // up and falls back to the catalog. That is the whole test - do not
      // "speed it up" by dropping the listActions() call.
      final actions = await ai.registry.listActions();
      expect(actions, isNotEmpty);

      await expectLater(
        ai.generate(
          model: openAI.model('llama-3.3-70b-versatile', namespace: 'groq'),
          prompt: 'Hello!',
        ),
        throwsA(isA<GenkitException>()),
      );
    });
  });
}
