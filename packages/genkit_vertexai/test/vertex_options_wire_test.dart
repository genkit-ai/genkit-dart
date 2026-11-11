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

// The vertexAI-only options (labels, vertexRetrieval, payGo, location,
// videoFormat.gcsUri) and TTS on generateContent (audioFormat, speech
// metadata, streamed audio), on both APIs. Mirrors the JS vertexai
// gemini_test cases.

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart'
    show resetDroppedConfigFieldWarnings;
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

// gemini-3.1-pro-preview is pinned to generateContent; gemini-3.8-flash uses
// the Interactions API.
const _generateContentModel = 'gemini-3.1-pro-preview';
const _interactionsModel = 'gemini-3.8-flash';
const _ttsModel = 'gemini-3.8-flash-tts';

final _hello = [
  Message(
    role: Role.user,
    content: [TextPart(text: 'hello')],
  ),
];

/// Runs [model] once on a vertexAI plugin at [location]; returns the
/// response.
Future<ModelResponse> _run(
  MockHttpClient client, {
  required String model,
  List<Message>? messages,
  Map<String, dynamic>? config,
  String location = 'global',
  void Function(ModelResponseChunk)? onChunk,
}) async {
  final plugin = VertexAiPluginImpl(
    projectId: 'my-project',
    location: location,
    authClient: client,
  );
  final action = plugin.resolve(.model, model) as Model;
  final result = await action.run(
    ModelRequest(messages: messages ?? _hello, config: config),
    onChunk: onChunk,
  );
  return result.result;
}

Map<String, dynamic> _lastBody(MockHttpClient client) =>
    (jsonDecode(client.lastBody!) as Map).cast<String, dynamic>();

List<String> _captureWarnings() {
  final warnings = <String>[];
  final subscription = Logger.root.onRecord
      .where((r) => r.level == Level.WARNING)
      .listen((r) => warnings.add(r.message));
  addTearDown(subscription.cancel);
  return warnings;
}

void main() {
  setUp(resetDroppedConfigFieldWarnings);

  _labelTests();
  _retrievalTests();
  _payGoTests();
  _locationTests();
  _videoTests();
  _ttsTests();
}

void _labelTests() {
  group('labels', () {
    for (final model in [_generateContentModel, _interactionsModel]) {
      test('are sent on $model, without empty keys', () async {
        final client = MockHttpClient();
        await _run(
          client,
          model: model,
          config: {
            'labels': {'team': 'genkit', '': 'dropped'},
          },
        );
        expect(_lastBody(client)['labels'], {'team': 'genkit'});
      });

      test('are not sent on $model when none are left', () async {
        final client = MockHttpClient();
        await _run(
          client,
          model: model,
          config: {
            'labels': {'': 'dropped'},
          },
        );
        expect(_lastBody(client), isNot(contains('labels')));
      });
    }
  });
}

void _retrievalTests() {
  group('vertexRetrieval', () {
    test('generateContent: a retrieval tool after the other tools, with the '
        'plugin project and location filled in', () async {
      final client = MockHttpClient();
      await _run(
        client,
        model: _generateContentModel,
        location: 'us',
        config: {
          'googleSearch': <String, dynamic>{},
          'vertexRetrieval': {
            'datastore': {'dataStoreId': 'my-store'},
            'disableAttribution': true,
          },
        },
      );
      expect(_lastBody(client)['tools'], [
        {'googleSearch': <String, dynamic>{}},
        {
          'retrieval': {
            'vertexAiSearch': {
              'datastore':
                  'projects/my-project/locations/us/collections/'
                  'default_collection/dataStores/my-store',
            },
            'disableAttribution': true,
          },
        },
      ]);
    });

    test('Interactions: a retrieval tool with the given data store; '
        'disableAttribution is dropped with a warning', () async {
      final warnings = _captureWarnings();
      final client = MockHttpClient();
      await _run(
        client,
        model: _interactionsModel,
        config: {
          'vertexRetrieval': {
            'datastore': {
              'projectId': 'p',
              'location': 'us-central1',
              'dataStoreId': 'ds',
            },
            'disableAttribution': false,
          },
        },
      );
      expect(_lastBody(client)['tools'], [
        {
          'type': 'retrieval',
          'retrieval_types': ['vertex_ai_search'],
          'vertex_ai_search_config': {
            'datastores': [
              'projects/p/locations/us-central1/collections/'
                  'default_collection/dataStores/ds',
            ],
          },
        },
      ]);
      expect(warnings, [
        'vertexRetrieval.disableAttribution is not supported by '
            "'$_interactionsModel' and was ignored.",
      ]);
    });

    test('an empty dataStoreId throws INVALID_ARGUMENT', () async {
      await expectLater(
        _run(
          MockHttpClient(),
          model: _generateContentModel,
          config: {
            'vertexRetrieval': {
              'datastore': {'dataStoreId': ''},
            },
          },
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
    });
  });
}

void _payGoTests() {
  group('payGo', () {
    test('payGoHeaders matches JS for every value', () {
      expect(payGoHeaders('priority'), {
        'X-Vertex-AI-LLM-Shared-Request-Type': 'priority',
      });
      expect(payGoHeaders('priority-only'), {
        'X-Vertex-AI-LLM-Request-Type': 'shared',
        'X-Vertex-AI-LLM-Shared-Request-Type': 'priority',
      });
      expect(payGoHeaders('flex'), {
        'X-Vertex-AI-LLM-Shared-Request-Type': 'flex',
      });
      expect(payGoHeaders('flex-only'), {
        'X-Vertex-AI-LLM-Request-Type': 'shared',
        'X-Vertex-AI-LLM-Shared-Request-Type': 'flex',
      });
      expect(payGoHeaders(null), isEmpty);
    });

    for (final model in [_generateContentModel, _interactionsModel]) {
      test('sends the headers on $model, not in the body', () async {
        final client = MockHttpClient();
        await _run(client, model: model, config: {'payGo': 'flex-only'});
        final headers = client.lastHeaders!;
        expect(headers['X-Vertex-AI-LLM-Request-Type'], 'shared');
        expect(headers['X-Vertex-AI-LLM-Shared-Request-Type'], 'flex');
        expect(_lastBody(client), isNot(contains('payGo')));
        expect(_lastBody(client), isNot(contains('pay_go')));
      });
    }

    test('sends no headers when not set', () async {
      final client = MockHttpClient();
      await _run(client, model: _generateContentModel);
      expect(
        client.lastHeaders!.keys.where((k) => k.startsWith('X-Vertex-AI-LLM')),
        isEmpty,
      );
    });
  });
}

void _locationTests() {
  group('location', () {
    test('a request location overrides the plugin location '
        '(generateContent)', () async {
      final client = MockHttpClient();
      await _run(
        client,
        model: _generateContentModel,
        config: {'location': 'europe-west1'},
      );
      expect(
        client.lastUrl.toString(),
        'https://europe-west1-aiplatform.googleapis.com/v1beta1/projects/'
        'my-project/locations/europe-west1/publishers/google/models/'
        '$_generateContentModel:generateContent',
      );
      expect(_lastBody(client), isNot(contains('location')));
    });

    test('a request location overrides the plugin location '
        '(Interactions, multi-regional host)', () async {
      final client = MockHttpClient();
      await _run(client, model: _interactionsModel, config: {'location': 'us'});
      expect(
        client.lastUrl.toString(),
        'https://aiplatform.us.rep.googleapis.com/v1beta1/projects/'
        'my-project/locations/us/interactions',
      );
    });

    test('without a request location, the plugin location is used', () async {
      final client = MockHttpClient();
      await _run(client, model: _generateContentModel, location: 'eu');
      expect(
        client.lastUrl.toString(),
        startsWith(
          'https://aiplatform.eu.rep.googleapis.com/v1beta1/projects/'
          'my-project/locations/eu/',
        ),
      );
    });
  });
}

void _videoTests() {
  group('videoFormat.gcsUri', () {
    test('is sent on the video response format', () async {
      final client = MockHttpClient();
      await _run(
        client,
        model: 'gemini-omni-1.1-flash-preview',
        config: {
          'videoFormat': {'delivery': 'uri', 'gcsUri': 'gs://bucket/out'},
        },
      );
      expect(_lastBody(client)['response_format'], {
        'type': 'video',
        'delivery': 'uri',
        'gcs_uri': 'gs://bucket/out',
      });
    });
  });
}

Map<String, Object?> _audioChunk(List<int> bytes) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {
            'inlineData': {
              'mimeType': 'audio/l16;codec=pcm;rate=24000',
              'data': base64Encode(bytes),
            },
          },
        ],
      },
    },
  ],
};

Map<String, Object?> _voice(String name) => {
  'prebuiltVoiceConfig': {'voiceName': name},
};

void _ttsTests() {
  group('TTS on generateContent', () {
    test('sends audioFormat as responseFormat, asks for audio by default and '
        'sends speech metadata', () async {
      final warnings = _captureWarnings();
      final client = MockHttpClient();
      await _run(
        client,
        model: _ttsModel,
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(
                text: 'Hi Jane!',
                metadata: {
                  'speechMetadata': {'speaker': 'Joe'},
                },
              ),
            ],
          ),
        ],
        config: {
          'speechConfig': {
            'multiSpeakerVoiceConfig': {
              'speakerVoiceConfigs': [
                {'speaker': 'Joe', 'voiceConfig': _voice('Puck')},
                {'speaker': 'Jane', 'voiceConfig': _voice('Kore')},
              ],
            },
          },
          'audioFormat': {'mimeType': 'audio/mulaw'},
        },
      );
      expect(client.lastUrl.toString(), endsWith(':generateContent'));
      final body = _lastBody(client);
      expect(((body['contents'] as List).first as Map)['parts'], [
        {
          'text': 'Hi Jane!',
          'speechMetadata': {'speaker': 'Joe'},
        },
      ]);
      final generationConfig = body['generationConfig'] as Map;
      expect(generationConfig['responseModalities'], ['AUDIO']);
      expect(generationConfig['responseFormat'], [
        {
          'audio': {'mimeType': 'AUDIO_MULAW'},
        },
      ]);
      expect(warnings, isEmpty);
    });

    test('keeps the sample rate and the given response modalities', () async {
      final client = MockHttpClient();
      await _run(
        client,
        model: _ttsModel,
        config: {
          'responseModalities': ['AUDIO', 'TEXT'],
          'audioFormat': {'mimeType': 'audio/l16', 'sampleRate': 16000},
        },
      );
      final generationConfig = _lastBody(client)['generationConfig'] as Map;
      expect(generationConfig['responseModalities'], ['AUDIO', 'TEXT']);
      expect(generationConfig['responseFormat'], [
        {
          'audio': {'mimeType': 'AUDIO_L16', 'sampleRate': 16000},
        },
      ]);
    });

    test('non-TTS models get no audio default', () async {
      final client = MockHttpClient();
      await _run(client, model: _generateContentModel);
      final generationConfig = _lastBody(client)['generationConfig'] as Map;
      expect(generationConfig, isNot(contains('responseModalities')));
      expect(generationConfig, isNot(contains('responseFormat')));
    });

    test('joins streamed audio chunks in the final response', () async {
      final client = MockHttpClient()
        ..streamChunks = [
          _audioChunk([1, 2]),
          _audioChunk([3, 4]),
          _audioChunk([5, 6]),
        ];
      final chunks = <ModelResponseChunk>[];
      final response = await _run(
        client,
        model: _ttsModel,
        onChunk: chunks.add,
      );

      // Each chunk is still streamed as it arrives.
      expect(chunks, hasLength(3));
      final media = response.message!.content.where((p) => p.isMedia).toList();
      expect(media, hasLength(1));
      final url = media.single.media!.url;
      expect(base64Decode(url.substring(url.indexOf(',') + 1)), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(media.single.media!.contentType, 'audio/l16;codec=pcm;rate=24000');
    });
  });
}
