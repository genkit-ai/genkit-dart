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

// The Lyria 3 models on the vertexAI plugin (JS vertexai/lyria.ts, the
// Interactions path; lyria-002 isn't ported).

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart' show lyriaSupports;
import 'package:genkit_vertexai/genkit_vertexai.dart';
import 'package:genkit_vertexai/src/known_models.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

const _interaction = {
  'status': 'completed',
  'steps': [
    {
      'type': 'model_output',
      'content': [
        {'type': 'text', 'text': '[0.0:] Lyrics...'},
      ],
    },
    {
      'type': 'model_output',
      'content': [
        {'type': 'audio', 'mime_type': 'audio/mpeg', 'data': 'YXVkaW8='},
      ],
    },
  ],
};

VertexAiPluginImpl _plugin(MockHttpClient client, {String? location}) =>
    VertexAiPluginImpl(
      projectId: 'my-project',
      location: location ?? 'global',
      authClient: client,
    );

Future<ModelResponse> _run(
  MockHttpClient client, {
  String model = 'lyria-3-clip-preview',
  Map<String, dynamic>? config,
  String? location,
}) async {
  final action =
      _plugin(client, location: location).resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [TextPart(text: 'Create an acoustic folk song')],
        ),
      ],
      config: config,
    ),
  );
  return result.result;
}

Map<String, dynamic> _lastBody(MockHttpClient client) =>
    (jsonDecode(client.lastBody!) as Map).cast<String, dynamic>();

void main() {
  _requestTests();
  _catalogTests();
  _listTests();
}

void _requestTests() {
  group('request', () {
    test('posts to the project interactions URL with no response format by '
        'default', () async {
      final client = MockHttpClient(interactionResponse: _interaction);
      await _run(client);

      expect(
        client.lastUrl.toString(),
        'https://aiplatform.googleapis.com/v1beta1/projects/my-project/'
        'locations/global/interactions',
      );
      final body = _lastBody(client);
      expect(body['model'], 'lyria-3-clip-preview');
      // The platform rejects an audio entry without a bit_rate.
      expect(body.keys.toSet(), {'model', 'input'});
    });

    test('sends explicit responseModalities as response_format', () async {
      final client = MockHttpClient(interactionResponse: _interaction);
      await _run(
        client,
        config: {
          'responseModalities': ['AUDIO'],
        },
      );
      expect(_lastBody(client)['response_format'], {'type': 'audio'});
    });

    test('a request location overrides the plugin location', () async {
      final client = MockHttpClient(interactionResponse: _interaction);
      await _run(
        client,
        location: 'us-central1',
        config: {'location': 'global'},
      );
      expect(
        client.lastUrl.toString(),
        startsWith('https://aiplatform.googleapis.com/'),
      );
      expect(_lastBody(client), isNot(contains('location')));
    });

    test('returns the lyrics text and the audio', () async {
      final response = await _run(
        MockHttpClient(interactionResponse: _interaction),
        model: 'lyria-3-pro-preview',
      );
      final content = response.message!.content;
      expect(content.first.text, '[0.0:] Lyrics...');
      expect(content.last.media?.contentType, 'audio/mpeg');
    });
  });
}

void _catalogTests() {
  group('catalog', () {
    test('the known list matches JS (without lyria-002)', () {
      expect(KnownVertexLyriaModel.values.map((m) => m.id), [
        'lyria-3-clip-preview',
        'lyria-3-pro-preview',
      ]);
    });

    test('known and unlisted lyria-* names resolve as Lyria models', () {
      for (final name in ['lyria-3-clip-preview', 'lyria-9-future']) {
        final action = _plugin(MockHttpClient()).resolve(.model, name) as Model;
        expect(action.customOptions, same(LyriaOptions.$schema), reason: name);
        final info = (action.metadata['model'] as Map).cast<String, dynamic>();
        expect(info['supports'], lyriaSupports, reason: name);
      }
    });

    test('the handle carries LyriaOptions', () {
      final ref = vertexAI.lyria('lyria-3-clip-preview');
      expect(ref.name, 'vertexai/lyria-3-clip-preview');
      expect(ref.customOptions, same(LyriaOptions.$schema));
    });
  });
}

void _listTests() {
  group('list', () {
    test('lists discovered Lyria models without lyria-002, and the known '
        'ones once', () async {
      final client = MockHttpClient(
        publisherModelsResponse:
            '{"publisherModels": ['
            '{"name": "publishers/google/models/lyria-002"}, '
            '{"name": "publishers/google/models/lyria-3-clip-preview"}, '
            '{"name": "publishers/google/models/lyria-9-future"}]}',
      );
      final names = (await _plugin(client).list()).map((a) => a.name).toList();

      expect(names, isNot(contains('vertexai/lyria-002')));
      expect(names, contains('vertexai/lyria-9-future'));
      for (final model in KnownVertexLyriaModel.values) {
        expect(
          names.where((n) => n == 'vertexai/${model.id}'),
          hasLength(1),
          reason: model.id,
        );
      }
    });

    test('lists the known models when discovery fails', () async {
      final client = MockHttpClient(
        publisherModelsStatus: 500,
        publisherModelsResponse:
            '{"error": {"message": "boom", "status": "INTERNAL"}}',
      );
      final names = (await _plugin(client).list()).map((a) => a.name).toList();
      for (final model in KnownVertexLyriaModel.values) {
        expect(names, contains('vertexai/${model.id}'));
      }
    });
  });
}
