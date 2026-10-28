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

// The Lyria models on the googleAI plugin. Ported from the JS
// tests/googleai/lyria_test.ts, plus routing and listing.

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:genkit_google_genai/src/lyria.dart';
import 'package:test/test.dart';

import 'test_harness.dart';

final _prompt = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'Create an acoustic folk song')],
  ),
];

const _interaction = {
  'id': 'interaction-123',
  'status': 'completed',
  'steps': [
    {
      'type': 'model_output',
      'content': [
        {'type': 'text', 'text': 'Here are the lyrics...'},
        {'type': 'audio', 'mime_type': 'audio/mpeg', 'data': 'audio-data'},
      ],
    },
  ],
};

/// Runs [model] once on [plugin] and returns the response.
Future<ModelResponse> _run(
  InteractionsWirePlugin plugin, {
  String model = 'lyria-3-clip-preview',
  Map<String, dynamic>? config,
}) async {
  final action = plugin.resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(messages: _prompt, config: config),
  );
  return result.result;
}

void main() {
  _requestTests();
  _responseTests();
  _routingTests();
  _listTests();
}

void _requestTests() {
  group('request', () {
    test('asks for audio and text by default, as response_format '
        'entries', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin);

      final body = plugin.lastBody;
      expect(body['response_format'], [
        {'type': 'audio'},
        {'type': 'text'},
      ]);
      expect(body, isNot(contains('response_modalities')));
      expect(body['model'], 'lyria-3-clip-preview');
    });

    test('sends lyria-3.5 to the Interactions API', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin, model: 'lyria-3.5');

      expect(plugin.requests.single.url.path, '/v1beta/interactions');
      final body = plugin.lastBody;
      expect(body['model'], 'lyria-3.5');
      expect(body['input'], [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'Create an acoustic folk song'},
          ],
        },
      ]);
      // Nothing else: no store, tools or generation config.
      expect(body.keys.toSet(), {'model', 'input', 'response_format'});
    });

    test('sends explicit responseModalities as response_format '
        'entries', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(
        plugin,
        config: {
          'responseModalities': ['AUDIO'],
        },
      );
      expect(plugin.lastBody['response_format'], {'type': 'audio'});
    });

    test('does not send config keys it does not know (no '
        'passthrough)', () async {
      final plugin = InteractionsWirePlugin(response: _interaction);
      await _run(plugin, config: {'temperature': 0.8});
      expect(plugin.lastBody, isNot(contains('temperature')));
    });
  });
}

void _responseTests() {
  group('response', () {
    test('returns structured audio and text response', () async {
      final response = await _run(
        InteractionsWirePlugin(response: _interaction),
        model: 'lyria-3-pro-preview',
      );

      final content = response.message!.content;
      expect(content, hasLength(2));
      expect(content[0].text, 'Here are the lyrics...');
      expect(content[1].media?.contentType, 'audio/mpeg');
      expect(content[1].media?.url, 'data:audio/mpeg;base64,audio-data');
    });

    test('throws for a failed interaction', () async {
      await expectLater(
        _run(
          InteractionsWirePlugin(
            response: {'id': 'interaction-123', 'status': 'failed'},
          ),
          model: 'lyria-3-pro-preview',
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('Interaction failed'),
          ),
        ),
      );
    });
  });
}

void _routingTests() {
  group('routing and metadata', () {
    final plugin = GoogleGenAiPluginImpl(apiKey: 'test-key');

    test('known models resolve with their label and the Lyria '
        'profile', () {
      for (final model in KnownLyriaModel.values) {
        final action = plugin.resolve(.model, model.id) as Model;
        expect(action.name, 'googleai/${model.id}');
        expect(action.customOptions, same(LyriaOptions.$schema));
        final info = (action.metadata['model'] as Map).cast<String, dynamic>();
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(info['supports'], {
          'multiturn': false,
          'media': true,
          'tools': false,
          'toolChoice': false,
          'systemRole': false,
          'output': ['media', 'text'],
        });
      }
    });

    test('the known list matches JS', () {
      expect(KnownLyriaModel.values.map((m) => m.id), [
        'lyria-3.5',
        'lyria-3-clip-preview',
        'lyria-3-pro-preview',
      ]);
    });

    test('unlisted lyria-* names resolve as Lyria models', () {
      final action = plugin.resolve(.model, 'lyria-9-future') as Model;
      expect(action.customOptions, same(LyriaOptions.$schema));
      final info = (action.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['supports'], lyriaSupports);
    });
  });
}

void _listTests() {
  group('list', () {
    GoogleGenAiPluginImpl pluginWith(ListingClient client) =>
        GoogleGenAiPluginImpl(apiKey: 'test-key', httpClient: client);

    test('lists discovered Lyria models, without deprecated ones', () async {
      final actions = await pluginWith(
        ListingClient(
          modelsResponse:
              '{"models": ['
              '{"name": "models/lyria-9-future", '
              '"supportedGenerationMethods": ["createInteraction"]}, '
              '{"name": "models/lyria-old", '
              '"description": "This model is deprecated."}]}',
        ),
      ).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/lyria-9-future'));
      expect(names, isNot(contains('googleai/lyria-old')));
      final discovered = actions.firstWhere(
        (a) => a.name == 'googleai/lyria-9-future',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['supports'], lyriaSupports);
    });

    test('lists the known models once, discovered or not', () async {
      final actions = await pluginWith(
        ListingClient(
          modelsResponse: '{"models": [{"name": "models/lyria-3.5"}]}',
        ),
      ).list();
      final names = actions.map((a) => a.name).toList();

      for (final model in KnownLyriaModel.values) {
        expect(
          names.where((n) => n == 'googleai/${model.id}'),
          hasLength(1),
          reason: model.id,
        );
      }
    });

    test('lists the known models when discovery fails', () async {
      final actions = await pluginWith(
        ListingClient(
          listStatus: 500,
          modelsResponse:
              '{"error": {"message": "boom", "status": "INTERNAL"}}',
        ),
      ).list();
      final names = actions.map((a) => a.name).toList();

      for (final model in KnownLyriaModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
    });
  });
}
