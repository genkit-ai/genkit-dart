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
import 'package:a2ui_core/a2ui_core.dart' show A2uiValidationError;
import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_a2ui/src/catalog_types.dart' show A2uiCatalogCore;
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

    test('bundled components take their arguments in the published order', () {
      // Express is positional: if a bundled component's properties drifted
      // from the published order, generated arguments would silently bind to
      // the wrong properties. The bundled catalog may leave properties out
      // (it is deliberately narrower), but only from the end.
      // Own properties, whether at the top level (as `.simple` writes them)
      // or in an `allOf` entry (as the published file does).
      List<String> order(Map<String, dynamic> schema) => [
        for (final part in [schema, ...?(schema['allOf'] as List?)])
          if (part case {'properties': final Map props})
            for (final key in props.keys)
              if (key != 'component') key as String,
      ];
      final published = loadSpecCatalog();
      for (final MapEntry(key: name, value: bundled)
          in basicCatalog.components.entries) {
        final mine = order(bundled.schema);
        final theirs = order(published.components[name]!.schema);
        expect(
          theirs.take(mine.length),
          mine,
          reason: '$name: $mine is not a prefix of the published $theirs',
        );
      }
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
        // Encoded, so key order (positional in Express) is compared too.
        expect(
          jsonEncode(function.toJson()),
          jsonEncode(published[name]!.toJson()),
          reason: name,
        );
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
              type: .number,
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
        throwsA(isA<A2uiValidationError>()),
      );
    });

    test('round-trips through catalog JSON', () {
      final restored = A2uiCatalog.fromJson(
        jsonDecode(jsonEncode(catalog.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), catalog.toJson());
    });
  });

  group('A2uiCatalog', () {
    A2uiCatalogComponent text(String name, String param) =>
        A2uiCatalogComponent.simple(
          name: name,
          params: [A2uiParam.dynamicValue(param)],
        );

    test('reads the id from catalogId, then \$id, then id', () {
      Map<String, dynamic> doc(Map<String, dynamic> ids) => {
        ...ids,
        'components': <String, dynamic>{},
      };
      expect(
        A2uiCatalog.fromJson(
          doc({'catalogId': 'a', r'$id': 'b', 'id': 'c'}),
        ).id,
        'a',
      );
      expect(A2uiCatalog.fromJson(doc({r'$id': 'b', 'id': 'c'})).id, 'b');
      expect(A2uiCatalog.fromJson(doc({'id': 'c'})).id, 'c');
      // A non-string id is skipped rather than thrown on.
      expect(A2uiCatalog.fromJson(doc({'catalogId': 1, 'id': 'c'})).id, 'c');
    });

    test('extend replaces a same-named entry in place', () {
      final base = A2uiCatalog(
        id: 'base',
        components: [text('A', 'a'), text('B', 'b'), text('C', 'c')],
      );
      final extended = base.extend(
        id: 'ext',
        components: [text('B', 'other'), text('D', 'd')],
      );
      expect(extended.components.keys, ['A', 'B', 'C', 'D']);
      expect(
        (extended.components['B']!.schema['properties'] as Map).keys,
        contains('other'),
      );
      // The base is untouched.
      expect(base.components.keys, ['A', 'B', 'C']);
    });

    test('is unmodifiable', () {
      expect(
        () => basicCatalog.components.remove('Icon'),
        throwsUnsupportedError,
      );
    });

    test('round-trips instructions and hands them to a2ui_core', () {
      final catalog = A2uiCatalog.fromJson({
        'catalogId': 'x',
        'components': {'Banner': text('Banner', 'title').schema},
        'instructions': 'Keep banners short.',
      });
      expect(catalog.instructions, 'Keep banners short.');
      expect(catalog.toJson()['instructions'], 'Keep banners short.');
      expect(catalog.toCore().instructions, 'Keep banners short.');
      expect(
        catalog.extend(id: 'y').instructions,
        'Keep banners short.',
        reason: 'extend keeps the base instructions unless given new ones',
      );
    });
  });

  group('A2uiCatalog construction', () {
    test(
      'rejects duplicate and reserved param names in release builds too',
      () {
        expect(
          () => A2uiCatalogComponent.simple(
            name: 'X',
            params: [A2uiParam.number('a'), A2uiParam.number('a')],
          ),
          throwsArgumentError,
        );
        expect(
          () => A2uiCatalogComponent.simple(
            name: 'X',
            params: [A2uiParam.number('component')],
          ),
          throwsArgumentError,
        );
        expect(
          () => A2uiCatalog(
            id: 'x',
            components: [
              A2uiCatalogComponent.simple(name: 'A', params: []),
              A2uiCatalogComponent.simple(name: 'A', params: []),
            ],
          ),
          throwsArgumentError,
        );
      },
    );

    test('fromJson rejects the pre-spec components list', () {
      expect(
        () => A2uiCatalog.fromJson({
          'id': 'x',
          'components': [
            {'name': 'Banner'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('fromJson honours an anyComponent union listing a subset', () {
      final catalog = A2uiCatalog.fromJson({
        'catalogId': 'x',
        'components': {
          'A': A2uiCatalogComponent.simple(name: 'A', params: []).schema,
          'B': A2uiCatalogComponent.simple(name: 'B', params: []).schema,
        },
        r'$defs': {
          'anyComponent': {
            'oneOf': [
              {r'$ref': '#/components/A'},
            ],
          },
        },
      });
      expect(catalog.components.keys, ['A']);
    });

    test('schemas are deeply immutable', () {
      final schema = basicCatalog.components['Text']!.schema;
      expect(() => schema['description'] = 'x', throwsUnsupportedError);
      expect(
        () => (schema['properties'] as Map)['text'] = {},
        throwsUnsupportedError,
      );
      final loaded = loadSpecCatalog();
      expect(
        () => (loaded.components['Text']!.schema['allOf'] as List).clear(),
        throwsUnsupportedError,
      );
    });

    test('extend does not inherit the base document title', () {
      final loaded = loadSpecCatalog();
      expect(loaded.toJson()['title'], isNotNull);
      expect(loaded.extend(id: 'mine').toJson().containsKey('title'), isFalse);
    });

    test('A2uiParam.schema uses the given schema as is', () {
      final c = A2uiCatalogComponent.simple(
        name: 'Stars',
        params: [
          const A2uiParam.schema('size', {
            'type': 'integer',
            'minimum': 1,
          }, required: true),
        ],
      );
      expect((c.schema['properties'] as Map)['size'], {
        'type': 'integer',
        'minimum': 1,
      });
      expect(c.schema['required'], ['component', 'size']);
    });
  });
}
