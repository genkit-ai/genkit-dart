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

/// Compiler tests, including the worked examples from the A2UI Express spec.
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit_a2ui/a2ui.dart';
import 'package:genkit_a2ui/src/express/compiler.dart';
import 'package:genkit_a2ui/src/express/errors.dart';
import 'package:test/test.dart';

final specCatalog = A2uiCatalog.fromJson(
  jsonDecode(File('test/fixtures/basic_catalog_v0_9_1.json').readAsStringSync())
      as Map<String, dynamic>,
);

List<A2uiEnvelope> compile(String source, {A2uiCatalog? catalog}) =>
    compileExpress(
      source,
      catalog: catalog ?? specCatalog,
      surfaceId: 'surface-1',
    );

/// The `components` array of the `updateComponents` envelope.
List<Map<String, dynamic>> componentsOf(List<A2uiEnvelope> envelopes) {
  final update = envelopes.firstWhere((e) => e['updateComponents'] != null);
  return ((update['updateComponents'] as Map)['components'] as List)
      .cast<Map<String, dynamic>>();
}

/// Looks up one compiled component by id.
Map<String, dynamic> byId(List<A2uiEnvelope> envelopes, String id) =>
    componentsOf(envelopes).firstWhere((c) => c['id'] == id);

void main() {
  group('envelope construction', () {
    test('emits the v0.9 create + update pair', () {
      final envelopes = compile('root = Text("hello")');
      expect(envelopes, hasLength(2));
      expect(envelopes[0]['createSurface'], isNotNull);
      expect(envelopes[1]['updateComponents'], isNotNull);
      expect(envelopes[0]['version'], 'v0.9');
    });

    test('uses the supplied surface id and catalog id', () {
      final create = compile('root = Text("x")')[0]['createSurface'] as Map;
      expect(create['surfaceId'], 'surface-1');
      expect(create['catalogId'], specCatalog.id);
    });

    test('surface() overrides the target surface and catalog', () {
      final envelopes = compile('''
surface("dash-1", "https://example.com/catalog.json")
root = Text("x")
''');
      final create = envelopes[0]['createSurface'] as Map;
      expect(create['surfaceId'], 'dash-1');
      expect(create['catalogId'], 'https://example.com/catalog.json');
    });

    test('compiles several surfaces in one block', () {
      final envelopes = compile('''
surface("a")
root = Text("first")
surface("b")
root = Text("second")
''');
      final ids = envelopes
          .where((e) => e['createSurface'] != null)
          .map((e) => (e['createSurface'] as Map)['surfaceId'])
          .toList();
      expect(ids, ['a', 'b']);
    });

    test('deleteSurface compiles to a lifecycle envelope', () {
      final envelopes = compile('deleteSurface("dash-1")');
      expect(envelopes.single['deleteSurface'], {'surfaceId': 'dash-1'});
    });

    test('a data-only block emits just updateDataModel', () {
      final envelopes = compile(r'$/title = "Enable notifications"');
      expect(envelopes, hasLength(1));
      final update = envelopes.single['updateDataModel'] as Map;
      expect(update['path'], '/');
      expect(update['value'], {'title': 'Enable notifications'});
    });

    test('throws when a render block has no root', () {
      expect(
        () => compile('body = Text("orphan")'),
        throwsA(isA<ExpressCompileError>()),
      );
    });
  });

  group('adjacency list flattening', () {
    test('variable names become component ids', () {
      final envelopes = compile('''
root = Card(body)
body = Column([title])
title = Text("Weather", "h3")
''');
      expect(byId(envelopes, 'root'), {
        'id': 'root',
        'component': 'Card',
        'child': 'body',
      });
      expect(byId(envelopes, 'body')['children'], ['title']);
      expect(byId(envelopes, 'title')['text'], 'Weather');
    });

    test('hoists inline components and references the generated id', () {
      final envelopes = compile('root = Card(Text("inline"))');
      final child = byId(envelopes, 'root')['child'] as String;
      expect(child, contains('inline'));
      expect(byId(envelopes, child)['text'], 'inline');
    });

    test('throws on a reference to an undefined variable', () {
      expect(
        () => compile('root = Card(missing)'),
        throwsA(isA<ExpressCompileError>()),
      );
    });
  });

  group('positional argument mapping', () {
    test('maps positional args onto schema properties in order', () {
      final text = byId(compile('root = Text("hi", "h3")'), 'root');
      expect(text['text'], 'hi');
      expect(text['variant'], 'h3');
    });

    test('supports keyword arguments', () {
      final text = byId(
        compile('root = Text(variant="h1", text="hi")'),
        'root',
      );
      expect(text['text'], 'hi');
      expect(text['variant'], 'h1');
    });

    test('an underscore skips a middle argument', () {
      // Column(children, justify?, align?) - `_` leaves justify unset so
      // "center" lands on align.
      final column = byId(
        compile('root = Column([a], _, "center")\na = Text("x")'),
        'root',
      );
      expect(column.containsKey('justify'), isFalse);
      expect(column['align'], 'center');
    });

    test('trailing optional arguments may be omitted', () {
      expect(
        byId(compile('root = Text("only")'), 'root').containsKey('variant'),
        isFalse,
      );
    });

    test('throws on an unknown property', () {
      expect(
        () => compile('root = Text(nonsense="x")'),
        throwsA(isA<ExpressCompileError>()),
      );
    });

    test('throws when a property is supplied twice', () {
      expect(
        () => compile('root = Text("positional", text="keyword")'),
        throwsA(isA<ExpressCompileError>()),
      );
    });

    test('throws on a component outside the catalog', () {
      expect(
        () => compile('root = Sparkline([1, 2])'),
        throwsA(isA<ExpressCompileError>()),
      );
    });
  });

  group('data binding', () {
    test('compiles absolute and relative paths', () {
      final envelopes = compile(r'''
root = List(_template($/items, row))
row = Text($label)
''');
      expect(byId(envelopes, 'root')['children'], {
        'path': '/items',
        'componentId': 'row',
      });
      expect(byId(envelopes, 'row')['text'], {'path': 'label'});
    });

    test('rejects a binding on a static property', () {
      // Text.variant is a plain enum, so it cannot take `$/path`.
      expect(
        () => compile(r'root = Text("hi", $/variant)'),
        throwsA(
          isA<ExpressCompileError>().having(
            (e) => e.message,
            'message',
            contains('static'),
          ),
        ),
      );
    });

    test('builds a nested dataModel from path assignments', () {
      final envelopes = compile(r'''
$/user/name = "Alice"
$/user/age = 30
root = Text($/user/name)
''');
      expect((envelopes.last['updateDataModel'] as Map)['value'], {
        'user': {'name': 'Alice', 'age': 30},
      });
    });
  });

  group('events, functions and checks', () {
    test('compiles Event with a context map', () {
      final envelopes = compile(r'''
root = Button(label, _, Event("save", {rep: $/form/rep}))
label = Text("Save")
''');
      expect(byId(envelopes, 'root')['action'], {
        'event': {
          'name': 'save',
          'context': {
            'rep': {'path': '/form/rep'},
          },
        },
      });
    });

    test('compiles a catalog client function call', () {
      final envelopes = compile(r'root = Text(formatString("Hi ${/name}!"))');
      expect(byId(envelopes, 'root')['text'], {
        'call': 'formatString',
        'args': {'value': r'Hi ${/name}!'},
      });
    });

    test('a bare check inherits the component value binding', () {
      final envelopes = compile(
        r'root = TextField("Email", $/email, _, [?required])',
      );
      expect(byId(envelopes, 'root')['checks'], [
        {
          'call': 'required',
          'args': {
            'value': {'path': '/email'},
          },
        },
      ]);
    });

    test('a parameterized check keeps its own arguments', () {
      final envelopes = compile(
        r'root = TextField("Zip", $/zip, _, [?regex(r"^[0-9]{5}$")])',
      );
      final check = (byId(envelopes, 'root')['checks'] as List).single as Map;
      expect(check['call'], 'regex');
      expect((check['args'] as Map)['pattern'], r'^[0-9]{5}$');
      expect((check['args'] as Map)['value'], {'path': '/zip'});
    });
  });

  group('the spec worked examples', () {
    // From specification/proposals/express/a2ui_express.md.
    test('notification permission card', () {
      final envelopes = compile(r'''
root = Card(main_column)
main_column = Column([icon, title, description, actions], _, "center")
icon = Icon($/icon)
title = Text($/title, "h3")
description = Text($/description, "body")
actions = Row([yes_btn, no_btn], "center")
yes_btn = Button(yes_btn_text, _, Event("accept"))
yes_btn_text = Text("Yes")
no_btn = Button(no_btn_text, _, Event("decline"))
no_btn_text = Text("No")
$/icon = "check"
$/title = "Enable notification"
''');

      expect(byId(envelopes, 'root')['child'], 'main_column');
      expect(byId(envelopes, 'main_column')['children'], [
        'icon',
        'title',
        'description',
        'actions',
      ]);
      expect(byId(envelopes, 'main_column')['align'], 'center');
      expect(byId(envelopes, 'icon')['name'], {'path': '/icon'});
      expect(byId(envelopes, 'title')['variant'], 'h3');
      expect(byId(envelopes, 'yes_btn')['child'], 'yes_btn_text');
      expect(
        ((byId(envelopes, 'yes_btn')['action'] as Map)['event'] as Map)['name'],
        'accept',
      );
      expect((envelopes.last['updateDataModel'] as Map)['value'], {
        'icon': 'check',
        'title': 'Enable notification',
      });
    });

    // From specification/proposals/express/express_dsl_examples.md.
    test('weather forecast with a list template', () {
      final envelopes = compile(r'''
root = Column([cityName, currentRow, divider, forecastList])
cityName = Text("New York")
currentRow = Row([currentTemp, currentIcon], "center", "center")
currentTemp = Text("68F")
currentIcon = Image("https://example.com/sun.png", "Sunny")
divider = Divider("horizontal")
forecastList = List(_template($/forecast, forecastItem), "vertical")
forecastItem = Row([itemDay, itemTemp], "spaceBetween", "center")
itemDay = Text($day)
itemTemp = Text($temp)
''');

      expect(byId(envelopes, 'currentRow')['justify'], 'center');
      expect(byId(envelopes, 'currentRow')['align'], 'center');
      expect(byId(envelopes, 'currentIcon'), {
        'id': 'currentIcon',
        'component': 'Image',
        'url': 'https://example.com/sun.png',
        'description': 'Sunny',
      });
      expect(byId(envelopes, 'divider')['axis'], 'horizontal');
      expect(byId(envelopes, 'forecastList')['children'], {
        'path': '/forecast',
        'componentId': 'forecastItem',
      });
      expect(byId(envelopes, 'forecastList')['direction'], 'vertical');
      expect(byId(envelopes, 'itemDay')['text'], {'path': 'day'});
    });
  });
}
