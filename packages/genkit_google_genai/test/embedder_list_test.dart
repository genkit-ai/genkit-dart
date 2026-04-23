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
import 'package:genkit_google_genai/src/api_client.dart';
import 'package:genkit_google_genai/src/generated/generativelanguage.dart'
    as gcl;
import 'package:genkit_google_genai/src/google_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('GoogleGenAiPluginImpl list', () {
    test('lists embedders with schemas and custom options', () async {
      final plugin = _FakeGoogleGenAiPluginImpl();

      final actions = await plugin.list();
      final embedder = actions.firstWhere(
        (action) => action.name == 'googleai/text-embedding-004',
      );

      expect(embedder.inputSchema, same(EmbedRequest.$schema));
      expect(embedder.outputSchema, same(EmbedResponse.$schema));

      final modelMetadata = embedder.metadata['model'] as Map<String, dynamic>;
      final customOptions =
          modelMetadata['customOptions'] as Map<String, dynamic>;
      expect(customOptions['properties'], contains('outputDimensionality'));
      expect(customOptions['properties'], contains('taskType'));
    });
  });
}

class _FakeGoogleGenAiPluginImpl extends GoogleGenAiPluginImpl {
  _FakeGoogleGenAiPluginImpl();

  @override
  Future<GenerativeLanguageBaseClient> getApiClient([
    String? requestApiKey,
  ]) async {
    return _FakeGoogleGenAiClient();
  }
}

class _FakeGoogleGenAiClient extends GenerativeLanguageBaseClient {
  _FakeGoogleGenAiClient()
    : super(baseUrl: 'https://example.com/', client: _FakeHttpClient());

  @override
  Future<gcl.ListModelsResponse> listModels({
    int? pageSize,
    String? pageToken,
  }) async {
    return gcl.ListModelsResponse(
      models: [
        gcl.Model(name: 'models/gemini-2.5-flash'),
        gcl.Model(name: 'models/text-embedding-004'),
      ],
    );
  }
}

class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }
}
