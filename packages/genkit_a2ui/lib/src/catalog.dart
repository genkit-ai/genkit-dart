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

/// The bundled A2UI "Basic Catalog" used by the `a2ui()` middleware.
///
/// A catalog pins the set of components a surface may render. The middleware
/// uses it for two things: (1) telling the model what it may render (prompt
/// injection), and (2) validating emitted envelopes only reference known
/// components. The renderer on the client registers a matching catalog under the
/// same [A2uiCatalog.id].
///
/// The catalog *types* live in `catalog_types.dart` and match the wire format
/// of the spec's `catalog.json`. This library only defines the bundled basic
/// catalog and the prompt rendering built on top of it.
library;

import 'basic_functions.dart';
import 'catalog_types.dart';
import 'express.dart';
import 'types.dart';

// The catalog types live in `catalog_types.dart` (they mirror the spec's
// `catalog.json`), but this library stays their canonical import site.
export 'catalog_types.dart'
    show
        A2uiCatalog,
        A2uiCatalogComponent,
        A2uiCatalogFunction,
        A2uiDynamicType,
        A2uiParam;

/// The registry value type under which A2UI catalogs are stored, so the
/// `a2ui()` middleware can look them up by id. Register with
/// `registry.registerValue(...)` via `loadCatalog`.
const String a2uiCatalogValueType = 'a2ui-catalog';

/// The default catalog id used by the `a2ui()` middleware when none is given.
/// Resolves to the bundled [basicCatalog].
const String defaultCatalogId = 'basic';

/// The icon names the bundled basic catalog's `Icon` component accepts. It is
/// an enum in the catalog, so the prompt lists the names and a block using any
/// other name fails to compile (and goes to repair, if enabled).
const List<String> basicIconNames = [
  'accountCircle',
  'add',
  'arrowBack',
  'arrowForward',
  'attachFile',
  'calendarToday',
  'call',
  'camera',
  'check',
  'close',
  'delete',
  'download',
  'edit',
  'event',
  'error',
  'fastForward',
  'favorite',
  'favoriteOff',
  'folder',
  'help',
  'home',
  'info',
  'locationOn',
  'lock',
  'lockOpen',
  'mail',
  'menu',
  'moreVert',
  'moreHoriz',
  'notificationsOff',
  'notifications',
  'pause',
  'payment',
  'person',
  'phone',
  'photo',
  'play',
  'print',
  'refresh',
  'rewind',
  'search',
  'send',
  'settings',
  'share',
  'shoppingCart',
  'skipNext',
  'skipPrevious',
  'star',
  'starHalf',
  'starOff',
  'stop',
  'upload',
  'visibility',
  'visibilityOff',
  'volumeDown',
  'volumeMute',
  'volumeOff',
  'volumeUp',
  'warning',
];

/// The A2UI "Basic Catalog" (v0.9), mirroring the components published by the
/// A2UI basic catalog. Use this to render standard UI without defining your own
/// design system.
///
/// Declared with [A2uiCatalogComponent.simple], which emits the spec's
/// `catalog.json` schema shape. Parameter order matches the published catalog,
/// since it is the positional argument order in A2UI Express (a test pins
/// this).
///
/// It is deliberately narrower than the published schema, to steer the model
/// toward what renders well: components do not take the shared `weight`
/// property, and `Icon.name` accepts only the [basicIconNames] (not a data
/// binding or an SVG path). Load the published `catalog.json` with
/// `loadCatalog(file:)` for the full schema.
final A2uiCatalog basicCatalog = A2uiCatalog(
  id: basicCatalogId,
  functions: basicFunctions,
  components: [
    A2uiCatalogComponent.simple(
      name: 'Text',
      description:
          'Displays a run of text. For headings/titles set the `variant` prop '
          '(h1..h5) rather than embedding Markdown; the text itself may use '
          'inline Markdown.',
      params: [
        const A2uiParam.dynamicValue(
          'text',
          required: true,
          description: 'The text content to display.',
        ),
        const A2uiParam.string(
          'variant',
          description: 'A hint for the base text style.',
          enumValues: ['h1', 'h2', 'h3', 'h4', 'h5', 'caption', 'body'],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Image',
      description: 'Displays an image from a URL.',
      params: [
        const A2uiParam.dynamicValue(
          'url',
          required: true,
          description: 'The URL of the image to display.',
        ),
        const A2uiParam.dynamicValue(
          'description',
          description: 'Accessibility text for the image.',
        ),
        const A2uiParam.string(
          'fit',
          description: 'How the image is resized to fit its container.',
          enumValues: ['contain', 'cover', 'fill', 'none', 'scaleDown'],
        ),
        const A2uiParam.string(
          'variant',
          description: 'A hint for the image size and style.',
          enumValues: [
            'icon',
            'avatar',
            'smallFeature',
            'mediumFeature',
            'largeFeature',
            'header',
          ],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Icon',
      description:
          'Displays a named material icon. `name` MUST be one of the exact '
          'names listed - do NOT invent names (e.g. there is no "cloud", '
          '"air", or "thermostat"). If none fits, omit the Icon.',
      params: [
        A2uiParam.string(
          'name',
          required: true,
          description: 'The name of the icon to display.',
          enumValues: basicIconNames,
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Row',
      description: 'Lays out children horizontally.',
      params: [
        const A2uiParam.children(
          'children',
          required: true,
          description: 'The ids of the child components.',
        ),
        const A2uiParam.string(
          'justify',
          description: 'Arrangement of children along the main axis.',
          enumValues: [
            'start',
            'center',
            'end',
            'spaceAround',
            'spaceBetween',
            'spaceEvenly',
            'stretch',
          ],
        ),
        A2uiParam.string(
          'align',
          description: 'Alignment of children along the cross axis.',
          enumValues: ['start', 'center', 'end', 'stretch'],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Column',
      description: 'Lays out children vertically.',
      params: [
        A2uiParam.children(
          'children',
          required: true,
          description: 'The ids of the child components.',
        ),
        A2uiParam.string(
          'justify',
          description: 'Arrangement of children along the main axis.',
          enumValues: [
            'start',
            'center',
            'end',
            'spaceBetween',
            'spaceAround',
            'spaceEvenly',
            'stretch',
          ],
        ),
        A2uiParam.string(
          'align',
          description: 'Alignment of children along the cross axis.',
          enumValues: ['start', 'center', 'end', 'stretch'],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'List',
      description:
          'A list of children. Use `_template(path, itemVar)` for `children` '
          'to generate items from a data-model list.',
      params: [
        A2uiParam.children(
          'children',
          required: true,
          description:
              'A fixed list of child ids, or a _template(...) binding.',
        ),
        A2uiParam.string(
          'direction',
          description: 'The direction items are laid out in.',
          enumValues: ['vertical', 'horizontal'],
        ),
        A2uiParam.string(
          'align',
          description: 'Alignment of children along the cross axis.',
          enumValues: ['start', 'center', 'end', 'stretch'],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Card',
      description: 'A visually-contained card wrapping a single child.',
      params: [
        A2uiParam.child(
          'child',
          required: true,
          description:
              'The id of the single child. Wrap multiple elements in a '
              'Column or Row and pass that container id here.',
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Divider',
      description: 'A horizontal or vertical separator line.',
      params: [
        A2uiParam.string(
          'axis',
          description: 'The orientation of the divider.',
          enumValues: ['horizontal', 'vertical'],
        ),
      ],
    ),
    A2uiCatalogComponent.simple(
      name: 'Button',
      description: 'A clickable button that fires an action back to the agent.',
      params: [
        A2uiParam.child(
          'child',
          required: true,
          description: 'The id of the child, usually a Text component.',
        ),
        A2uiParam.string(
          'variant',
          description: 'A hint for the button style.',
          enumValues: ['default', 'primary', 'borderless'],
        ),
        A2uiParam.action(
          'action',
          required: true,
          description:
              'The action to fire, e.g. Event("refresh"). The event name is '
              'sent back to the agent when the button is pressed.',
        ),
      ],
      checkable: true,
    ),
    A2uiCatalogComponent.simple(
      name: 'TextField',
      description: 'A single- or multi-line text input.',
      params: [
        A2uiParam.dynamicValue(
          'label',
          required: true,
          description: 'The text label for the input field.',
        ),
        A2uiParam.dynamicValue(
          'value',
          description: 'The value of the text field.',
        ),
        A2uiParam.string(
          'variant',
          description: 'The type of input field to display.',
          enumValues: ['shortText', 'longText', 'number', 'obscured'],
        ),
      ],
      checkable: true,
    ),
    A2uiCatalogComponent.simple(
      name: 'CheckBox',
      description: 'A labeled checkbox.',
      params: [
        A2uiParam.dynamicValue(
          'label',
          required: true,
          description: 'The text to display next to the checkbox.',
        ),
        A2uiParam.dynamicValue(
          'value',
          required: true,
          description: 'The current state of the checkbox.',
          type: .boolean,
        ),
      ],
      checkable: true,
    ),
    A2uiCatalogComponent.simple(
      name: 'Slider',
      description: 'A numeric slider.',
      params: [
        A2uiParam.dynamicValue(
          'label',
          description: 'The label for the slider.',
        ),
        A2uiParam.number('min', description: 'The minimum value.'),
        A2uiParam.number(
          'max',
          required: true,
          description: 'The maximum value.',
        ),
        A2uiParam.dynamicValue(
          'value',
          required: true,
          description: 'The current value.',
          type: .number,
        ),
      ],
      checkable: true,
    ),
  ],
);

/// Builds the "make it look good" styling tips, scoped to the components the
/// catalog actually provides so a custom catalog is never told to emit
/// components it lacks (which would then fail validation).
String _renderStyleTips(Set<String> has) {
  final tips = <String>[];
  final containers = ['Card', 'Column', 'Row'].where(has.contains).toList();
  if (containers.isNotEmpty) {
    tips.add(
      '- Group related content with layout components '
      '(${containers.join('/')}) and give it a clear hierarchy.',
    );
  }
  if (has.contains('Text')) {
    tips.add(
      '- Give titles a heading variant (e.g. h2/h3) and secondary text the '
      'caption variant instead of embedding "#"/"##" heading markers in the '
      'text.',
    );
  }
  final accents = ['Icon', 'Divider', 'Image'].where(has.contains).toList();
  if (accents.isNotEmpty) {
    tips.add(
      '- Use ${accents.join('/')} to add visual meaning and separate sections '
      'where it helps.',
    );
  }
  if (has.contains('Button')) {
    tips.add('- Give primary buttons the "primary" variant.');
  }
  return tips.isNotEmpty
      ? '\n\n## Style\n\nMake it look good, not bland:\n${tips.join('\n')}'
      : '';
}

/// Builds a worked example. Uses a weather card when the catalog has the
/// components for it (the common case, e.g. the basic catalog); otherwise
/// falls back to a minimal example built only from components the catalog
/// provides, so the example never references unknown components.
String _renderExample(A2uiCatalog catalog, Set<String> has) {
  if (has.containsAll(['Card', 'Column', 'Text', 'Button'])) {
    // The Button shows the label as its own component: `child` is a component
    // id slot, the easiest thing to get wrong.
    return r'''


## Example

A weather card:
<a2ui>
surface("tokyo-weather")
$/temp = "18°C"
root = Card(body)
body = Column([title, temp, refresh])
title = Text("Weather in Tokyo", "h3")
temp = Text($/temp)
refresh = Button(Text("Refresh"), "primary", Event("refresh", {city: "Tokyo"}))
</a2ui>''';
  }
  // `Name()` only compiles for a component with no required properties; with
  // none such, no example beats one that teaches a compile error.
  final rootComponent = catalog.components.values
      .where((c) => !_hasRequiredProps(c))
      .firstOrNull
      ?.name;
  if (rootComponent == null) return '';
  return '''


## Example

A minimal surface:
<a2ui>
surface("example")
root = $rootComponent()
</a2ui>''';
}

/// Whether [c] requires a property besides its `component` discriminator.
bool _hasRequiredProps(A2uiCatalogComponent c) =>
    [c.schema, ...?(c.schema['allOf'] as List?)].any(
      (part) =>
          part is Map &&
          (part['required'] as List? ?? const []).any((r) => r != 'component'),
    );

/// Renders a catalog into model-facing instructions: when and how to render
/// UI, then the A2UI Express contract and the catalog's signatures (from
/// `a2ui_agent`). Injected into the system prompt by the middleware when
/// `instructions != 'none'`.
String renderCatalogInstructions(A2uiCatalog catalog) {
  final has = catalog.components.keys.toSet();

  // Forms guidance only applies if the catalog has input components.
  final inputs = [
    'TextField',
    'CheckBox',
    'Slider',
  ].where(has.contains).toList();
  final formsSection = inputs.isNotEmpty
      ? '''


## Forms

Input components (${inputs.join(', ')}) do NOT send their values
automatically. To capture what the user entered you MUST do BOTH:
1. Bind each input's value to a data-model path, e.g.
   `email = TextField("Email", \$/email)`. Typing updates the data model.
2. On the submit Button, echo those same paths in the Event context, e.g.
   `Event("submit", {email: \$/email})`.
Without both, the action arrives with an empty context and the entered values
are lost.'''
      : '';

  return '''# Rendering UI with A2UI

You can render rich, interactive UI (not just text) by emitting an A2UI
surface. Render one when the answer is data the user will look at or act on:
results from tools, comparisons, choices to pick from, forms, dashboards, or
anything interactive. You may still write normal prose before or after it.

Do NOT render a surface for conversation: greetings, small talk, opinions,
advice, explanations, or facts that read fine as a few sentences. Answer those
in prose. A surface that only holds paragraphs of text is worse than the text.

## Surfaces

- Start every <a2ui> block with surface("<id>"). For a new surface, choose a
  new, short, descriptive id (e.g. "tokyo-weather").
- To change a surface you already rendered (e.g. after the user presses one of
  its buttons), reuse its id. Either render it again in full, with a `root`,
  which replaces it, or, for a small change, leave out `root` and write only
  what changed: data paths (`\$/temp = "21°C"`) and components redefined
  under their existing variable names. A redefined component replaces the old
  one entirely, so restate all of its arguments. Every variable a component
  uses must be assigned in the same block, so redefining a parent means
  redefining its children too. Everything the block does not mention stays as
  it was. (The rule that a tree needs a `root` is for new surfaces and full
  re-renders.)
- Give containers their own variables (as `body` in the example), so a later
  update can redefine them.
- User actions arrive as lines like
  `[UI action "refresh" from refresh on surface tokyo-weather context={"city":"Tokyo"}]`.$formsSection${_renderStyleTips(has)}${_renderExample(catalog, has)}

${ExpressEngine.of(catalog).promptSnippet}${_renderCatalogGuidance(catalog)}

Do not explain the Express code; just emit the block.''';
}

/// The catalog's own `instructions`. `a2ui_agent` includes them only for v1.0
/// catalogs, so for v0.9 they are added here.
String _renderCatalogGuidance(A2uiCatalog catalog) =>
    switch (catalog.instructions?.trim()) {
      final String text when text.isNotEmpty =>
        '\n\n## Catalog instructions\n\n$text',
      _ => '',
    };
