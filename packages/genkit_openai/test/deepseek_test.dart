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
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:genkit_openai/src/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

import 'fake_openai_server.dart';

part 'deepseek_test.g.dart';

/// A trivial output schema, for the response-format assertions.
@Schema()
abstract class $JsonOut {
  String get name;
}

/// Records every request the plugin sends and answers with a canned reply.
MockClient recordingClient(
  List<http.Request> requests, {
  List<String> modelIds = const [],
}) {
  return MockClient((request) async {
    requests.add(request);
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            for (final id in modelIds)
              {'id': id, 'object': 'model', 'created': 0, 'owned_by': 'x'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({
        'id': 'chatcmpl-test',
        'object': 'chat.completion',
        'created': 0,
        'model': 'deepseek-flash',
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
  });
}

/// Answers a streaming chat request with a single SSE frame.
MockClient streamingClient(List<http.Request> requests) {
  return MockClient((request) async {
    requests.add(request);
    final frame = jsonEncode({
      'id': 'c',
      'object': 'chat.completion.chunk',
      'created': 0,
      'model': 'deepseek-flash',
      'choices': [
        {
          'index': 0,
          'delta': {'content': 'ok'},
          'finish_reason': 'stop',
        },
      ],
    });
    return http.Response(
      'data: $frame\n\ndata: [DONE]\n\n',
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  });
}

Map<String, dynamic> chatBodyOf(List<http.Request> requests) =>
    (jsonDecode(
              requests
                  .firstWhere((r) => r.url.path.endsWith('/chat/completions'))
                  .body,
            )
            as Map)
        .cast<String, dynamic>();

String? noEnv(String name) => null;

void main() {
  group('catalog', () {
    test('the exported collections cannot be mutated', () {
      expect(() => knownDeepSeekChatModels.add('x'), throwsUnsupportedError);
      expect(
        () => knownDeepSeekModels['x'] = knownDeepSeekModels.values.first,
        throwsUnsupportedError,
      );
    });

    test('no DeepSeek model claims constrained generation', () {
      // DeepSeek takes `json_object` but never a schema, so nothing in this
      // catalog may advertise constrained output.
      for (final model in KnownDeepSeekModel.values) {
        expect(
          model.supports.containsKey('constrained'),
          isFalse,
          reason: model.id,
        );
        expect(model.supports['output'], ['text', 'json'], reason: model.id);
      }
    });

    test('only the Flash line takes image input', () {
      expect(deepSeekModelInfoFor('deepseek-flash').supports?['media'], isTrue);
      expect(
        deepSeekModelInfoFor('deepseek-v4-pro').supports?['media'],
        isFalse,
      );
    });

    test('the routing aliases resolve to Flash', () {
      for (final alias in [
        'deepseek-v4-flash',
        'deepseek-v4-flash-vision-exp',
      ]) {
        expect(
          knownDeepSeekModelFor(alias),
          KnownDeepSeekModel.deepseekFlash,
          reason: alias,
        );
      }
    });

    test('the announced names are legacy, and still listed', () {
      // Discontinuation announced for 2026-07-24, but both still answer,
      // routed to Flash. `legacy` is exactly that state - served, with a
      // shutdown announced - so they stay in the listing until the names stop
      // answering.
      for (final id in ['deepseek-chat', 'deepseek-reasoner']) {
        final model = knownDeepSeekModelFor(id);
        expect(model, isNotNull, reason: id);
        expect(model!.stage, OpenAIModelStage.legacy, reason: id);
        expect(knownDeepSeekChatModels, contains(id), reason: id);
      }
    });

    test('lookup is case-insensitive', () {
      expect(
        knownDeepSeekModelFor('DeepSeek-Flash'),
        KnownDeepSeekModel.deepseekFlash,
      );
    });

    test('an uncurated name claims only what every DeepSeek model has', () {
      final info = deepSeekModelInfoFor('deepseek-v5-something');

      expect(info.supports?['tools'], isTrue);
      expect(info.supports?['media'], isFalse);
      expect(info.supports?.containsKey('constrained'), isFalse);
      expect(info.label, isNull);
    });

    test('curated metadata is not mutable through the returned info', () {
      expect(
        () => deepSeekModelInfoFor('deepseek-flash').supports!['tools'] = false,
        throwsUnsupportedError,
      );
    });

    test('typed refs cover the catalog', () {
      // Every curated entry, including the retired aliases: they are still
      // resolvable, they are only kept out of the listing.
      expect(
        DeepSeekModels.all.map((r) => r.name).toSet(),
        KnownDeepSeekModel.values.map((m) => 'deepseek/${m.id}').toSet(),
      );
      expect(
        knownDeepSeekChatModels.map((id) => 'deepseek/$id').toSet(),
        everyElement(isIn(DeepSeekModels.all.map((r) => r.name))),
      );
      expect(DeepSeekModels.deepseekFlash.name, 'deepseek/deepseek-flash');
    });
  });

  group('plugin wiring', () {
    test('dials DeepSeek without being told where it lives', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          deepSeek(apiKey: 'ds-key', httpClient: recordingClient(requests)),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(model: DeepSeekModels.deepseekFlash, prompt: 'hi');

      expect(requests.single.url.host, 'api.deepseek.com');
      expect(requests.single.headers['authorization'], 'Bearer ds-key');
    });

    test('reads DEEPSEEK_API_KEY, and says so when it is missing', () async {
      // The key has to reach the wire, not merely be read: asserting the
      // plugin's name here would pass with any env var spelling, since the
      // name comes from the provider's namespace rather than from configVar.
      final requests = <http.Request>[];
      final fromEnv = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: deepSeekProvider,
            configVar: (name) => name == 'DEEPSEEK_API_KEY' ? 'from-env' : null,
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(fromEnv.shutdown);

      await fromEnv.generate(model: DeepSeekModels.deepseekFlash, prompt: 'hi');

      expect(requests.single.headers['authorization'], 'Bearer from-env');

      // And nothing else answers for it: OPENAI_API_KEY set, DEEPSEEK_API_KEY
      // not, is a keyless plugin.
      final wrongVar = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: deepSeekProvider,
            configVar: (name) => name == 'OPENAI_API_KEY' ? 'openai-env' : null,
            httpClient: recordingClient([]),
          ),
        ],
      );
      addTearDown(wrongVar.shutdown);

      final wrong = await wrongVar.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'hi',
      );
      expect(wrong.finishReason, FinishReason.failed);

      final keyless = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: deepSeekProvider,
            configVar: noEnv,
            httpClient: recordingClient([]),
          ),
        ],
      );
      addTearDown(keyless.shutdown);

      final response = await keyless.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'hi',
      );

      expect(response.finishReason, FinishReason.failed);
      expect(response.error?.message, contains('DEEPSEEK_API_KEY'));
      expect(response.error?.message, isNot(contains('OPENAI_API_KEY')));
    });

    test('offers no audio models, having no audio API', () async {
      // The catalogs are the provider's, so a DeepSeek plugin must not list
      // OpenAI's tts and whisper ids - nor route a name that merely reads like
      // one to an endpoint api.deepseek.com does not serve.
      final plugin = OpenAIPlugin(
        provider: deepSeekProvider,
        apiKey: 'ds-key',
        httpClient: recordingClient([], modelIds: ['deepseek-flash']),
      );

      final names = (await plugin.list())
          .where((m) => m.actionType == ActionType.model)
          .map((m) => m.name)
          .toSet();
      expect(names.any((n) => n.contains('tts')), isFalse);
      expect(names.any((n) => n.contains('whisper')), isFalse);

      final action = plugin.resolve(.model, 'whisper-1');
      expect(
        (action!.metadata['model'] as Map)['supports'],
        isNot(containsPair('media', true)),
        reason: 'routed to transcription on a host without one',
      );
    });

    test('lists its own catalog, not OpenAI\'s', () async {
      final plugin = OpenAIPlugin(
        provider: deepSeekProvider,
        apiKey: 'ds-key',
        httpClient: recordingClient([], modelIds: ['deepseek-flash']),
      );

      final names = (await plugin.list())
          .where((m) => m.actionType == ActionType.model)
          .map((m) => m.name)
          .toSet();

      expect(names, contains('deepseek/deepseek-flash'));
      expect(names, contains('deepseek/deepseek-v4-pro'));
      expect(names.any((n) => n.contains('gpt-')), isFalse);
    });

    test('another spelling of the same host is still the same host', () async {
      // DeepSeek documents both `https://api.deepseek.com` and `.../v1`, and
      // this repo's own sample used the second. Treating it as a foreign
      // gateway would silently drop the catalog, the labels and the per-model
      // checks for someone who copied the URL out of DeepSeek's docs.
      for (final baseUrl in [
        'https://api.deepseek.com/v1',
        'https://api.deepseek.com/',
        'https://API.deepseek.com',
      ]) {
        final plugin = OpenAIPlugin(
          provider: deepSeekProvider,
          apiKey: 'ds-key',
          baseUrl: baseUrl,
          httpClient: recordingClient([]),
        );

        final names = (await plugin.list()).map((m) => m.name).toSet();
        expect(names, contains('deepseek/deepseek-flash'), reason: baseUrl);
      }
    });

    test('a gateway keeps the capabilities but not the deployment', () async {
      final plugin = OpenAIPlugin(
        provider: deepSeekProvider,
        apiKey: 'ds-key',
        baseUrl: 'https://gateway.example/v1',
        httpClient: recordingClient([], modelIds: ['deepseek-flash']),
      );

      final metadata = (await plugin.list()).single;
      final info = (metadata.metadata['model'] as Map).cast<String, dynamic>();

      // The curated catalog is withheld from a host that is not DeepSeek, the
      // same way OpenAI's is - only what /models reported is listed.
      expect(metadata.name, 'deepseek/deepseek-flash');
      expect(info['supports'], deepSeekVisionSupports);
      expect(info.containsKey('stage'), isFalse);
      expect(info.containsKey('versions'), isFalse);
    });

    test('openAI is untouched by any of this', () async {
      final plugin = OpenAIPlugin(apiKey: 'k', httpClient: recordingClient([]));

      expect(plugin.name, 'openai');
      expect(plugin.baseUrl, isNull);
      expect(plugin.provider.apiKeyEnvVar, 'OPENAI_API_KEY');
    });
  });

  group('reasoning', () {
    test('replays previous thinking when the request carries tools', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'lookup',
        description: 'look something up',
        fn: (input, ctx) async => .response({'ok': true}),
      );

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'first I considered'),
              TextPart(text: 'an answer'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'go on')],
          ),
        ],
        toolNames: ['lookup'],
      );

      final sent = (chatBodyOf(requests)['messages'] as List)
          .cast<Map<String, dynamic>>();
      final assistant = sent.firstWhere((m) => m['role'] == 'assistant');
      expect(assistant['reasoning_content'], 'first I considered');
    });

    test('sends no reasoning when there are no tools', () async {
      // DeepSeek ignores it in that case, and it is not a field OpenAI ever
      // asked for, so it stays off the wire.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'thinking'),
              TextPart(text: 'answer'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'go on')],
          ),
        ],
      );

      final sent = (chatBodyOf(requests)['messages'] as List)
          .cast<Map<String, dynamic>>();
      final assistant = sent.firstWhere((m) => m['role'] == 'assistant');
      expect(assistant, isNot(contains('reasoning_content')));
    });

    test('sends a level DeepSeek has no native setting for', () async {
      // The reference maps them rather than refusing them: `minimal` runs as
      // `low`, `medium` and `xhigh` as `high`. Refusing here would fail a
      // request the host would have served.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      for (final effort in ['minimal', 'medium', 'xhigh']) {
        requests.clear();
        await ai.generate(
          model: DeepSeekModels.deepseekFlash,
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: effort),
        );

        final body = chatBodyOf(requests);
        expect(body['reasoning_effort'], effort);
        expect(body['thinking'], {'type': 'enabled'});
      }
    });

    test('sends the effort and the thinking toggle together', () async {
      // The vendor's own OpenAI-format samples pass `reasoning_effort` at the
      // top level alongside the `thinking` object, so both go out: the effort
      // where every host reads it, the toggle to say which mode it applies to.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      for (final effort in ['low', 'high', 'max']) {
        requests.clear();
        await ai.generate(
          model: DeepSeekModels.deepseekFlash,
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: effort),
        );

        final body = chatBodyOf(requests);
        expect(body['reasoning_effort'], effort);
        expect(body['thinking'], {'type': 'enabled'});
      }
    });

    test('none turns thinking off, which is what it means there', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'none'),
      );

      final body = chatBodyOf(requests);
      expect(body['thinking'], {'type': 'disabled'});
      // Nothing to spend an effort on once thinking is off.
      expect(body, isNot(contains('reasoning_effort')));
    });

    test('says nothing about thinking when nothing was asked', () async {
      // Thinking is on by default for the models that have it; spelling that
      // out would only risk disagreeing with the default later.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(model: DeepSeekModels.deepseekFlash, prompt: 'hi');

      expect(chatBodyOf(requests), isNot(contains('thinking')));
    });

    test('the rewrite survives the streaming path too', () async {
      // Buffered and streamed calls build the request separately; both go
      // through the same transport, and this is the only thing that says so.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: streamingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final stream = ai.generateStream(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'max'),
      );
      await stream.drain<void>();

      final body = chatBodyOf(requests);
      expect(body['reasoning_effort'], 'max');
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['stream'], isTrue);
    });

    test('OpenAI keeps reasoning_effort at the top level', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.o4Mini,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'medium'),
      );

      final body = chatBodyOf(requests);
      expect(body['reasoning_effort'], 'medium');
      expect(body, isNot(contains('thinking')));
    });

    test('the non-thinking alias takes none', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: DeepSeekModels.deepseekChat,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'none'),
      );

      expect(response.finishReason, isNot(FinishReason.failed));
      expect(chatBodyOf(requests)['thinking'], {'type': 'disabled'});
    });

    test('the non-thinking alias takes an effort too', () async {
      // Thinking is a request-time mode on DeepSeek, not a property of the
      // name: `deepseek-chat` is Flash with thinking off by default, and it
      // answers `high` with reasoning tokens. Refusing locally would fail a
      // request the host serves.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: DeepSeekModels.deepseekChat,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(response.finishReason, isNot(FinishReason.failed));
      final body = chatBodyOf(requests);
      expect(body['reasoning_effort'], 'high');
      expect(body['thinking'], {'type': 'enabled'});
    });
  });

  group('the self-built transport', () {
    test('rewrites over a real socket, with no client injected', () async {
      // Every other test here hands the plugin an httpClient, so the client
      // it builds for itself - the one real users get, and the one the body
      // rewriting now has to wrap - would otherwise never run.
      final server = await FakeOpenAIServer.start(expectedApiKey: 'ds-key');
      addTearDown(server.stop);
      server.enqueue(
        FakeResponse.json(chatCompletion(content: 'thought it through')),
      );

      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'ds-key', baseUrl: server.baseUrl)],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: deepSeek.model('deepseek-flash'),
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high', maxTokens: 64),
      );

      expect(response.text, 'thought it through');
      final body = server.chatRequestBodies.single;
      expect(body['reasoning_effort'], 'high');
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['max_tokens'], 64);
      // The rewritten request must still carry a usable content-length; a
      // stale one from the original would truncate the body.
      expect(body['messages'], hasLength(1));
    });
  });

  group('request dialect', () {
    test('sends max_tokens, which is the field DeepSeek reads', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'hi',
        config: OpenAIChatOptions(maxTokens: 256),
      );

      final body = chatBodyOf(requests);
      expect(body['max_tokens'], 256);
      expect(
        body,
        isNot(contains('max_completion_tokens')),
        reason: 'DeepSeek ignores it silently, so the limit would be lost',
      );
    });

    test('OpenAI still gets max_completion_tokens', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'hi',
        config: OpenAIChatOptions(maxTokens: 256),
      );

      final body = chatBodyOf(requests);
      expect(body['max_completion_tokens'], 256);
      expect(body, isNot(contains('max_tokens')));
    });

    test('asks for json_object, since DeepSeek takes no schema', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'give me json',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      expect(chatBodyOf(requests)['response_format'], {'type': 'json_object'});
    });

    test('asks for json_object even with no schema at all', () async {
      // The prompt hint and the response format are set independently; a
      // schemaless JSON request used to get the hint but stay in free-text
      // mode on the wire, which is the worst of both.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'give me an object',
        outputFormat: 'json',
      );

      expect(chatBodyOf(requests)['response_format'], {'type': 'json_object'});
    });

    test('OpenAI asks for json_object without a schema too', () async {
      // Not a DeepSeek special case since #415: a schemaless JSON request has
      // nothing to build a `json_schema` from, and asking for `json_object` is
      // the only thing that puts either host into JSON mode at all.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'give me an object',
        outputFormat: 'json',
      );

      expect(chatBodyOf(requests)['response_format'], {'type': 'json_object'});
    });

    test('OpenAI is still handed the schema itself', () async {
      // The difference that remains: OpenAI takes the schema as a constraint,
      // DeepSeek can only be told about it in the prompt.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'describe a person',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      final format =
          chatBodyOf(requests)['response_format'] as Map<String, dynamic>;
      expect(format['type'], 'json_schema');
    });

    test('carries the schema in the prompt, since the wire cannot', () async {
      // The schema cannot travel as a constraint here, so it has to reach the
      // model as text - and DeepSeek refuses a JSON request whose prompt never
      // says "json". Since #453 core's own simulation writes those
      // instructions for a model that claims no constrained generation, which
      // is why the plugin's `jsonObjectInstruction` stands down rather than
      // repeating them; the assertion is on the prompt, not on who wrote it.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'describe a person',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      final prompt = jsonEncode(chatBodyOf(requests)['messages']);
      expect(prompt.toLowerCase(), contains('json'));
      expect(prompt, contains(r'\"name\"'));
    });

    test('does not repeat itself when the prompt already says json', () async {
      // With no schema the instruction exists only to satisfy DeepSeek's
      // "the prompt must mention json" rule, which the caller already did.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'reply with json please',
        outputFormat: 'json',
      );

      expect(chatBodyOf(requests)['messages'], hasLength(1));
    });

    test('adds nothing when core already wrote the instructions', () async {
      // Core's formatter marks what it wrote with `purpose: 'output'`, and
      // since #453 its simulated constrained generation writes exactly these
      // instructions for a model claiming no native constraint. A second copy
      // from here would send the schema twice.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: DeepSeekModels.deepseekFlash,
        prompt: 'Extract the fields from this JSON log line: {"a":1}',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      final messages = chatBodyOf(requests)['messages'] as List;
      expect(messages, hasLength(1));
      final prompt = jsonEncode(messages);
      expect(prompt, contains(r'\"name\"'));
      // Once, not twice.
      expect(
        RegExp('conform to the following').allMatches(prompt),
        hasLength(1),
      );
    });

    test('writes them itself when core wrote none', () async {
      // A raw action call carrying a schema but no instruction part: nothing
      // else will tell DeepSeek what shape to emit, and it refuses a
      // json_object request whose prompt never says "json".
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [deepSeek(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final model = await ai.registry.lookupAction(
        .model,
        'deepseek/deepseek-flash',
      );
      await (model! as Model)(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'describe a person')],
            ),
          ],
          output: OutputConfig(
            format: 'json',
            constrained: false,
            schema: {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
            },
          ),
        ),
      );

      final sent = (chatBodyOf(requests)['messages'] as List).last as Map;
      expect(sent['role'], 'system');
      expect(sent['content'], contains('"name"'));
    });

    test('OpenAI gets no such hint', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'describe a person',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      // The schema travels as a constraint there, so the prompt is left alone.
      expect(chatBodyOf(requests)['messages'], hasLength(1));
    });

    test('OpenAI still gets the schema', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: OpenAIModels.gpt4o,
        prompt: 'give me json',
        outputFormat: 'json',
        outputSchema: JsonOut.$schema,
      );

      final format = (chatBodyOf(requests)['response_format'] as Map)
          .cast<String, dynamic>();
      expect(format['type'], 'json_schema');
    });
  });
}
