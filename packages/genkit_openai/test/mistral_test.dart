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
import 'package:genkit_openai/src/converters.dart';
import 'package:genkit_openai/src/known_mistral_models.dart';
import 'package:genkit_openai/src/known_models.dart'
    show OpenAIModelStage, multimodalSupports;
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:genkit_openai/src/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openai_dart/openai_dart.dart' as sdk;
import 'package:test/test.dart';

import 'fake_openai_server.dart';
import 'recording_client.dart';

/// The fields Mistral's `ChatCompletionRequest` declares
/// (https://docs.mistral.ai/openapi.yaml). Its schema is closed: any other
/// top-level field is a 422.
const _mistralChatFields = {
  'model',
  'messages',
  'temperature',
  'top_p',
  'max_tokens',
  'stream',
  'stop',
  'random_seed',
  'metadata',
  'response_format',
  'tools',
  'tool_choice',
  'presence_penalty',
  'frequency_penalty',
  'min_tokens',
  'repetition_penalty',
  'top_k',
  'logprobs',
  'top_logprobs',
  'prompt_logprobs',
  'top_prompt_logprobs',
  'n',
  'prediction',
  'parallel_tool_calls',
  'reasoning_effort',
  'prompt_mode',
  'guardrails',
  'prompt_cache_key',
  'service_tier',
  'safe_prompt',
};

/// Every field the plugin can be asked to set, at once.
final _everyOption = OpenAIChatOptions(
  temperature: 0.2,
  topP: 0.9,
  maxTokens: 64,
  stop: ['END'],
  presencePenalty: 0.1,
  frequencyPenalty: 0.1,
  seed: 7,
  user: 'end-user-1',
  reasoningEffort: 'high',
  verbosity: 'low',
);

const _reasoning = 'Two loaves, one each.';
const _signature = 'sig-abc';

/// The metadata of a reasoning part read from Mistral.
Map<String, dynamic> _mistralMeta([String? signature]) => {
  'reasoningSource': 'mistral',
  'thoughtSignature': ?signature,
};

/// A reasoning part as the plugin reads it from a Mistral thinking chunk.
ReasoningPart _mistralReasoning(String text, {String? signature}) =>
    ReasoningPart(reasoning: text, metadata: _mistralMeta(signature));

/// The message of a completion, as the SDK parses it.
sdk.AssistantMessage sdkMessageOf(Map<String, dynamic> completion) =>
    sdk.ChatCompletion.fromJson(completion).choices.first.message;

/// The assistant messages of a chat request body.
List<Map<String, dynamic>> _assistantMessages(Map<String, dynamic> body) => [
  for (final m in body['messages'] as List)
    if ((m as Map)['role'] == 'assistant') m.cast<String, dynamic>(),
];

/// Answers chat requests with [replies] in turn, recording each request.
MockClient _scriptedClient(
  List<http.Request> requests,
  List<Map<String, dynamic>> replies,
) {
  var next = 0;
  return MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode(replies[next++]),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

/// A completion whose message `content` is [content], with [toolCalls].
Map<String, dynamic> _completion(
  List<Map<String, dynamic>> content, {
  List<Map<String, dynamic>>? toolCalls,
  String finishReason = 'stop',
}) => {
  ...chatCompletion(),
  'choices': [
    {
      'index': 0,
      'message': {
        'role': 'assistant',
        'content': content,
        'tool_calls': ?toolCalls,
      },
      'finish_reason': finishReason,
    },
  ],
};

/// A thinking chunk as Mistral sends it: its text is itself a list of chunks.
Map<String, dynamic> _thinking(String text, {String? signature}) => {
  'type': 'thinking',
  'thinking': [
    {'type': 'text', 'text': text},
  ],
  'closed': true,
  'signature': ?signature,
};

/// A completion whose `content` is Mistral's array of chunks.
Map<String, dynamic> _thinkingCompletion() => {
  ...chatCompletion(),
  'choices': [
    {
      'index': 0,
      'message': {
        'role': 'assistant',
        'content': [
          _thinking(_reasoning, signature: _signature),
          {'type': 'text', 'text': 'bonjour'},
        ],
      },
      'finish_reason': 'stop',
    },
  ],
};

/// A streamed chunk whose delta `content` is [content], string or array.
Map<String, dynamic> _delta(Object content, {String? finishReason}) => {
  ...chatChunk(finishReason: finishReason),
  'choices': [
    {
      'index': 0,
      'delta': {'content': content},
      'finish_reason': finishReason,
    },
  ],
};

/// The deltas Mistral streams for a model that thinks: an array holding a
/// thinking chunk, an array holding the signed last thinking chunk and the
/// first text chunk, then plain strings.
List<Map<String, dynamic>> _thinkingDeltas() => [
  _delta([_thinking('Two loaves,')]),
  _delta([
    _thinking(' one each.', signature: _signature),
    {'type': 'text', 'text': 'bon'},
  ]),
  _delta('jour', finishReason: 'stop'),
];

/// Answers every chat request with [reply], as JSON or, when the request asked
/// for a stream, as SSE frames.
MockClient _replyingClient(
  List<http.Request> requests, {
  required Map<String, dynamic> Function() reply,
  required List<Map<String, dynamic>> Function() stream,
}) {
  return MockClient((request) async {
    requests.add(request);
    final body = jsonDecode(request.body) as Map;
    if (body['stream'] == true) {
      final frames = [
        for (final frame in stream()) 'data: ${jsonEncode(frame)}\n\n',
        'data: [DONE]\n\n',
      ];
      return http.Response(
        frames.join(),
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return http.Response(
      jsonEncode(reply()),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

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

    test('the Ministral 3 models are curated with image input', () {
      for (final id in [
        'ministral-14b-latest',
        'ministral-8b-latest',
        'ministral-3b-latest',
      ]) {
        final info = mistralModelInfoFor(id);
        expect(info.label, isNotNull, reason: id);
        expect(info.supports?['media'], isTrue, reason: id);
        expect(info.stage, 'stable', reason: id);
        expect(knownMistralChatModels, contains(id));
      }
    });

    test('the alias of a deprecated model is legacy, and still listed', () {
      // Mistral still serves Medium 3.5 until its announced retirement, which
      // is what `legacy` means in this vocabulary.
      for (final model in [KnownMistralModel.mistralMedium]) {
        expect(model.stage, OpenAIModelStage.legacy, reason: model.id);
        expect(model.info.stage, 'legacy', reason: model.id);
        expect(knownMistralChatModels, contains(model.id));
      }
    });

    test('only a deprecated entry is withheld from the listing', () {
      expect(knownMistralChatModels, [
        for (final model in KnownMistralModel.values)
          if (model.stage != OpenAIModelStage.deprecated) model.id,
      ]);
    });

    test('Large is curated by its alias, with image input', () {
      final info = mistralModelInfoFor('mistral-large-latest');

      expect(info.label, 'Mistral Large');
      expect(info.supports?['media'], isTrue);
      expect(info.stage, 'stable');
      expect(knownMistralChatModels, contains('mistral-large-latest'));
    });

    test('only the models Mistral takes reasoning_effort on reason', () {
      // Mistral answers the others with "reasoning_effort is not enabled for
      // this model".
      expect(
        [
          for (final model in KnownMistralModel.values)
            if (model.reasons) model.id,
        ],
        unorderedEquals([
          'mistral-large-latest',
          'mistral-small-latest',
          'mistral-medium-latest',
        ]),
      );
    });

    test('the embedders declare their vector length', () {
      expect(
        mistralEmbedderInfoFor('mistral-embed', compat: false)['dimensions'],
        1024,
      );
      expect(
        mistralEmbedderInfoFor('codestral-embed', compat: false)['dimensions'],
        1536,
      );
      final gateway = mistralEmbedderInfoFor('mistral-embed', compat: true);
      expect(gateway['dimensions'], 1024);
      expect(gateway, isNot(contains('label')));
      expect(
        mistralEmbedderInfoFor('some-embed', compat: false),
        isNot(contains('dimensions')),
      );
    });

    test('lookup is case-insensitive', () {
      expect(
        knownMistralModelFor('Mistral-Small-Latest'),
        KnownMistralModel.mistralSmall,
      );
    });

    test('an uncurated name claims neither tools nor JSON output', () {
      // Mistral lists both per model card, not API-wide.
      final info = mistralModelInfoFor('open-mistral-nemo');

      expect(info.label, isNull);
      expect(info.supports?['multiturn'], isTrue);
      expect(info.supports?['systemRole'], isTrue);
      expect(info.supports?['tools'], isFalse);
      expect(info.supports?['media'], isFalse);
      expect(info.supports?['output'], ['text']);
      expect(info.supports, isNot(contains('constrained')));
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

      expect(models, contains('mistral/ministral-14b-latest'));
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
        httpClient: recordingClient([], modelIds: ['mistral-medium-latest']),
      );

      final metadata = (await plugin.list()).single;
      final info = (metadata.metadata['model'] as Map).cast<String, dynamic>();

      expect(metadata.name, 'mistral/mistral-medium-latest');
      expect(info['supports'], multimodalSupports);
      expect(info.containsKey('label'), isFalse);
      expect(info.containsKey('versions'), isFalse);
    });

    test('lists the embedders with their vector length', () async {
      final plugin = OpenAIPlugin(
        provider: mistralProvider,
        apiKey: 'm-key',
        httpClient: recordingClient([]),
      );

      final embedders = {
        for (final m in await plugin.list())
          if (m.actionType == ActionType.embedder) m.name: m.metadata['model'],
      };

      expect((embedders['mistral/mistral-embed'] as Map)['dimensions'], 1024);
      expect((embedders['mistral/codestral-embed'] as Map)['dimensions'], 1536);
    });

    group('reasoningEffort', () {
      Future<(GenerateResult<dynamic>, List<http.Request>)> generate(
        String model, {
        String? baseUrl,
        List<CustomModelDefinition>? models,
      }) async {
        final requests = <http.Request>[];
        final ai = Genkit(
          plugins: [
            mistral(
              apiKey: 'k',
              baseUrl: baseUrl,
              models: models,
              httpClient: recordingClient(requests),
            ),
          ],
        );
        addTearDown(ai.shutdown);
        final response = await ai.generate(
          model: mistral.model(model),
          prompt: 'hi',
          config: OpenAIChatOptions(reasoningEffort: 'high'),
        );
        return (response, requests);
      }

      test('goes out for a curated model that takes it', () async {
        final (response, requests) = await generate('mistral-small-latest');

        expect(response.finishReason, FinishReason.stop);
        expect(chatBodyOf(requests)['reasoning_effort'], 'high');
      });

      test('is refused for a curated model that does not', () async {
        final (response, requests) = await generate('ministral-14b-latest');

        expect(response.finishReason, FinishReason.failed);
        expect(
          response.error?.message,
          contains('ministral-14b-latest does not accept reasoningEffort'),
        );
        expect(requests, isEmpty);
      });

      test('is left to the API for an uncurated model', () async {
        final (response, requests) = await generate('magistral-medium-2509');

        expect(response.finishReason, FinishReason.stop);
        expect(chatBodyOf(requests)['reasoning_effort'], 'high');
      });

      test('is left to the API for a declared model', () async {
        final (response, requests) = await generate(
          'ministral-14b-latest',
          models: [
            CustomModelDefinition(
              name: 'ministral-14b-latest',
              info: ModelInfo(supports: {'multiturn': true}),
            ),
          ],
        );

        expect(response.finishReason, FinishReason.stop);
        expect(chatBodyOf(requests)['reasoning_effort'], 'high');
      });

      test('is checked on every one of Mistral\'s hosts', () async {
        for (final host in mistralHosts) {
          final (response, requests) = await generate(
            'codestral-latest',
            baseUrl: 'https://$host/v1',
          );

          expect(response.finishReason, FinishReason.failed, reason: host);
          expect(requests, isEmpty, reason: host);
        }
      });

      test('is left to a gateway', () async {
        final (response, requests) = await generate(
          'ministral-14b-latest',
          baseUrl: 'https://gateway.example/v1',
        );

        expect(response.finishReason, FinishReason.stop);
        expect(chatBodyOf(requests)['reasoning_effort'], 'high');
      });
    });

    test('only the OCR models are filtered out of discovery', () async {
      // Mistral lists them, but they are served by `/v1/ocr`, not chat
      // completions.
      final plugin = OpenAIPlugin(
        provider: mistralProvider,
        apiKey: 'm-key',
        httpClient: recordingClient(
          [],
          modelIds: [
            'mistral-small-latest',
            'mistral-large-4',
            'mistral-large-latest',
            'magistral-medium-latest',
            'zai-glm-5-3',
            'mistral-ocr-latest',
          ],
        ),
      );

      final names = (await plugin.list()).map((m) => m.name).toSet();

      expect(names, contains('mistral/mistral-small-latest'));
      expect(names, contains('mistral/mistral-large-4'));
      expect(names, contains('mistral/mistral-large-latest'));
      expect(names, contains('mistral/magistral-medium-latest'));
      expect(names, contains('mistral/zai-glm-5-3'));
      expect(names, isNot(contains('mistral/mistral-ocr-latest')));
    });

    test('every one of Mistral\'s hosts is its own', () async {
      for (final host in mistralHosts) {
        final requests = <http.Request>[];
        final plugin = OpenAIPlugin(
          provider: mistralProvider,
          apiKey: 'm-key',
          baseUrl: 'https://$host',
          httpClient: recordingClient(
            requests,
            modelIds: ['mistral-ocr-latest', 'mistral-small-latest'],
          ),
        );

        final listed = await plugin.list();
        final names = listed.map((m) => m.name).toSet();
        final small = listed.firstWhere(
          (m) => m.name == 'mistral/mistral-small-latest',
        );

        // Catalog, discovery filter and deployment details all apply.
        expect(
          names,
          isNot(contains('mistral/mistral-ocr-latest')),
          reason: host,
        );
        expect(names, contains('mistral/codestral-latest'), reason: host);
        expect(
          (small.metadata['model'] as Map)['label'],
          'Mistral Small',
          reason: host,
        );
        // The versionless spelling is dialled on the host named, at /v1.
        expect(requests.single.url.host, host);
        expect(requests.single.url.path, '/v1/models');
      }
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

    test('sends only fields Mistral defines, whatever is set', () async {
      // Mistral's schema is closed, so a field the SDK starts writing after a
      // bump would fail every request: this catches it, where asserting the
      // known extras are gone would not.
      final body = await bodyFor(_everyOption);

      expect(_mistralChatFields, containsAll(body.keys));
      expect(body['reasoning_effort'], 'high');
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
        config: _everyOption,
      );
      await stream.drain<void>();

      final body = chatBodyOf(requests);
      expect(body['stream'], isTrue);
      expect(_mistralChatFields, containsAll(body.keys));
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
      expect(_mistralChatFields, containsAll(body.keys));
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
      expect(_mistralChatFields, containsAll(body.keys));
      final tool = (body['tools'] as List).single as Map;
      expect((tool['function'] as Map)['name'], 'lookup');
      expect(body['tool_choice'], 'required');
    });

    test('refuses an inline PDF before the request goes out', () async {
      // OpenAI's `file` part carries the document inline; Mistral's takes
      // only an uploaded file's id and rejects the whole request otherwise.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        promptParts: [
          TextPart(text: 'summarise this'),
          MediaPart(
            media: Media(
              url: 'data:application/pdf;base64,JVBERi0xLjcK',
              contentType: 'application/pdf',
            ),
          ),
        ],
      );

      expect(response.finishReason, FinishReason.failed);
      expect(
        response.error?.message,
        contains('does not accept inline application/pdf media'),
      );
      expect(requests, isEmpty);
    });

    test('refuses a PDF data URL that declares no contentType', () async {
      // The data URL's own header says what it is; defaulting to image/png
      // would send it as image_url and past the refusal.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      final response = await ai.generate(
        model: mistral.model('mistral-small-latest'),
        promptParts: [
          TextPart(text: 'summarise this'),
          MediaPart(
            media: Media(url: 'data:application/pdf;base64,JVBERi0xLjcK'),
          ),
        ],
      );

      expect(response.finishReason, FinishReason.failed);
      expect(
        response.error?.message,
        contains('does not accept inline application/pdf media'),
      );
      expect(requests, isEmpty);
    });

    test('an inline image still goes out as image_url', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        promptParts: [
          TextPart(text: 'describe this'),
          MediaPart(
            media: Media(
              url: 'data:image/png;base64,iVBORw0K',
              contentType: 'image/png',
            ),
          ),
        ],
      );

      final body = chatBodyOf(requests);
      final content = ((body['messages'] as List).single as Map)['content'];
      expect((content as List).map((p) => (p as Map)['type']), [
        'text',
        'image_url',
      ]);
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

  group('reply dialect', () {
    Genkit mistralReplying(List<http.Request> requests) {
      final ai = Genkit(
        plugins: [
          mistral(
            apiKey: 'k',
            httpClient: _replyingClient(
              requests,
              reply: _thinkingCompletion,
              stream: _thinkingDeltas,
            ),
          ),
        ],
      );
      addTearDown(ai.shutdown);
      return ai;
    }

    test('a thinking chunk is a reasoning part, signature kept', () async {
      final ai = mistralReplying([]);

      final response = await ai.generate(
        model: mistral.model('mistral-large-latest'),
        prompt: 'Bread for two?',
      );

      expect(response.finishReason, FinishReason.stop);
      expect(response.text, 'bonjour');
      final reasoning = response.message!.content
          .where((p) => p.isReasoning)
          .single;
      expect(reasoning.reasoning, _reasoning);
      expect(reasoning.metadata, _mistralMeta(_signature));
      // Reasoning leads the answer it produced.
      expect(response.message!.content.first.isReasoning, isTrue);
    });

    test('streamed thinking chunks are reasoning chunks', () async {
      final ai = mistralReplying([]);

      final chunks = <GenerateResponseChunk<dynamic>>[];
      final stream = ai.generateStream(
        model: mistral.model('mistral-large-latest'),
        prompt: 'Bread for two?',
      );
      await for (final chunk in stream) {
        chunks.add(chunk);
      }
      final response = await stream.onResult;

      final streamedReasoning = [
        for (final c in chunks)
          for (final p in c.content)
            if (p.isReasoning) p,
      ];
      expect(streamedReasoning.map((p) => p.reasoning).join(), _reasoning);
      expect(streamedReasoning.last.metadata, _mistralMeta(_signature));
      expect(
        [
          for (final c in chunks)
            for (final p in c.content)
              if (p.isText) p.text,
        ],
        ['bon', 'jour'],
      );

      expect(response.text, 'bonjour');
      final reasoning = response.message!.content
          .where((p) => p.isReasoning)
          .single;
      expect(reasoning.reasoning, _reasoning);
      expect(reasoning.metadata, _mistralMeta(_signature));
    });

    test('each thinking chunk is its own part, with its own signature', () {
      final message = GenkitConverter.fromOpenAIAssistantMessage(
        sdkMessageOf(
          mistralChatReply(
            _completion([
              _thinking('first', signature: 's1'),
              _thinking('second', signature: 's2'),
              _thinking('', signature: 's3'),
              {'type': 'text', 'text': 'done'},
            ]),
          ),
        ),
        reasoningSource: mistralReasoningSource,
      );

      expect(
        [
          for (final p in message.content)
            if (p.isReasoning) {'text': p.reasoning, 'meta': p.metadata},
        ],
        [
          {'text': 'first', 'meta': _mistralMeta('s1')},
          {'text': 'second', 'meta': _mistralMeta('s2')},
          // A chunk with only a signature is kept: the signature is what has
          // to go back.
          {'text': '', 'meta': _mistralMeta('s3')},
        ],
      );
      expect(message.text, 'done');
    });

    test('a reply with no signature gets no metadata', () {
      final reply = mistralChatReply({
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': [
                _thinking('hmm'),
                {'type': 'text', 'text': 'a'},
                {'type': 'text', 'text': 'b'},
              ],
            },
          },
        ],
      });

      expect((reply['choices'] as List).single, {
        'message': {
          'role': 'assistant',
          'content': 'ab',
          'reasoning_details': [
            {'type': 'reasoning.text', 'text': 'hmm'},
          ],
        },
      });
    });

    for (final streamed in [false, true]) {
      test('model_length is a length stop (streamed: $streamed)', () async {
        final ai = Genkit(
          plugins: [
            mistral(
              apiKey: 'k',
              httpClient: _replyingClient(
                [],
                reply: () => chatCompletion(
                  content: 'cut',
                  finishReason: 'model_length',
                ),
                stream: () => [_delta('cut', finishReason: 'model_length')],
              ),
            ),
          ],
        );
        addTearDown(ai.shutdown);

        final GenerateResult<dynamic> response;
        if (streamed) {
          final stream = ai.generateStream(
            model: mistral.model('mistral-small-latest'),
            prompt: 'hi',
          );
          await stream.drain<void>();
          response = await stream.onResult;
        } else {
          response = await ai.generate(
            model: mistral.model('mistral-small-latest'),
            prompt: 'hi',
          );
        }

        expect(response.finishReason, FinishReason.length);
        expect(response.text, 'cut');
      });
    }

    test('a string content passes through untouched', () {
      final reply = chatCompletion(content: 'bonjour');

      expect(mistralChatReply(reply), reply);
    });
  });

  group('reasoning replay', () {
    const thinkingChunk = {
      'type': 'thinking',
      'thinking': [
        {'type': 'text', 'text': _reasoning},
      ],
      'signature': _signature,
    };

    for (final streamed in [false, true]) {
      test(
        'a ${streamed ? 'streamed' : 'buffered'} reply\'s reasoning goes back '
        'as a thinking chunk',
        () async {
          final requests = <http.Request>[];
          final ai = Genkit(
            plugins: [
              mistral(
                apiKey: 'k',
                httpClient: _replyingClient(
                  requests,
                  reply: _thinkingCompletion,
                  stream: _thinkingDeltas,
                ),
              ),
            ],
          );
          addTearDown(ai.shutdown);

          final GenerateResult<dynamic> first;
          if (streamed) {
            final stream = ai.generateStream(
              model: mistral.model('mistral-large-latest'),
              prompt: 'Bread for two?',
            );
            await stream.drain<void>();
            first = await stream.onResult;
          } else {
            first = await ai.generate(
              model: mistral.model('mistral-large-latest'),
              prompt: 'Bread for two?',
            );
          }
          await ai.generate(
            model: mistral.model('mistral-large-latest'),
            messages: [
              ...first.messages,
              Message(
                role: Role.user,
                content: [TextPart(text: 'Three?')],
              ),
            ],
          );

          final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
          expect(_assistantMessages(body).single['content'], [
            thinkingChunk,
            {'type': 'text', 'text': 'bonjour'},
          ]);
        },
      );
    }

    test('each reasoning part goes back as its own chunk, in order', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [
              _mistralReasoning('first', signature: 's1'),
              _mistralReasoning('second'),
              _mistralReasoning('', signature: 's3'),
              TextPart(text: 'hello'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'again')],
          ),
        ],
      );

      expect(_assistantMessages(chatBodyOf(requests)).single, {
        'role': 'assistant',
        'content': [
          {
            'type': 'thinking',
            'thinking': [
              {'type': 'text', 'text': 'first'},
            ],
            'signature': 's1',
          },
          {
            'type': 'thinking',
            'thinking': [
              {'type': 'text', 'text': 'second'},
            ],
          },
          {
            'type': 'thinking',
            'thinking': [
              {'type': 'text', 'text': ''},
            ],
            'signature': 's3',
          },
          {'type': 'text', 'text': 'hello'},
        ],
      });
    });

    test('a tool loop sends the thinking back with the tool call', () async {
      // Large 4 always thinks, so the turn that calls the tool carries
      // reasoning that has to reach Mistral on the follow-up request.
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          mistral(
            apiKey: 'k',
            httpClient: _scriptedClient(requests, [
              _completion(
                [_thinking(_reasoning, signature: _signature)],
                toolCalls: [
                  {
                    'id': 'call-1',
                    'type': 'function',
                    'function': {
                      'name': 'lookup',
                      'arguments': '{"dish":"baguette"}',
                    },
                  },
                ],
                finishReason: 'tool_calls',
              ),
              _completion([
                _thinking('In stock.'),
                {'type': 'text', 'text': 'Yes.'},
              ]),
            ]),
          ),
        ],
      );
      addTearDown(ai.shutdown);
      ai.defineTool(
        name: 'lookup',
        description: 'look a dish up',
        fn: (input, ctx) async => .response({'stock': 'in'}),
      );

      final response = await ai.generate(
        model: mistral.model('mistral-large-latest'),
        prompt: 'Is the baguette in stock?',
        toolNames: ['lookup'],
      );

      expect(response.text, 'Yes.');
      expect(requests, hasLength(2));
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      final assistant = _assistantMessages(body).single;
      expect(assistant['content'], [thinkingChunk]);
      expect(((assistant['tool_calls'] as List).single as Map)['id'], 'call-1');
      for (final message in body['messages'] as List) {
        expect(message, isNot(contains('reasoning_details')));
        expect(message, isNot(contains('reasoning_content')));
      }
    });

    test('reasoning from another model is not sent', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [mistral(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: mistral.model('mistral-small-latest'),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(reasoning: 'unmarked'),
              ReasoningPart(
                reasoning: 'from elsewhere',
                metadata: {'reasoningSource': 'other', 'thoughtSignature': 'x'},
              ),
              TextPart(text: 'hello'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'again')],
          ),
        ],
      );

      expect(_assistantMessages(chatBodyOf(requests)).single, {
        'role': 'assistant',
        'content': 'hello',
      });
    });

    test('survives a JSON round trip of the history', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [
          mistral(
            apiKey: 'k',
            httpClient: _replyingClient(
              requests,
              reply: _thinkingCompletion,
              stream: _thinkingDeltas,
            ),
          ),
        ],
      );
      addTearDown(ai.shutdown);

      final first = await ai.generate(
        model: mistral.model('mistral-large-latest'),
        prompt: 'Bread for two?',
      );
      final saved = jsonEncode([for (final m in first.messages) m.toJson()]);
      final history = [
        for (final m in jsonDecode(saved) as List)
          Message.fromJson((m as Map).cast<String, dynamic>()),
      ];
      await ai.generate(
        model: mistral.model('mistral-large-latest'),
        messages: [
          ...history,
          Message(
            role: Role.user,
            content: [TextPart(text: 'Three?')],
          ),
        ],
      );

      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(
        (_assistantMessages(body).single['content'] as List).first,
        thinkingChunk,
      );
    });

    test('OpenAI never gets reasoning back', () async {
      final requests = <http.Request>[];
      final ai = Genkit(
        plugins: [openAI(apiKey: 'k', httpClient: recordingClient(requests))],
      );
      addTearDown(ai.shutdown);

      await ai.generate(
        model: openAI.model('gpt-4o'),
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hi')],
          ),
          Message(
            role: Role.model,
            content: [
              _mistralReasoning('first', signature: 's1'),
              TextPart(text: 'hello'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'again')],
          ),
        ],
      );

      expect(_assistantMessages(chatBodyOf(requests)).single, {
        'role': 'assistant',
        'content': 'hello',
      });
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

    test('a thinking reply is read through the real client', () async {
      server.enqueue(FakeResponse.json(_thinkingCompletion()));
      server.enqueue(FakeResponse.sse(_thinkingDeltas()));
      final ai = Genkit(
        plugins: [mistral(apiKey: 'm-key', baseUrl: server.baseUrl)],
      );
      addTearDown(ai.shutdown);

      final buffered = await ai.generate(
        model: mistral.model('mistral-large-latest'),
        prompt: 'hi',
      );
      final stream = ai.generateStream(
        model: mistral.model('mistral-large-latest'),
        prompt: 'hi',
      );
      await stream.drain<void>();
      final streamed = await stream.onResult;

      for (final response in [buffered, streamed]) {
        expect(response.text, 'bonjour');
        final reasoning = response.message!.content
            .where((p) => p.isReasoning)
            .single;
        expect(reasoning.reasoning, _reasoning);
        expect(reasoning.metadata, _mistralMeta(_signature));
      }
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
