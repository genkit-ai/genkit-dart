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
import 'package:genkit_ollama/genkit_ollama.dart';
import 'package:test/test.dart';

void main() {
  group('Plugin Handle', () {
    test('creates a plugin instance', () {
      expect(ollama(), isNotNull);
    });

    test('creates a plugin instance with a custom base URL', () {
      expect(ollama(baseUrl: 'http://remote:11434'), isNotNull);
    });

    test('rejects an empty name', () {
      expect(
        () => ollama(name: ''),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCodes.INVALID_ARGUMENT,
          ),
        ),
      );
    });

    test('rejects a name containing a slash', () {
      expect(() => ollama(name: 'a/b'), throwsA(isA<GenkitException>()));
    });

    test('creates a model reference', () {
      expect(ollama.model('llama3.2').name, 'ollama/llama3.2');
    });

    test('creates a model reference with a custom namespace', () {
      expect(
        ollama.model('llama3.2', namespace: 'local').name,
        'local/llama3.2',
      );
    });

    test('creates an embedder reference', () {
      expect(
        ollama.embedder('nomic-embed-text').name,
        'ollama/nomic-embed-text',
      );
    });

    test('defaults the base URL to localhost', () {
      final plugin = ollama() as OllamaPlugin;
      expect(plugin.baseUrl, defaultOllamaBaseUrl);
    });
  });

  group('init', () {
    test('registers configured models and embedders', () async {
      final plugin =
          ollama(
                models: [const CustomModelDefinition(name: 'llama3.2')],
                embedders: [
                  const OllamaEmbedderDefinition(
                    name: 'nomic-embed-text',
                    dimensions: 768,
                  ),
                ],
              )
              as OllamaPlugin;
      final actions = await plugin.init();
      final names = actions.map((a) => a.name).toList();
      expect(names, contains('ollama/llama3.2'));
      expect(names, contains('ollama/nomic-embed-text'));
    });
  });
}
