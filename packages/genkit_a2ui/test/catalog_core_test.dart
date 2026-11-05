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

/// Pins the hand-off to a2ui_agent: every catalog shape this package accepts
/// must convert to an a2ui_core catalog that the Express compiler can use.
library;

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_agent/a2ui_agent.dart';
import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

/// The published v0.9.1 basic catalog, used unmodified.
A2uiCatalog loadSpecCatalog() => A2uiCatalog.fromJson(
  jsonDecode(File('test/fixtures/basic_catalog_v0_9_1.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Compiles one Express block against [catalog] and returns its components.
List<Map<String, Object?>> compile(A2uiCatalog catalog, String block) {
  final format = const ExpressFormatFactory().createFormat([catalog.toCore()]);
  final messages = format.createParser().compile(block);
  final update = messages
      .map((m) => m.toJson())
      .firstWhere((m) => m.containsKey('updateComponents'));
  return ((update['updateComponents']! as Map)['components']! as List)
      .cast<Map<String, Object?>>();
}

const weatherCard = '''
surface("tokyo")
title = Text("Tokyo", "h3")
refresh = Button(Text("Refresh"), action=Event("refresh", {city: "Tokyo"}))
root = Card(Column([title, refresh]))
''';

void main() {
  group('toCore', () {
    test('converts the published basic catalog', () {
      final core = loadSpecCatalog().toCore();
      expect(core.components, hasLength(18));
      expect(core.functions, hasLength(14));
    });

    test('keeps components added to a loaded catalog', () {
      // The published file lists its components in `$defs.anyComponent`; a
      // stale copy of that list would hide the extension from a2ui_core.
      final extended = loadSpecCatalog().extend(
        id: 'https://example.com/extended.json',
        components: [
          A2uiCatalogComponent.simple(
            name: 'Gauge',
            description: 'A gauge.',
            params: [const A2uiParam.dynamicValue('value', required: true)],
          ),
        ],
      );
      expect(extended.toCore().components.keys, contains('Gauge'));
      expect(extended.toCore().components, hasLength(19));
    });

    test('converts the bundled basic catalog', () {
      expect(
        basicCatalog.toCore().components.keys,
        basicCatalog.components.keys,
      );
    });

    test('declares the published basic catalog functions verbatim', () {
      final published = loadSpecCatalog().functions;
      expect(basicCatalog.functions.keys, published.keys);
      basicCatalog.functions.forEach((name, function) {
        expect(function.toJson(), published[name]!.toJson(), reason: name);
      });
    });

    test('is parsed once per catalog', () {
      expect(identical(basicCatalog.toCore(), basicCatalog.toCore()), isTrue);
    });
  });

  group('the bundled basic catalog compiles like the published one', () {
    for (final (label, catalog) in [
      ('bundled', basicCatalog),
      ('published', loadSpecCatalog()),
    ]) {
      test(label, () {
        final byId = {
          for (final c in compile(catalog, weatherCard)) c['id']: c,
        };
        expect(byId['title'], {
          'id': 'title',
          'component': 'Text',
          'text': 'Tokyo',
          'variant': 'h3',
        });
        // `child` is a component-id slot, so the inline Text is hoisted.
        expect(byId['refresh']!['child'], 'refresh_child');
        expect(byId['refresh']!['action'], {
          'event': {
            'name': 'refresh',
            'context': {'city': 'Tokyo'},
          },
        });
        expect(byId['root']!['child'], 'root_child');
      });
    }
  });

  group('A2uiCatalogComponent.simple', () {
    final catalog = basicCatalog.extend(
      id: 'custom',
      components: [
        A2uiCatalogComponent.simple(
          name: 'Gauge',
          description: 'A circular gauge.',
          params: [
            const A2uiParam.dynamicValue(
              'value',
              required: true,
              ref: 'DynamicNumber',
            ),
            const A2uiParam.number('max'),
            const A2uiParam.string('unit', enumValues: ['C', 'F']),
          ],
        ),
      ],
    );

    test('compiles positionally, in params order, with bindings', () {
      final gauge = compile(catalog, r'root = Gauge($/temp, 40, "C")').single;
      expect(gauge, {
        'id': 'root',
        'component': 'Gauge',
        'value': {'path': '/temp'},
        'max': 40,
        'unit': 'C',
      });
    });

    test('compiles a check from the catalog functions', () {
      final field = compile(
        catalog,
        r'root = TextField("Email", $/email, checks=[?required, ?email])',
      ).single;
      expect(field['checks'], hasLength(2));
    });

    test('rejects a value outside its enum', () {
      expect(
        () => compile(catalog, 'root = Gauge(1, 2, "K")'),
        throwsA(anything),
      );
    });

    test('round-trips through catalog JSON', () {
      final restored = A2uiCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), catalog.toJson());
    });
  });
}
