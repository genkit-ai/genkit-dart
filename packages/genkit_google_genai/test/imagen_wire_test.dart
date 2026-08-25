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
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _pngB64 = 'aGVsbG8=';

/// Captures every predict request the plugin puts on the wire and serves a
/// canned Imagen predictions response.
class _WirePlugin extends GoogleGenAiPluginImpl {
  final List<http.Request> captured;
  final List<String?> capturedApiKeys;
  final Map<String, dynamic> response;

  _WirePlugin(
    this.captured, {
    this.response = const {
      'predictions': [
        {'bytesBase64Encoded': _pngB64, 'mimeType': 'image/png'},
      ],
    },
  }) : capturedApiKeys = [],
       super(apiKey: 'test-key');

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    capturedApiKeys.add(requestApiKey);
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured.add(request);
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}

ModelRequest _request({List<Message>? messages, Map<String, dynamic>? config}) {
  return ModelRequest(
    messages:
        messages ??
        [
          Message(
            role: Role.user,
            content: [TextPart(text: 'a cat wearing a hat')],
          ),
        ],
    config: config,
  );
}

Future<(http.Request, ModelResponse)> _predict({
  List<Message>? messages,
  Map<String, dynamic>? config,
  String model = 'imagen-4.0-generate-001',
}) async {
  final captured = <http.Request>[];
  final plugin = _WirePlugin(captured);
  final action = plugin.resolve('model', model) as Model;
  final response = await action(_request(messages: messages, config: config));
  return (captured.single, response);
}

Map<String, dynamic> _body(http.Request request) =>
    (jsonDecode(request.body) as Map).cast<String, dynamic>();

Map<String, dynamic> _parameters(http.Request request) =>
    (_body(request)['parameters'] as Map).cast<String, dynamic>();

Map<String, dynamic> _instance(http.Request request) =>
    ((_body(request)['instances'] as List).single as Map)
        .cast<String, dynamic>();

void main() {
  group('imagen request on the wire', () {
    test('targets the :predict endpoint for the requested model', () async {
      final (request, _) = await _predict();
      expect(
        request.url.toString(),
        'https://example.test/v1beta/models/imagen-4.0-generate-001:predict',
      );
    });

    test('sends the last message text as the instance prompt and defaults '
        'sampleCount to 1', () async {
      final (request, _) = await _predict();
      expect(_instance(request), {'prompt': 'a cat wearing a hat'});
      expect(_parameters(request), {'sampleCount': 1});
    });

    test('prompt comes from the last message only', () async {
      final (request, _) = await _predict(
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'first prompt')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'sure')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'second prompt')],
          ),
        ],
      );
      expect(_instance(request)['prompt'], 'second prompt');
    });

    test('numberOfImages maps to sampleCount and is not sent '
        'verbatim', () async {
      final (request, _) = await _predict(config: {'numberOfImages': 3});
      final parameters = _parameters(request);
      expect(parameters['sampleCount'], 3);
      expect(parameters, isNot(contains('numberOfImages')));
    });

    test('aspectRatio and personGeneration pass through to '
        'parameters', () async {
      final (request, _) = await _predict(
        config: {'aspectRatio': '16:9', 'personGeneration': 'allow_adult'},
      );
      final parameters = _parameters(request);
      expect(parameters['aspectRatio'], '16:9');
      expect(parameters['personGeneration'], 'allow_adult');
    });

    test('unknown config keys pass through to parameters', () async {
      final (request, _) = await _predict(config: {'imageSize': '2K'});
      expect(_parameters(request)['imageSize'], '2K');
    });

    test('config apiKey overrides the transport key and never reaches the '
        'wire', () async {
      final captured = <http.Request>[];
      final plugin = _WirePlugin(captured);
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      await action(_request(config: {'apiKey': 'per-request-key'}));
      expect(plugin.capturedApiKeys, ['per-request-key']);
      expect(_parameters(captured.single), isNot(contains('apiKey')));
      expect(_instance(captured.single), isNot(contains('apiKey')));
    });

    test('a base-image media part is sent as the instance image', () async {
      final (request, _) = await _predict(
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'make it a watercolor'),
              MediaPart(
                media: Media(
                  url: 'data:image/png;base64,$_pngB64',
                  contentType: 'image/png',
                ),
              ),
            ],
          ),
        ],
      );
      expect(_instance(request)['image'], {'bytesBase64Encoded': _pngB64});
    });

    test('a media part typed other than base is not sent as the instance '
        'image', () async {
      final (request, _) = await _predict(
        messages: [
          Message(
            role: Role.user,
            content: [
              TextPart(text: 'make it a watercolor'),
              MediaPart(
                media: Media(
                  url: 'data:image/png;base64,$_pngB64',
                  contentType: 'image/png',
                ),
                metadata: {'type': 'mask'},
              ),
            ],
          ),
        ],
      );
      expect(_instance(request), isNot(contains('image')));
    });

    test('an empty prompt is rejected before any request is made', () async {
      final captured = <http.Request>[];
      final plugin = _WirePlugin(captured);
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      await expectLater(
        action(
          _request(
            messages: [Message(role: Role.user, content: [])],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
      expect(captured, isEmpty);
    });

    test('tool requests are rejected', () async {
      final plugin = _WirePlugin([]);
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      await expectLater(
        action(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'a cat')],
              ),
            ],
            tools: [
              ToolDefinition(
                name: 'someTool',
                description: 'tool',
                inputSchema: {'type': 'object'},
              ),
            ],
          ),
        ),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });
  });

  group('imagen response conversion', () {
    test('predictions become data-URI media parts with stop finish '
        'reason', () async {
      final captured = <http.Request>[];
      final plugin = _WirePlugin(
        captured,
        response: {
          'predictions': [
            {'bytesBase64Encoded': 'aaaa', 'mimeType': 'image/png'},
            {'bytesBase64Encoded': 'bbbb', 'mimeType': 'image/jpeg'},
          ],
        },
      );
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      final response = await action(_request());

      expect(response.finishReason, FinishReason.stop);
      expect(response.message!.role, Role.model);
      final media = response.message!.content.map((p) => p.media!).toList();
      expect(media, hasLength(2));
      expect(media[0].url, 'data:image/png;base64,aaaa');
      expect(media[0].contentType, 'image/png');
      expect(media[1].url, 'data:image/jpeg;base64,bbbb');
      expect(media[1].contentType, 'image/jpeg');
      expect(response.usage!.outputImages, 2);
    });

    test('an empty predictions response throws', () async {
      final plugin = _WirePlugin([], response: {'predictions': []});
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      await expectLater(
        action(_request()),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('no predictions'),
          ),
        ),
      );
    });

    test('a prediction without image bytes throws', () async {
      final plugin = _WirePlugin(
        [],
        response: {
          'predictions': [
            {'mimeType': 'image/png'},
          ],
        },
      );
      final action =
          plugin.resolve('model', 'imagen-4.0-generate-001') as Model;
      await expectLater(action(_request()), throwsA(isA<GenkitException>()));
    });
  });

  group('imagen resolution and listing', () {
    Map<String, dynamic> modelInfoOf(Action action) =>
        (action.metadata['model'] as Map).cast<String, dynamic>();

    test('curated imagen models resolve with imagen metadata and '
        'options', () {
      final plugin = _WirePlugin([]);
      for (final model in KnownImagenModel.values) {
        final action = plugin.resolve('model', model.id);
        expect(action, isNotNull);
        final info = modelInfoOf(action!);
        expect(info['label'], model.label);
        expect((info['supports'] as Map)['multiturn'], isFalse);
        expect((info['supports'] as Map)['media'], isTrue);
        expect((action as Model).customOptions, ImagenOptions.$schema);
      }
    });

    test('unknown imagen model names still resolve as imagen models', () {
      final plugin = _WirePlugin([]);
      final action = plugin.resolve('model', 'imagen-99.0-generate-001');
      expect(action, isNotNull);
      expect((action as Model).customOptions, ImagenOptions.$schema);
      expect((modelInfoOf(action)['supports'] as Map)['tools'], isFalse);
    });

    test('list surfaces discovered predict-capable imagen models and '
        'appends curated ones missing from discovery', () async {
      final plugin = _ListPlugin(
        '{"models": ['
        '{"name": "models/gemini-2.0-flash"}, '
        '{"name": "models/imagen-4.0-generate-001", '
        '"supportedGenerationMethods": ["predict"]}, '
        '{"name": "models/imagen-3.0-generate-002", '
        '"supportedGenerationMethods": ["predict"]}, '
        '{"name": "models/imagen-nonpredict", '
        '"supportedGenerationMethods": ["generateContent"]}]}',
      );
      final actions = await plugin.list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/imagen-3.0-generate-002'));
      expect(names, isNot(contains('googleai/imagen-nonpredict')));
      for (final model in KnownImagenModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
      expect(
        names.where((n) => n == 'googleai/imagen-4.0-generate-001'),
        hasLength(1),
      );

      final discovered = actions.firstWhere(
        (a) => a.name == 'googleai/imagen-4.0-generate-001',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['label'], 'Imagen 4');
      expect((info['supports'] as Map)['multiturn'], isFalse);
    });

    test('list falls back to curated imagen models when discovery '
        'fails', () async {
      final plugin = _ListPlugin(
        '{"error": {"message": "boom", "status": "INTERNAL"}}',
        status: 500,
      );
      final actions = await plugin.list();
      final names = actions.map((a) => a.name).toList();
      for (final model in KnownImagenModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
    });

    test('googleAI.imagen and GoogleAiModels refs point at the curated '
        'action names', () {
      expect(
        googleAI.imagen('imagen-4.0-generate-001').name,
        'googleai/imagen-4.0-generate-001',
      );
      expect(
        GoogleAiModels.imagen4.name,
        'googleai/${KnownImagenModel.imagen4.id}',
      );
      expect(
        GoogleAiModels.imagen4Fast.name,
        'googleai/${KnownImagenModel.imagen4Fast.id}',
      );
      expect(
        GoogleAiModels.imagen4Ultra.name,
        'googleai/${KnownImagenModel.imagen4Ultra.id}',
      );
    });
  });
}

/// Serves a canned models-listing body for list() tests.
class _ListPlugin extends GoogleGenAiPluginImpl {
  final String listBody;
  final int status;

  _ListPlugin(this.listBody, {this.status = 200}) : super(apiKey: 'test-key');

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        return http.Response(
          listBody,
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}
