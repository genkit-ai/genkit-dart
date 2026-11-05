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

import 'package:genkit_a2ui/a2ui.dart';
import 'package:test/test.dart';

void main() {
  group('basicCatalog', () {
    test('has a stable id and uniquely-named components', () {
      expect(basicCatalog.id, isNotEmpty);
      // Keying by name makes duplicates impossible; assert the map is populated
      // and that each entry agrees with its key.
      expect(basicCatalog.components, isNotEmpty);
      basicCatalog.components.forEach((key, component) {
        expect(component.name, key);
      });
    });
  });

  group('renderCatalogInstructions', () {
    final text = renderCatalogInstructions(basicCatalog);

    test('includes the Express contract and every component signature', () {
      expect(text, contains('A2UI Express'));
      for (final name in basicCatalog.components.keys) {
        expect(
          text,
          contains('$name('),
          reason: 'expected instructions to document component $name',
        );
      }
    });

    test('tells the model to name surfaces and reuse ids to replace', () {
      expect(text, contains('surface("<id>")'));
      expect(text, contains('reuse its id'));
    });

    test('marks component-id slots', () {
      expect(text, contains('Card(child (component ID))'));
    });

    test('lists the basic icon allow-list', () {
      expect(text, contains(basicIconNames.first));
    });

    test('its worked example compiles against the catalog', () {
      final example = RegExp(
        r'## Example[\s\S]*?<a2ui>\n([\s\S]*?)\n</a2ui>',
      ).firstMatch(text)!.group(1)!;
      final parser = A2uiStreamParser(catalog: basicCatalog);
      final batches = [
        ...parser.push('<a2ui>\n$example\n</a2ui>').envelopeBatches,
        ...parser.flush().envelopeBatches,
      ];
      expect(batches, hasLength(1));
    });
  });

  group('renderCatalogInstructions with a custom catalog', () {
    // A catalog with none of the components the styling guidance and the
    // weather example hardcode (Card, Column, Text, Button, inputs, ...).
    final custom = A2uiCatalog(
      id: 'my-catalog',
      components: [
        A2uiCatalogComponent.simple(
          name: 'Widget',
          description: 'A widget.',
          params: [const A2uiParam.dynamicValue('label')],
        ),
      ],
    );
    final text = renderCatalogInstructions(custom);

    test('never references components the catalog does not provide', () {
      // Only the parts this package writes; the Express contract from
      // a2ui_agent uses generic placeholder names.
      final ours = text.substring(0, text.indexOf('# A2UI Express'));
      for (final name in [
        'Card',
        'Column',
        'Row',
        'Text',
        'Button',
        'Icon',
        'Divider',
        'Image',
        'TextField',
        'CheckBox',
        'Slider',
      ]) {
        expect(
          ours,
          isNot(matches(RegExp('\\b$name\\b'))),
          reason: 'custom-catalog instructions must not mention $name',
        );
      }
    });

    test('builds the example from a component the catalog provides', () {
      expect(text, contains('root = Widget()'));
    });

    test('documents the custom component', () {
      expect(text, contains('Widget(label?)'));
      expect(text, contains('A widget.'));
    });
  });

  group('renderCatalogInstructions fallback example', () {
    /// The `<a2ui>` example block in [text], compiled strictly.
    List<ParseSegment> compileExample(A2uiCatalog catalog, String text) {
      final example = RegExp(
        r'A minimal surface:\n(<a2ui>[\s\S]*?</a2ui>)',
      ).firstMatch(text)!.group(1)!;
      final parser = A2uiStreamParser(catalog: catalog);
      return [...parser.push(example).segments, ...parser.flush().segments];
    }

    test('compiles', () {
      final catalog = A2uiCatalog(
        id: 'c',
        components: [
          A2uiCatalogComponent.simple(
            name: 'Widget',
            params: [const A2uiParam.dynamicValue('label')],
          ),
        ],
      );
      final segments = compileExample(
        catalog,
        renderCatalogInstructions(catalog),
      );
      expect(segments.whereType<EnvelopeSegment>(), hasLength(1));
    });

    test('skips components with required properties', () {
      final catalog = A2uiCatalog(
        id: 'c',
        components: [
          A2uiCatalogComponent.simple(
            name: 'Gauge',
            params: [
              const A2uiParam.dynamicValue(
                'value',
                required: true,
                type: .number,
              ),
            ],
          ),
          A2uiCatalogComponent.simple(name: 'Spacer', params: []),
        ],
      );
      final text = renderCatalogInstructions(catalog);
      expect(text, contains('root = Spacer()'));
      expect(compileExample(catalog, text), isNotEmpty);
    });

    test('is left out when no component can be written bare', () {
      final catalog = A2uiCatalog(
        id: 'c',
        components: [
          A2uiCatalogComponent.simple(
            name: 'Gauge',
            params: [
              const A2uiParam.dynamicValue(
                'value',
                required: true,
                type: .number,
              ),
            ],
          ),
        ],
      );
      expect(renderCatalogInstructions(catalog), isNot(contains('## Example')));
    });

    test('an empty catalog renders without an example', () {
      final text = renderCatalogInstructions(
        A2uiCatalog(id: 'empty', components: []),
      );
      expect(text, contains('Rendering UI with A2UI'));
      expect(text, isNot(contains('## Example')));
    });
  });
}
