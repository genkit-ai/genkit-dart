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

part 'xai_test.g.dart';

/// A generated class, whose schema is a `$ref` into `$defs` before flattening.
@Schema()
abstract class $CityQuery {
  String get city;
}

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
              {'id': id, 'object': 'model', 'created': 0, 'owned_by': 'xai'},
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
        'model': 'grok-4.6',
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

Map<String, dynamic> chatBodyOf(List<http.Request> requests) =>
    (jsonDecode(
              requests
                  .firstWhere((r) => r.url.path.endsWith('/chat/completions'))
                  .body,
            )
            as Map)
        .cast<String, dynamic>();

void main() {
  group('catalog', () {
    test('the exported collections cannot be mutated', () {
      expect(() => knownXaiChatModels.add('x'), throwsUnsupportedError);
      expect(
        () => knownXaiModels['x'] = knownXaiModels.values.first,
        throwsUnsupportedError,
      );
    });

    test('every Grok text model takes images, tools and a schema', () {
      // Unlike DeepSeek, xAI offers json_schema, so `constrained` is honest
      // here and the OpenAI preset is an exact fit rather than a near one.
      for (final model in KnownXaiModel.values) {
        final supports = xaiModelInfoFor(model.id).supports!;
        expect(supports['media'], isTrue, reason: model.id);
        expect(supports['tools'], isTrue, reason: model.id);
        expect(supports['constrained'], isTrue, reason: model.id);
      }
    });

    test('only the non-reasoning build declines an effort', () {
      for (final model in KnownXaiModel.values) {
        expect(
          model.reasons,
          model != KnownXaiModel.grok420NonReasoning,
          reason: model.id,
        );
      }
    });

    test('lookup is case-insensitive', () {
      expect(knownXaiModelFor('GROK-4.6'), KnownXaiModel.grok46);
    });

    test('an uncurated Grok is described like the rest', () {
      final info = xaiModelInfoFor('grok-5');

      expect(info.label, isNull);
      expect(info.supports?['media'], isTrue);
    });

    test('curated metadata is not mutable through the returned info', () {
      expect(
        () => xaiModelInfoFor('grok-4.6').supports!['tools'] = false,
        throwsUnsupportedError,
      );
    });

    test('typed refs cover the catalog', () {
      expect(
        XaiModels.all.map((r) => r.name).toSet(),
        knownXaiChatModels.map((id) => 'xai/$id').toSet(),
      );
      expect(XaiModels.grok46.name, 'xai/grok-4.6');
    });
  });

  group('plugin wiring', () {
    test('dials xAI without being told where it lives', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'x-key', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(model: XaiModels.grok46, prompt: 'hi');

      expect(requests.single.url.host, 'api.x.ai');
      expect(requests.single.url.path, '/v1/chat/completions');
      expect(requests.single.headers['authorization'], 'Bearer x-key');
    });

    test('the versionless spelling still reaches /v1', () async {
      // Matching on the host makes `https://api.x.ai` xAI's own, so it keeps
      // the curated catalog - but xAI publishes `/v1` only, and the SDK sends
      // the base URL as given, so the caller's spelling would 404 on every
      // request. The provider's own URL goes on the wire instead.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          xAI(
            apiKey: 'x-key',
            baseUrl: 'https://api.x.ai',
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(model: XaiModels.grok46, prompt: 'hi');

      expect(requests.single.url.path, '/v1/chat/completions');
    });

    test('another host is dialled exactly as written', () async {
      // Nothing is canonicalised for a host we do not recognise: the caller's
      // gateway may well serve the path they gave.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          xAI(
            apiKey: 'x-key',
            baseUrl: 'https://gateway.test/xai',
            httpClient: recordingClient(requests),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      await ai.generate(model: xAI.model('grok-4-6'), prompt: 'hi');

      expect(requests.single.url.host, 'gateway.test');
      expect(requests.single.url.path, '/xai/chat/completions');
    });

    test('names XAI_API_KEY when there is no key', () async {
      final ai = Genkit(
        plugins: [
          OpenAIPlugin(
            provider: xaiProvider,
            configVar: (_) => null,
            httpClient: recordingClient([]),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(model: XaiModels.grok46, prompt: 'hi');

      expect(response.finishReason, FinishReason.failed);
      expect(response.error?.message, contains('XAI_API_KEY'));
    });

    test('lists its own catalog, not another provider\'s', () async {
      final plugin = OpenAIPlugin(
        provider: xaiProvider,
        apiKey: 'x-key',
        httpClient: recordingClient([], modelIds: ['grok-4.6']),
      );

      final names = (await plugin.list()).map((m) => m.name).toSet();

      expect(names, contains('xai/grok-4.6'));
      expect(names, contains('xai/grok-build-0.1'));
      expect(names.any((n) => n.contains('gpt-')), isFalse);
      expect(names.any((n) => n.contains('deepseek')), isFalse);
    });

    test('image and video models stay out of the model listing', () async {
      // xAI serves grok-imagine-*; nothing classified a `video` id before, so
      // the video models would have been offered as chat models.
      final plugin = OpenAIPlugin(
        provider: xaiProvider,
        apiKey: 'x-key',
        httpClient: recordingClient(
          [],
          modelIds: [
            'grok-4.6',
            'grok-imagine-image-2.0',
            'grok-imagine-video-1.5',
          ],
        ),
      );

      final names = (await plugin.list()).map((m) => m.name).toSet();

      expect(names, contains('xai/grok-4.6'));
      expect(names, isNot(contains('xai/grok-imagine-image-2.0')));
      expect(names, isNot(contains('xai/grok-imagine-video-1.5')));
    });
  });

  group('tool schemas', () {
    test('a generated schema reaches the wire inlined', () async {
      // schemantic emits a generated class as a `$ref` into `$defs`. OpenAI
      // resolves it; xAI rejects it outright with "tool parameter root must
      // be an object type (root schema is a $ref)".
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'getPopulation',
        description: 'Get the population of a city.',
        inputSchema: CityQuery.$schema,
        outputSchema: .integer(),
        fn: (q, _) async => .response(1),
      );

      await ai.generate(
        model: XaiModels.grok46,
        prompt: 'hi',
        toolNames: ['getPopulation'],
      );

      final tool = (chatBodyOf(requests)['tools'] as List).single as Map;
      final parameters = ((tool['function'] as Map)['parameters'] as Map)
          .cast<String, dynamic>();

      expect(parameters[r'$ref'], isNull, reason: 'root is still a ref');
      expect(parameters['type'], 'object');
      expect(parameters['properties'] as Map, contains('city'));
    });
  });

  group('request dialect', () {
    test('keeps OpenAI\'s spelling of the token limit', () async {
      // xAI is the closest of the curated providers to OpenAI; nothing about
      // the request is rewritten.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: XaiModels.grok46,
        prompt: 'hi',
        config: OpenAIChatOptions(maxTokens: 128),
      );

      final body = chatBodyOf(requests);
      expect(body['max_completion_tokens'], 128);
      expect(body, isNot(contains('thinking')));
    });

    test('sends a JSON schema, which xAI accepts', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: XaiModels.grok46,
        prompt: 'give me json',
        outputFormat: 'json',
        outputSchema: .string(),
      );

      final format = (chatBodyOf(requests)['response_format'] as Map)
          .cast<String, dynamic>();
      expect(format['type'], 'json_schema');
      // And no prompt hint: the schema travels as a constraint.
      expect(chatBodyOf(requests)['messages'], hasLength(1));
    });

    test('reasoning effort goes at the top level', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: XaiModels.grok46,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'xhigh'),
      );

      expect(chatBodyOf(requests)['reasoning_effort'], 'xhigh');
    });

    test('sends a level xAI does not define, and lets it answer', () async {
      // `minimal` and `max` are OpenAI's, and the shared options schema offers
      // the union of every provider's vocabulary - but which levels a host has
      // is the host's call, settled on #439: refusing locally fails a request
      // the API may well serve.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: XaiModels.grok46,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'minimal'),
      );

      expect(chatBodyOf(requests)['reasoning_effort'], 'minimal');
    });

    test('the non-reasoning build refuses an effort', () async {
      final ai = Genkit(
        plugins: [xAI(apiKey: 'k', httpClient: recordingClient([]))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: XaiModels.grok420NonReasoning,
        prompt: 'hi',
        config: OpenAIChatOptions(reasoningEffort: 'high'),
      );

      expect(response.finishReason, FinishReason.failed);
      expect(response.error?.message, contains('grok-4.20-0309-non-reasoning'));
    });
  });
}
