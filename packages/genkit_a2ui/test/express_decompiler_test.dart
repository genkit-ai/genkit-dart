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

/// Decompiler tests. The headline property is round-tripping: recompiling
/// decompiled output must reproduce the original envelopes, since that output
/// is replayed to the model as an example of its own work.
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_a2ui/src/express/compiler.dart';
import 'package:genkit_a2ui/src/express/decompiler.dart';
import 'package:test/test.dart';

final specCatalog = A2uiCatalog.fromJson(
  jsonDecode(File('test/fixtures/basic_catalog_v0_9_1.json').readAsStringSync())
      as Map<String, dynamic>,
);

List<A2uiEnvelope> compile(String source) =>
    compileExpress(source, catalog: specCatalog, surfaceId: 'surface-1');

String decompile(List<A2uiEnvelope> envelopes) =>
    decompileExpress(envelopes, catalog: specCatalog);

/// Compiles, decompiles, and recompiles, so the two representations can be
/// compared directly.
void expectRoundTrip(String source) {
  final original = compile(source);
  final recompiled = compile(decompile(original));
  expect(
    jsonEncode(recompiled),
    jsonEncode(original),
    reason: 'round trip changed the envelopes\nvia:\n${decompile(original)}',
  );
}

void main() {
  group('round trips', () {
    test('a simple surface', () {
      expectRoundTrip('''
root = Card(body)
body = Column([title, temp])
title = Text("Weather in Tokyo", "h3")
temp = Text("18C")
''');
    });

    test('data bindings and a data model', () {
      expectRoundTrip(r'''
$/temp = "18C"
$/user/name = "Alice"
root = Text($/temp)
''');
    });

    test('skipped middle arguments', () {
      expectRoundTrip('''
root = Column([a], _, "center")
a = Text("x")
''');
    });

    test('events with context', () {
      expectRoundTrip(r'''
root = Button(label, "primary", Event("save", {rep: $/form/rep}))
label = Text("Save")
''');
    });

    test('list templates', () {
      expectRoundTrip(r'''
root = List(_template($/items, row), "vertical")
row = Text($label)
''');
    });

    test('client function calls with arguments', () {
      // Arguments must come back as `name=value` keyword args. Braces would
      // recompile as a single map literal in the first positional slot.
      expectRoundTrip(r'root = Text(formatString("Hi ${/name}!"))');
    });

    test('checks with arguments', () {
      expectRoundTrip(
        r'root = TextField("Zip", $/zip, _, [?regex(r"^[0-9]{5}$")])',
      );
    });

    test('a surface targeting a non-default catalog', () {
      // The catalogId must survive, or the surface silently recompiles against
      // the wrong catalog.
      final original = compile('''
surface("s9", "https://example.com/custom.json")
root = Text("x")
''');
      final recompiled = compile(decompile(original));
      expect(
        (recompiled.first['createSurface'] as Map)['catalogId'],
        'https://example.com/custom.json',
      );
    });

    test('the spec notification card', () {
      expectRoundTrip(r'''
root = Card(main_column)
main_column = Column([icon, title, actions], _, "center")
icon = Icon($/icon)
title = Text($/title, "h3")
actions = Row([yes_btn], "center")
yes_btn = Button(yes_btn_text, _, Event("accept"))
yes_btn_text = Text("Yes")
$/icon = "check"
$/title = "Enable notification"
''');
    });
  });

  group('rendering', () {
    test('emits a surface() statement for createSurface', () {
      final source = decompile(compile('root = Text("x")'));
      expect(source, startsWith('surface("surface-1")'));
    });

    test('renders components positionally, not as keywords', () {
      final source = decompile(compile('root = Text("hi", "h3")'));
      expect(source, contains('root = Text("hi", "h3")'));
    });

    test('omits trailing optional arguments', () {
      expect(decompile(compile('root = Text("hi")')), contains('Text("hi")'));
    });

    test('keeps interior gaps as underscores', () {
      final source = decompile(
        compile('root = Column([a], _, "center")\na = Text("x")'),
      );
      expect(source, contains('Column([a], _, "center")'));
    });

    test('renders child references as bare ids', () {
      final source = decompile(compile('root = Card(body)\nbody = Text("x")'));
      // `body` is an id, so it must not be quoted.
      expect(source, contains('root = Card(body)'));
    });

    test('renders bindings with the dollar sigil', () {
      expect(
        decompile(compile(r'root = Text($/temp)')),
        contains(r'Text($/temp)'),
      );
    });

    test('flattens a nested data model into one assignment per leaf', () {
      final source = decompile(
        compile(r'''
$/user/name = "Alice"
$/user/age = 30
root = Text("x")
'''),
      );
      expect(source, contains(r'$/user/name = "Alice"'));
      expect(source, contains(r'$/user/age = 30'));
    });

    test('renders deleteSurface', () {
      expect(
        decompile(compile('deleteSurface("dash-1")')),
        'deleteSurface("dash-1")',
      );
    });

    test('wraps a block in the sentinel tags', () {
      final block = decompileExpressBlock(
        compile('root = Text("x")'),
        catalog: specCatalog,
      );
      expect(block, startsWith('<a2ui>\n'));
      expect(block, endsWith('\n</a2ui>'));
    });

    test('skips envelope kinds the DSL cannot express', () {
      final source = decompile([
        {'version': 'v0.9', 'somethingFuture': <String, dynamic>{}},
      ]);
      expect(source, isEmpty);
    });
  });

  group('string forms', () {
    test('prefers a raw string for backslash-heavy values', () {
      final source = decompile(compile(r'root = Text(r"^[0-9]\d+$")'));
      expect(source, contains(r'r"^[0-9]\d+$"'));
    });

    test('uses triple quotes for embedded quotes', () {
      final source = decompile(compile(r'root = Text("say \"hi\" now")'));
      expect(source, contains('"""say "hi" now"""'));
    });

    test('escapes carriage returns rather than emitting them literally', () {
      // A literal CR in the output would be silently rewritten by any
      // line-ending normalization in transit.
      final envelopes = <A2uiEnvelope>[
        {
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 's1',
            'components': [
              {'id': 'root', 'component': 'Text', 'text': 'a\r\nb'},
            ],
          },
        },
      ];
      final source = decompile(envelopes);
      expect(source, isNot(contains('\r')));
      expect(source, contains(r'\r'));
    });

    test('escapes newlines when triple quoting does not apply', () {
      // Ends with a quote, so the triple-quoted form is unsafe and the
      // escaped single-quoted form is used instead.
      expectRoundTrip(r'root = Text("line\nends with \"")');
    });
  });
}
