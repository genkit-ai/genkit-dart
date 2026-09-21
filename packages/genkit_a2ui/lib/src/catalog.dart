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

import 'catalog_types.dart';
import 'express/signature.dart';
import 'types.dart';

// The catalog types moved to `catalog_types.dart` (they now mirror the spec's
// `catalog.json`), but this library stays their canonical import site.
export 'catalog_types.dart'
    show A2uiCatalog, A2uiCatalogComponent, A2uiCatalogFunction;
export 'express/signature.dart' show A2uiParam, A2uiSignature;

/// The registry value type under which A2UI catalogs are stored, so the
/// `a2ui()` middleware can look them up by id. Register with
/// `registry.registerValue(...)` via `loadCatalog`.
const String a2uiCatalogValueType = 'a2ui-catalog';

/// The default catalog id used by the `a2ui()` middleware when none is given.
/// Resolves to the bundled [basicCatalog].
const String defaultCatalogId = 'basic';

/// The set of icon names the basic catalog's `Icon` component supports. Names
/// outside this list render as literal text (the renderer degrades gracefully),
/// so the prompt lists them to steer the model toward valid names. Note the
/// middleware validates component *types* against the catalog but does not
/// validate individual `Icon` name values.
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
/// `catalog.json` schema shape. Parameter order here *is* the Express
/// positional argument order, and it matches the published catalog.
final A2uiCatalog basicCatalog = A2uiCatalog.of(
  id: basicCatalogId,
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
        A2uiParam.string(
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
          ref: 'DynamicBoolean',
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
          ref: 'DynamicNumber',
        ),
      ],
      checkable: true,
    ),
  ],
);

/// Builds the "make it look good" styling tips, scoped to the components the
/// catalog actually provides so a custom catalog is never told to emit
/// components it lacks (which would then fail `validate: 'strict'`).
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
      '- Give titles a heading `variant` (e.g. h2/h3) and secondary text the '
      '`caption` variant instead of embedding "#"/"##" heading markers in '
      'the text.',
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
      ? '\n\nMake it look good, not bland:\n${tips.join('\n')}'
      : '';
}

/// Builds a worked example. Uses a rich Card/Column/Text layout when the catalog
/// supports it (the common case, e.g. the basic catalog); otherwise falls back
/// to a minimal example built only from components the catalog provides, so the
/// example never references unknown components.
String _renderExample(A2uiCatalog catalog, Set<String> has) {
  if (has.contains('Card') && has.contains('Column') && has.contains('Text')) {
    // Include a Button when the catalog has one: its `child` is an id slot,
    // the easiest thing to get wrong, so the example shows the label defined
    // as its own component rather than inlined as a string.
    final button = has.contains('Button')
        ? '''
refreshLabel = Text("Refresh")
refreshBtn = Button(refreshLabel, "primary", Event("refresh"))
'''
        : '';
    final children = has.contains('Button')
        ? '[title, temp, refreshBtn]'
        : '[title, temp]';
    return '''


Example (a small weather card):
<a2ui>
\$/temp = "18\u00b0C"
root = Card(body)
body = Column($children)
title = Text("Weather in Tokyo", "h3")
temp = Text(\$/temp)
$button</a2ui>''';
  }
  // Minimal fallback: root uses whatever the catalog's first component is.
  final rootComponent = catalog.components.isNotEmpty
      ? catalog.components.values.first.name
      : 'Text';
  return '''


Example (a minimal surface):
<a2ui>
root = $rootComponent()
</a2ui>''';
}

/// The component's schema `description`, as a trailing prompt fragment.
String _describe(A2uiCatalogComponent c) {
  final description = c.schema['description'];
  return description is String && description.isNotEmpty ? ' $description' : '';
}

/// Renders the allowed values of any enum-constrained params, so the model is
/// told which literals are valid (notably the long `Icon.name` allow-list).
String _enumDocs(A2uiCatalogComponent c) {
  final lines = <String>[];
  for (final p in c.signature.params) {
    final values = p.enumValues;
    if (values != null && values.isNotEmpty) {
      lines.add('\n    ${p.name}: one of ${values.join(', ')}.');
    }
  }
  return lines.join();
}

/// Renders a catalog into model-facing instructions describing the A2UI protocol
/// and the available components. Injected into the system prompt by the
/// middleware when `instructions != 'none'`.
String renderCatalogInstructions(A2uiCatalog catalog) {
  final componentDocs = catalog.components.values
      .map((c) => '- ${c.signature.render()}${_describe(c)}${_enumDocs(c)}')
      .join('\n');

  final has = catalog.components.keys.toSet();
  final styleSection = _renderStyleTips(has);
  final exampleSection = _renderExample(catalog, has);

  // Forms guidance only applies if the catalog has input components.
  final inputs = [
    'TextField',
    'CheckBox',
    'Slider',
  ].where(has.contains).toList();
  final inputList = inputs.join(', ');
  final formsSection = inputs.isNotEmpty
      ? '''

- Forms: input components ($inputList) do NOT send their values automatically.
  To capture what the user entered you MUST do BOTH of these:
  1. Bind each input's value argument to a data-model path, e.g.
     `emailField = TextField("Email", \$/email)`.
     Typing updates the data model at that path.
  2. On the submit Button, echo those same paths in the Event context, e.g.
     `submit = Button(submitLabel, "primary", Event("submit", {email: \$/email}))`.
  Without the \$ bindings and the button's Event context, the action arrives
  with an empty context and the entered values are lost.'''
      : '';

  return '''# Rendering UI with A2UI Express

You can render rich, interactive UI (not just text) by emitting an A2UI surface.
When a result is better *shown* than *told* (weather, lists, forms, comparisons,
confirmations, anything visual or interactive), render a UI surface.

To render UI, output the interface using A2UI Express. You MUST surround the
entire Express block with the sentinel tags `<a2ui>` and `</a2ui>`. You may
still write normal prose before it. The host compiles your Express output into
the correct protocol messages automatically.

Rules:
1. Every statement assigns a component to a variable. Components may also be
   nested inline inside a parent's argument list:
     header = ComponentA("Hello", "h3")
     root = ComponentB([header, ComponentA("inline is fine too")])
   Variable names must start with a letter or underscore and contain only
   letters, digits and underscores.
2. The tree MUST have a single entry point assigned to the variable `root`.
   Containers reference their children by variable name, never by copying the
   child's definition.
3. Arguments are POSITIONAL, in the order shown in the signatures below. Do not
   write property names unless you use the keyword form (`variant="h3"`). To
   skip an optional argument in the middle, pass `_`. Trailing optional
   arguments may simply be omitted.
4. Primitives: strings use `"` or `"""` (escapes: \\n, \\t, \\\\, \\"); raw strings
   are prefixed with `r` (e.g. `r"^[0-9]+\$"`); numbers are plain (42, 3.14);
   booleans are true/false; null is null.
5. Lists use square brackets: [child1, child2]. Maps use braces with literal
   keys: {title: "Overview"}.
6. Data bindings prefix a data-model path with `\$`: absolute paths look like
   `\$/user/firstName`, and inside a list template a relative path looks like
   `\$firstName`.
7. Populate the data model by assigning to an absolute path:
   `\$/title = "Enable notifications"`. Values may be primitives, arrays or maps.
8. Interactive components take an action built with the reserved `Event`
   helper: `Event("refresh")` or `Event("save", {email: \$/email})`. The event
   name is sent back to you when the user interacts, so choose meaningful
   names.
9. For a list generated from data, use the reserved `_template` helper and
   define the item component separately:
     itemList = ComponentB(_template(\$/forecast, item))
     item = ComponentA(\$day)
10. Validation rules are prefixed with `?`, e.g. `?required` or
    `?regex(r"^[0-9]{5}\$", "Must be 5 digits")`. Group several in a list:
    [?required, ?email].
11. Arguments marked `(static)` in the signatures below MUST be inline literals;
    they cannot take a `\$` data binding.
12. Arguments marked `(id)` hold the NAME OF ANOTHER COMPONENT, never a piece
    of text. Define that component on its own line and pass its variable name.
    For a labelled button, the label is a separate component:
      okLabel = ComponentA("OK")
      okButton = ComponentC(okLabel, _, Event("ok"))
    Passing a string there (`ComponentC("OK", ...)`) is an error: the renderer
    would look for a component named "OK" and fail.$formsSection
13. When a user interacts with a surface (e.g. presses a button) and you respond
    with updated UI, RE-RENDER THE WHOLE SURFACE: emit a complete block with a
    `root` again. Do not emit a fragment expecting a previous surface to still
    exist.$styleSection

The catalogId to use is:
"${catalog.id}"

Available components (use these exact positional signatures):
$componentDocs$exampleSection

Do not explain the Express code; just emit the block.''';
}
