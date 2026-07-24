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
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

final custom = const A2uiCatalog(
  id: 'my-catalog',
  components: [
    A2uiCatalogComponent(
      name: 'Widget',
      description: 'A widget.',
      props: 'label: string.',
    ),
  ],
);

void main() {
  late Genkit genkit;

  setUp(() {
    genkit = Genkit(isDevEnv: false);
  });

  tearDown(() async {
    await genkit.shutdown();
  });

  group('loadCatalog', () {
    test('registers an in-memory catalog under its id', () async {
      final result = await loadCatalog(
        genkit.registry,
        id: 'my-catalog',
        catalog: custom,
      );
      expect(result.id, 'my-catalog');
      expect(resolveCatalog(genkit.registry, 'my-catalog').id, 'my-catalog');
    });

    test(
      'defaults the catalog id to the registration id when absent',
      () async {
        final result = await loadCatalog(
          genkit.registry,
          id: 'anon',
          catalog: A2uiCatalog(id: '', components: custom.components),
        );
        expect(result.id, 'anon');
      },
    );

    test('throws when neither catalog nor file is provided', () async {
      await expectLater(
        loadCatalog(genkit.registry, id: 'x'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('provide either `catalog` or `file`'),
          ),
        ),
      );
    });

    group('from a file', () {
      late Directory dir;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('a2ui-loader-');
      });

      tearDown(() async {
        if (dir.existsSync()) await dir.delete(recursive: true);
      });

      test('loads and registers a catalog from a JSON file', () async {
        final file = File('${dir.path}/catalog.json');
        await file.writeAsString(jsonEncode(custom.toJson()));
        final result = await loadCatalog(
          genkit.registry,
          id: 'my-catalog',
          file: file.path,
        );
        expect(result.components.length, 1);
        expect(result.components.first.name, 'Widget');
      });

      test('throws on a missing file', () async {
        await expectLater(
          loadCatalog(genkit.registry, id: 'x', file: '${dir.path}/nope.json'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('failed to read catalog file'),
            ),
          ),
        );
      });

      test('throws on invalid JSON', () async {
        final file = File('${dir.path}/bad.json');
        await file.writeAsString('{not json}');
        await expectLater(
          loadCatalog(genkit.registry, id: 'x', file: file.path),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('not valid JSON'),
            ),
          ),
        );
      });

      test('throws when the catalog has no components array', () async {
        final file = File('${dir.path}/no-components.json');
        await file.writeAsString(jsonEncode({'id': 'x'}));
        await expectLater(
          loadCatalog(genkit.registry, id: 'x', file: file.path),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('components'),
            ),
          ),
        );
      });
    });
  });

  group('resolveCatalog', () {
    test('resolves a registered catalog by id', () async {
      await loadCatalog(genkit.registry, id: 'my-catalog', catalog: custom);
      final resolved = resolveCatalog(genkit.registry, 'my-catalog');
      expect(resolved.id, 'my-catalog');
    });

    test('falls back to the bundled basic catalog for the default id', () {
      final resolved = resolveCatalog(genkit.registry, defaultCatalogId);
      expect(resolved.id, basicCatalog.id);
    });

    test('throws for an unknown id', () {
      expect(
        () => resolveCatalog(genkit.registry, 'nope'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('no catalog registered under id "nope"'),
          ),
        ),
      );
    });
  });
}
