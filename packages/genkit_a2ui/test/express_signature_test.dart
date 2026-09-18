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

/// Pins the schema crawler to the A2UI reference implementation.
///
/// The expected strings mirror the upstream prompt contract's signature list.
/// Express is positional, so any drift here silently rebinds every generated
/// argument - these assertions are the guard against that.
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

/// The published v0.9.1 basic catalog, used unmodified.
A2uiCatalog loadSpecCatalog() {
  final raw = File(
    'test/fixtures/basic_catalog_v0_9_1.json',
  ).readAsStringSync();
  return A2uiCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  group('componentSignature against the published basic catalog', () {
    final catalog = loadSpecCatalog();

    const expected = {
      'Text': 'Text(text, variant? (static))',
      // `name` is a oneOf including a DataBinding branch, so despite the
      // enum it accepts `$/path` and is not `(static)`.
      'Icon': 'Icon(name)',
      'Card': 'Card(child (static))',
      'Divider': 'Divider(axis? (static))',
      'Image': 'Image(url, description?, fit? (static), variant? (static))',
      'Row': 'Row(children, justify? (static), align? (static))',
      'Column': 'Column(children, justify? (static), align? (static))',
      'List': 'List(children, direction? (static), align? (static))',
      'Button':
          'Button(child (static), variant? (static), action (static), '
          'checks? (static))',
      'CheckBox': 'CheckBox(label, value, checks? (static))',
    };

    expected.forEach((name, signature) {
      test('$name has the upstream positional signature', () {
        expect(catalog.components[name]!.signature.render(), signature);
      });
    });

    test('parses every component and function in the file', () {
      expect(catalog.components, hasLength(18));
      expect(catalog.functions, hasLength(14));
    });

    test('reads the catalog id from catalogId', () {
      expect(catalog.id, contains('catalogs/basic/catalog.json'));
    });
  });

  group('parameter metadata', () {
    final catalog = loadSpecCatalog();

    test('required params come from the schema required array', () {
      final text = catalog.components['Text']!.signature;
      expect(text['text']!.required, isTrue);
      expect(text['variant']!.required, isFalse);
    });

    test('binding-capable props are not static, plain enums are', () {
      final text = catalog.components['Text']!.signature;
      // `text` is a $ref to DynamicString, so it accepts `$/path`.
      expect(text['text']!.static, isFalse);
      // `variant` is a plain enum, so it must be an inline literal.
      expect(text['variant']!.static, isTrue);
      expect(text['variant']!.enumValues, contains('h3'));
    });

    test('structural component/id keys are never positional', () {
      for (final component in catalog.components.values) {
        final names = component.signature.params.map((p) => p.name);
        expect(names, isNot(contains('component')));
        expect(names, isNot(contains('id')));
      }
    });

    test('checkable components get a trailing checks param', () {
      expect(
        catalog.components['Button']!.signature.params.last.name,
        'checks',
      );
      expect(
        catalog.components['Text']!.signature.params.map((p) => p.name),
        isNot(contains('checks')),
      );
    });

    test('descriptions carry through for the prompt', () {
      expect(
        catalog.components['Image']!.signature['url']!.description,
        isNotEmpty,
      );
    });
  });

  group('functionSignature', () {
    final catalog = loadSpecCatalog();

    test('reads args properties in order', () {
      final regex = catalog.functions['regex']!.signature;
      expect(
        regex.params.map((p) => p.name),
        containsAll(['value', 'pattern']),
      );
    });

    test('openUrl exposes its required url arg', () {
      final openUrl = catalog.functions['openUrl']!.signature;
      expect(openUrl['url'], isNotNull);
      expect(openUrl['url']!.required, isTrue);
    });
  });

  group('A2uiCatalogComponent.simple', () {
    test('produces a schema the crawler reads back identically', () {
      final gauge = A2uiCatalogComponent.simple(
        name: 'Gauge',
        description: 'A circular gauge.',
        params: [
          const A2uiParam.dynamicValue('value', required: true),
          const A2uiParam.number('min'),
          const A2uiParam.string('unit', description: 'e.g. "°C".'),
        ],
      );

      expect(
        gauge.signature.render(),
        'Gauge(value, min? (static), unit? (static))',
      );
      expect(gauge.signature['value']!.static, isFalse);
      expect(gauge.signature['unit']!.description, 'e.g. "°C".');
    });

    test('checkable adds the trailing checks param', () {
      final field = A2uiCatalogComponent.simple(
        name: 'MyField',
        params: [const A2uiParam.dynamicValue('value', required: true)],
        checkable: true,
      );
      expect(field.signature.render(), 'MyField(value, checks? (static))');
    });

    test('round-trips through catalog JSON', () {
      final original = A2uiCatalog.of(
        id: 'custom',
        components: [
          A2uiCatalogComponent.simple(
            name: 'Gauge',
            params: [
              const A2uiParam.dynamicValue('value', required: true),
              const A2uiParam.number('max'),
            ],
          ),
        ],
      );
      final restored = A2uiCatalog.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(
        restored.components['Gauge']!.signature.render(),
        original.components['Gauge']!.signature.render(),
      );
    });
  });

  group('bundled basicCatalog', () {
    test('derives the same signatures as the published catalog', () {
      final published = loadSpecCatalog();
      for (final name in const ['Text', 'Card', 'Column', 'Row', 'Button']) {
        expect(
          basicCatalog.components[name]!.signature.render(),
          published.components[name]!.signature.render(),
          reason: '$name must match the published basic catalog',
        );
      }
    });

    test('keeps component names unique and non-empty', () {
      expect(basicCatalog.id, isNotEmpty);
      expect(basicCatalog.components, isNotEmpty);
    });
  });
}
