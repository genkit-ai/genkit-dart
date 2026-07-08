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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/common.dart';
import 'package:genkit_vertexai/src/known_models.dart';
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  VertexAiPluginImpl plugin({MockHttpClient? client}) => VertexAiPluginImpl(
    projectId: 'my-project',
    location: 'us-central1',
    authClient: client ?? MockHttpClient(),
  );

  Map<String, dynamic> modelInfoOf(Action action) =>
      (action.metadata['model'] as Map).cast<String, dynamic>();

  group('known model resolution', () {
    for (final name in vertexAiKnownModelNames) {
      test('$name resolves with curated metadata', () {
        final action = plugin().resolve('model', name);

        expect(action, isNotNull);
        final info = modelInfoOf(action!);
        expect(info['label'], knownGeminiModels[name]!.label);
        expect(info['stage'], 'stable');
        expect(
          (info['supports'] as Map).cast<String, dynamic>(),
          knownGeminiModels[name]!.supports,
        );
      });
    }

    test('unknown model falls back to common metadata', () {
      final action = plugin().resolve('model', 'gemini-unknown-model');

      expect(action, isNotNull);
      final info = modelInfoOf(action!);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);
      // Model defaults the label to the action name when not curated.
      expect(info['label'], 'vertexai/gemini-unknown-model');
    });
  });

  group('list', () {
    test('includes curated models missing from discovery', () async {
      final actions = await plugin().list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('vertexai/gemini-2.5-pro'));
      for (final name in vertexAiKnownModelNames) {
        expect(names, contains('vertexai/$name'));
      }

      final curated = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-3.5-flash',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });

    test('does not duplicate curated models returned by discovery', () async {
      final client = MockHttpClient(
        publisherModelsResponse:
            '{"publisherModels": ['
            '{"name": "publishers/google/models/gemini-3.5-flash"}, '
            '{"name": "publishers/google/models/gemini-2.5-pro"}]}',
      );
      final actions = await plugin(client: client).list();
      final names = actions.map((a) => a.name).toList();

      expect(
        names.where((n) => n == 'vertexai/gemini-3.5-flash'),
        hasLength(1),
      );

      // Discovered entry still carries the curated metadata.
      final discovered = actions.firstWhere(
        (a) => a.name == 'vertexai/gemini-3.5-flash',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['label'], 'Gemini 3.5 Flash');
      expect(info['stage'], 'stable');
    });
  });
}
