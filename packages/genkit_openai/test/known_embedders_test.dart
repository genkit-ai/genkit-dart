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

import 'package:genkit/plugin.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_openai/src/known_embedders.dart'
    show compatEmbedderInfo, embedderInfoFor;
import 'package:genkit_openai/src/openai_plugin.dart';
import 'package:test/test.dart';

import 'discovery_client.dart';

/// A plugin whose `GET /models` answers with [modelIds] and nothing else.
OpenAIPlugin pluginListing(List<String> modelIds, {String? baseUrl}) =>
    OpenAIPlugin(
      apiKey: 'test-key',
      baseUrl: baseUrl,
      httpClient: discoveryClient([], ids: modelIds),
    );

void main() {
  group('catalog invariants', () {
    test('the exported collections cannot be mutated', () {
      expect(() => knownEmbedderModels.add('x'), throwsUnsupportedError);
      expect(
        () => knownOpenAIEmbedders['x'] = <String, dynamic>{},
        throwsUnsupportedError,
      );
    });

    test('curated metadata is not mutable through the returned map', () {
      expect(
        () => embedderInfoFor('text-embedding-3-small')['dimensions'] = 1,
        throwsUnsupportedError,
      );
    });

    test('no two entries claim the same name', () {
      final seen = <String>{};
      for (final embedder in KnownOpenAIEmbedder.values) {
        expect(seen, isNot(contains(embedder.id)), reason: embedder.id);
        seen.add(embedder.id);
      }
    });

    test('every entry claims a positive vector length', () {
      for (final embedder in KnownOpenAIEmbedder.values) {
        expect(embedder.dimensions, greaterThan(0), reason: embedder.id);
      }
    });

    test('every listed embedder is one OpenAI still serves', () {
      for (final embedder in KnownOpenAIEmbedder.values) {
        expect(
          knownEmbedderModels.contains(embedder.id),
          embedder.stage != OpenAIModelStage.deprecated,
          reason: embedder.id,
        );
      }
    });
  });

  group('embedderInfoFor', () {
    test('a curated embedder carries its label, size and stage', () {
      final info = embedderInfoFor('text-embedding-3-small');

      expect(info['label'], 'OpenAI text-embedding-3-small');
      expect(info['dimensions'], 1536);
      expect(info['stage'], 'stable');
      expect(info['supports'], {
        'input': ['text'],
      });
    });

    test('lookup is case-insensitive', () {
      expect(embedderInfoFor('TEXT-EMBEDDING-3-LARGE')['dimensions'], 3072);
    });

    test('an uncurated embedder claims text input and no size', () {
      final info = embedderInfoFor('bge-large-en-embedding-v1.5');

      expect(info.containsKey('dimensions'), isFalse);
      expect(info.containsKey('label'), isFalse);
      expect(info['supports'], {
        'input': ['text'],
      });
    });

    test('ada-002 is superseded but still served', () {
      expect(
        KnownOpenAIEmbedder.textEmbeddingAda002.stage,
        OpenAIModelStage.legacy,
      );
      expect(knownEmbedderModels, contains('text-embedding-ada-002'));
    });

    test('only the -3- models take a shorter vector', () {
      expect(KnownOpenAIEmbedder.textEmbedding3Small.dimensionsReducible, true);
      expect(KnownOpenAIEmbedder.textEmbedding3Large.dimensionsReducible, true);
      expect(
        KnownOpenAIEmbedder.textEmbeddingAda002.dimensionsReducible,
        false,
      );
    });
  });

  group('compatEmbedderInfo', () {
    test('keeps the vector length and drops the deployment details', () {
      final info = compatEmbedderInfo('text-embedding-3-small');

      // A gateway routing this name to OpenAI returns 1536 dimensions, but
      // OpenAI's label and retirement schedule are not the backend's.
      expect(info['dimensions'], 1536);
      expect(info.containsKey('label'), isFalse);
      expect(info.containsKey('stage'), isFalse);
    });

    test('an uncurated name takes the dynamic defaults', () {
      expect(compatEmbedderInfo('nomic-embedding-text'), {
        'supports': {
          'input': ['text'],
        },
      });
    });
  });

  group('typed refs', () {
    test('name the curated embedders under the default namespace', () {
      expect(
        OpenAIEmbedders.textEmbedding3Small.name,
        'openai/text-embedding-3-small',
      );
      expect(
        OpenAIEmbedders.textEmbeddingAda002.name,
        'openai/text-embedding-ada-002',
      );
    });

    test('cover every embedder OpenAI still serves', () {
      // Nothing else fails when a catalog entry is added without a ref.
      expect(
        OpenAIEmbedders.all.map((r) => r.name).toSet(),
        knownEmbedderModels.map((id) => 'openai/$id').toSet(),
      );
    });

    test('match openAI.embedder() for the same id', () {
      expect(
        OpenAIEmbedders.textEmbedding3Large.name,
        openAI.embedder(KnownOpenAIEmbedder.textEmbedding3Large.id).name,
      );
    });

    test('carry the options schema', () {
      expect(OpenAIEmbedders.textEmbedding3Small.customOptions, isNotNull);
    });
  });

  group('list', () {
    test('lists the curated embedders without discovery', () async {
      final listing = await pluginListing(const []).list();

      expect(
        embedderNames(listing),
        knownEmbedderModels.map((id) => 'openai/$id').toSet(),
      );
    });

    test('a discovered embedder is listed as an embedder', () async {
      final listing = await pluginListing(['text-embedding-4-turbo']).list();

      expect(embedderNames(listing), contains('openai/text-embedding-4-turbo'));
      expect(
        listing
            .where((m) => m.actionType == ActionType.model)
            .map((m) => m.name),
        isNot(contains('openai/text-embedding-4-turbo')),
      );
    });

    test('a listed embedder carries its curated metadata', () async {
      final listing = await pluginListing(const []).list();
      final metadata = listing.firstWhere(
        (m) => m.name == 'openai/text-embedding-3-large',
      );
      final info = (metadata.metadata['model'] as Map).cast<String, dynamic>();

      expect(metadata.actionType, ActionType.embedder);
      expect(info['label'], 'OpenAI text-embedding-3-large');
      expect(info['dimensions'], 3072);
      // Core's own keys survive alongside the curated ones.
      expect(info['customOptions'], isNotNull);
      expect(metadata.inputSchema, isNotNull);
      expect(metadata.outputSchema, isNotNull);
    });

    test('a compat backend is left with what it reports', () async {
      final listing = await pluginListing([
        'text-embedding-3-small',
      ], baseUrl: 'https://api.deepinfra.com/v1/openai').list();
      final info =
          (listing
                      .firstWhere(
                        (m) => m.name == 'openai/text-embedding-3-small',
                      )
                      .metadata['model']
                  as Map)
              .cast<String, dynamic>();

      // The curated catalog is withheld, so only the discovered id is there.
      expect(embedderNames(listing), {'openai/text-embedding-3-small'});
      expect(info['dimensions'], 1536);
      expect(info.containsKey('stage'), isFalse);
    });
  });
}
