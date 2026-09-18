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

    test('includes the catalog id', () {
      expect(text, contains(basicCatalog.id));
    });

    test('lists every catalog component name', () {
      for (final c in basicCatalog.components.values) {
        expect(
          text,
          contains('- ${c.name}('),
          reason: 'expected instructions to document component ${c.name}',
        );
      }
    });

    test('tells the model to use the Express sentinel tags', () {
      expect(text, contains('<a2ui>'));
      expect(text, contains('</a2ui>'));
    });

    test('lists the basic icon allow-list', () {
      expect(text, contains(basicIconNames.first));
    });
  });

  group('renderCatalogInstructions with a custom catalog', () {
    // A catalog with none of the components the styling guidance / example
    // hardcode (Card, Column, Text, Button, inputs, ...).
    final custom = A2uiCatalog.of(
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
          text,
          isNot(matches(RegExp('\\b$name\\b'))),
          reason: 'custom-catalog instructions must not mention $name',
        );
      }
    });

    test('builds the example from a component the catalog provides', () {
      expect(text, contains('root = Widget()'));
    });

    test('still documents the custom component and catalog id', () {
      expect(text, contains('- Widget(label?) A widget.'));
      expect(text, contains('my-catalog'));
    });
  });

  group('renderCatalogInstructions with an empty catalog', () {
    test(
      'renders without throwing and without a components-driven example',
      () {
        const empty = A2uiCatalog(id: 'empty', components: {});
        final text = renderCatalogInstructions(empty);
        expect(text, contains('Rendering UI with A2UI'));
        // Falls back to a default root component name.
        expect(text, contains('root = Text()'));
      },
    );
  });
}
