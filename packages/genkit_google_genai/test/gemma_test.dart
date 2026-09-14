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
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// TODO(#366): consolidate with the shared wire harness once it lands.
/// Captures every generateContent request body the plugin puts on the wire
/// and serves a canned response.
class _WirePlugin extends GoogleGenAiPluginImpl {
  final List<Map<String, dynamic>> captured;

  _WirePlugin(this.captured) : super(apiKey: 'test-key');

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return GenerativeLanguageBaseClient(
      baseUrl: 'https://example.test/',
      client: MockClient((request) async {
        captured.add((jsonDecode(request.body) as Map).cast<String, dynamic>());
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }
}

class _ListingClient extends http.BaseClient {
  _ListingClient(this.body, {this.status = 200});

  final String body;
  final int status;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// The models listing as the live API serves it: Gemini plus the two Gemma 4
/// models, and no earlier Gemma generation.
const _servedModels =
    '{"models": ['
    '{"name": "models/gemini-3.5-flash"}, '
    '{"name": "models/gemma-4-31b-it"}, '
    '{"name": "models/gemma-4-26b-a4b-it"}]}';

Future<Map<String, dynamic>> _onTheWire({
  required String model,
  required List<Message> messages,
  Map<String, dynamic>? config,
}) async {
  final captured = <Map<String, dynamic>>[];
  final plugin = _WirePlugin(captured);
  final action = plugin.resolve(.model, model) as Model;
  await action(ModelRequest(messages: messages, config: config));
  return captured.single;
}

List<Map<String, dynamic>> _contentsOf(Map<String, dynamic> body) =>
    (body['contents'] as List)
        .map((c) => (c as Map).cast<String, dynamic>())
        .toList();

List<Map<String, dynamic>> _partsOf(Map<String, dynamic> content) =>
    (content['parts'] as List)
        .map((p) => (p as Map).cast<String, dynamic>())
        .toList();

Map<String, dynamic> _systemInstructionOf(Map<String, dynamic> body) =>
    (body['systemInstruction'] as Map).cast<String, dynamic>();

Map<String, dynamic> _modelInfoOf(Map<String, dynamic> metadata) =>
    (metadata['model'] as Map).cast<String, dynamic>();

void main() {
  GoogleGenAiPluginImpl plugin({http.Client? client}) =>
      GoogleGenAiPluginImpl(apiKey: 'test-key', httpClient: client);

  group('curated Gemma models', () {
    for (final model in KnownGemmaModel.values) {
      test('${model.id} resolves with curated metadata', () {
        final action = plugin().resolve(.model, model.id);

        expect(action, isNotNull);
        final info = _modelInfoOf(action!.metadata);
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(info['supports'], commonModelInfo.supports);
      });

      test('${model.id} resolves with GeminiOptions as its '
          'customOptions', () {
        final action = plugin().resolve(.model, model.id) as Model;

        expect(action.customOptions, same(GeminiOptions.$schema));
      });
    }

    test('typed refs point at the curated action names', () {
      expect(
        GoogleAiModels.gemma431b.name,
        'googleai/${KnownGemmaModel.gemma431b.id}',
      );
      expect(
        GoogleAiModels.gemma426bA4b.name,
        'googleai/${KnownGemmaModel.gemma426bA4b.id}',
      );
    });

    test('typed refs carry GeminiOptions', () {
      expect(
        GoogleAiModels.gemma431b.customOptions,
        same(GeminiOptions.$schema),
      );
      expect(
        GoogleAiModels.gemma426bA4b.customOptions,
        same(GeminiOptions.$schema),
      );
    });

    test('every curated Gemma model has a typed ref', () {
      final refNames = {
        GoogleAiModels.gemma431b.name,
        GoogleAiModels.gemma426bA4b.name,
      };

      expect(refNames, {
        for (final model in KnownGemmaModel.values) 'googleai/${model.id}',
      });
    });

    test('curated catalogue holds both families', () {
      for (final model in KnownGeminiModel.values) {
        expect(knownGeminiModels, contains(model.id));
      }
      for (final model in KnownGemmaModel.values) {
        expect(knownGeminiModels, contains(model.id));
      }
    });
  });

  group('list', () {
    test('lists discovered Gemma models with curated metadata', () async {
      final actions = await plugin(
        client: _ListingClient(_servedModels),
      ).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/gemini-3.5-flash'));
      for (final model in KnownGemmaModel.values) {
        expect(names.where((n) => n == 'googleai/${model.id}'), hasLength(1));

        final discovered = actions.firstWhere(
          (a) => a.name == 'googleai/${model.id}',
        );
        final info = _modelInfoOf(discovered.metadata);
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(info['supports'], commonModelInfo.supports);
      }
    });

    test('lists Gemma models absent from discovery', () async {
      final client = _ListingClient(
        '{"models": [{"name": "models/gemini-3.5-flash"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      for (final model in KnownGemmaModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
    });

    test('lists Gemma models when discovery fails outright', () async {
      final client = _ListingClient(
        '{"error": {"message": "boom", "status": "INTERNAL"}}',
        status: 500,
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      for (final model in KnownGemmaModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
      expect(names.where((n) => n.contains('gemma-3')), isEmpty);
    });

    test('lists a served Gemma model that is not curated', () async {
      final client = _ListingClient(
        '{"models": ['
        '{"name": "models/gemini-3.5-flash"}, '
        '{"name": "models/gemma-5-x-it"}]}',
      );
      final actions = await plugin(client: client).list();

      final discovered = actions.firstWhere(
        (a) => a.name == 'googleai/gemma-5-x-it',
        orElse: () => throw TestFailure(
          'gemma-5-x-it missing from ${actions.map((a) => a.name)}',
        ),
      );
      final info = _modelInfoOf(discovered.metadata);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);

      final gemini = actions.firstWhere(
        (a) => a.name == 'googleai/gemini-3.5-flash',
      );
      expect(
        info['customOptions'],
        _modelInfoOf(gemini.metadata)['customOptions'],
      );
    });

    test('drops a Gemma model that cannot generate content', () async {
      final client = _ListingClient(
        '{"models": ['
        '{"name": "models/gemma-5-embed", '
        '"supportedGenerationMethods": ["embedContent"]}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, isNot(contains('googleai/gemma-5-embed')));
    });

    test('keeps a model whose supportedGenerationMethods is absent', () async {
      final client = _ListingClient(
        '{"models": [{"name": "models/gemma-5-x-it"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/gemma-5-x-it'));
    });
  });

  // Gemma takes the shared Gemini request path unchanged. These pin that path
  // for Gemma model names so Gemma-specific special-casing cannot creep back in.
  group('gemma requests on the wire', () {
    test('sends the system message with role system', () async {
      final body = await _onTheWire(
        model: 'gemma-4-31b-it',
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'be terse')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      final systemInstruction = _systemInstructionOf(body);
      expect(systemInstruction['role'], 'system');
      expect(_partsOf(systemInstruction).map((p) => p['text']), ['be terse']);

      final contents = _contentsOf(body);
      expect(contents, hasLength(1));
      expect(contents.first['role'], 'user');
      expect(_partsOf(contents.first).map((p) => p['text']), ['hello']);
    });

    test('keeps reasoning parts and thought signatures in history', () async {
      final body = await _onTheWire(
        model: 'gemma-4-31b-it',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
          Message(
            role: Role.model,
            content: [
              ReasoningPart(
                reasoning: 'thinking...',
                metadata: {'thoughtSignature': 'sig'},
              ),
              TextPart(text: 'hi'),
            ],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'again')],
          ),
        ],
      );

      final contents = _contentsOf(body);
      expect(contents, hasLength(3));
      final modelParts = _partsOf(contents[1]);
      expect(modelParts.first['thought'], isTrue);
      expect(modelParts.first['text'], 'thinking...');
      expect(modelParts.first['thoughtSignature'], 'sig');
    });

    test('passes temperature above 1.0 through untouched', () async {
      final body = await _onTheWire(
        model: 'gemma-4-31b-it',
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        config: {'temperature': 1.5},
      );

      final generationConfig = (body['generationConfig'] as Map)
          .cast<String, dynamic>();
      expect(generationConfig['temperature'], 1.5);
    });
  });
}
