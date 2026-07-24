// Copyright 2025 Google LLC
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
import 'package:test/test.dart';

class MockHttpClient extends http.BaseClient {
  MockHttpClient({this.modelsResponse, this.listStatus = 200});

  /// Overrides the JSON body returned for the models listing.
  final String? modelsResponse;

  /// HTTP status returned for the models listing.
  final int listStatus;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path != '/v1beta/models') {
      throw StateError('Unexpected request: ${request.url}');
    }
    final body =
        modelsResponse ??
        '{"models": ['
            '{"name": "models/gemini-2.0-flash"}, '
            '{"name": "models/text-embedding-004"}]}';
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      listStatus,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  GoogleGenAiPluginImpl plugin({MockHttpClient? client}) =>
      GoogleGenAiPluginImpl(
        apiKey: 'test-key',
        httpClient: client ?? MockHttpClient(),
      );

  Map<String, dynamic> modelInfoOf(Action action) =>
      (action.metadata['model'] as Map).cast<String, dynamic>();

  group('known model resolution', () {
    for (final model in KnownGeminiModel.values) {
      test('${model.id} resolves with curated metadata', () {
        final action = plugin().resolve('model', model.id);

        expect(action, isNotNull);
        final info = modelInfoOf(action!);
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(
          (info['supports'] as Map).cast<String, dynamic>(),
          model.info.supports,
        );
      });
    }

    test('unknown model falls back to common metadata', () {
      final action = plugin().resolve('model', 'gemini-unknown-model');

      expect(action, isNotNull);
      final info = modelInfoOf(action!);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);
      expect(info['label'], 'googleai/gemini-unknown-model');
    });
  });

  group('list', () {
    test('enriches discovered curated models', () async {
      final client = MockHttpClient(
        modelsResponse:
            '{"models": ['
            '{"name": "models/gemini-3.5-flash"}, '
            '{"name": "models/gemini-2.0-flash"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/gemini-3.5-flash'));

      final discovered = actions.firstWhere(
        (a) => a.name == 'googleai/gemini-3.5-flash',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test('appends curated models missing from discovery', () async {
      final actions = await plugin().list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('googleai/gemini-2.0-flash'));
      expect(names, contains('googleai/text-embedding-004'));
      for (final model in KnownGeminiModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }

      final curated = actions.firstWhere(
        (a) => a.name == 'googleai/gemini-3.5-flash',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test('does not duplicate curated models returned by discovery', () async {
      final client = MockHttpClient(
        modelsResponse:
            '{"models": ['
            '{"name": "models/gemini-3.5-flash"}, '
            '{"name": "models/gemini-2.0-flash"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(
        names.where((n) => n == 'googleai/gemini-3.5-flash'),
        hasLength(1),
      );
      for (final model in KnownGeminiModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
    });

    test('falls back to the curated catalog when discovery fails', () async {
      final client = MockHttpClient(
        listStatus: 500,
        modelsResponse: '{"error": {"message": "boom", "status": "INTERNAL"}}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      for (final model in KnownGeminiModel.values) {
        expect(names, contains('googleai/${model.id}'));
      }
      expect(names.where((n) => n.contains('embedding')), isEmpty);
      final curated = actions.firstWhere(
        (a) => a.name == 'googleai/gemini-3.5-flash',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });
  });

  group('GoogleAiModels', () {
    test('refs point at the curated action names', () {
      expect(
        GoogleAiModels.gemini35Flash.name,
        'googleai/${KnownGeminiModel.gemini35Flash.id}',
      );
      expect(
        GoogleAiModels.gemini31FlashLite.name,
        'googleai/${KnownGeminiModel.gemini31FlashLite.id}',
      );
      expect(
        GoogleAiModels.gemini31FlashImage.name,
        'googleai/${KnownGeminiModel.gemini31FlashImage.id}',
      );
      expect(
        GoogleAiModels.gemini3ProImage.name,
        'googleai/${KnownGeminiModel.gemini3ProImage.id}',
      );
    });
  });
}
