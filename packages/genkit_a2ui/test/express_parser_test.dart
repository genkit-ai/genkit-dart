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

/// Parser tests, checked against the rules in the normative `Express.g4`.
library;

import 'package:genkit_a2ui/src/express/ast.dart';
import 'package:genkit_a2ui/src/express/lexer.dart';
import 'package:genkit_a2ui/src/express/parser.dart';
import 'package:test/test.dart';

/// Parses a single statement, failing if the source holds more than one.
ExprStatement one(String source) => parseExpress(source).single;

/// Parses a single assignment's value.
ExprNode valueOf(String source) => (one(source) as ExprAssignment).value;

void main() {
  group('statements', () {
    test('parses a variable assignment', () {
      final statement = one('root = Card(body)') as ExprAssignment;
      expect(statement.target, 'root');
      expect(statement.isPath, isFalse);
      expect((statement.value as ExprCall).name, 'Card');
    });

    test('parses a data path assignment', () {
      final statement = one(r'$/title = "Hello"') as ExprAssignment;
      expect(statement.target, r'$/title');
      expect(statement.isPath, isTrue);
      expect((statement.value as ExprLiteral).value, 'Hello');
    });

    test('parses a standalone command as an expression statement', () {
      final statement = one('deleteSurface("s1")');
      final call = (statement as ExprStatementExpression).expression;
      expect((call as ExprCall).name, 'deleteSurface');
      expect((call.positional.single as ExprLiteral).value, 's1');
    });

    test('separates adjacent statements without any separator token', () {
      // Newlines are skipped by the lexer, so boundaries come from lookahead.
      final statements = parseExpress('a = Text("x")\nb = Text("y")');
      expect(statements, hasLength(2));
      expect((statements[1] as ExprAssignment).target, 'b');
    });

    test('allows one assignment to span several lines', () {
      final statements = parseExpress('''
root = Column(
  [header,
   body],
  "center",
)
''');
      expect(statements, hasLength(1));
      final call = (statements.single as ExprAssignment).value as ExprCall;
      expect(call.positional, hasLength(2));
    });

    test('parses a realistic multi-statement block', () {
      final statements = parseExpress('''
surface("main")
\$/temp = "18C"
root = Card(body)
body = Column([title, temp])
title = Text("Weather", "h3")
temp = Text(\$/temp)
''');
      expect(statements, hasLength(6));
    });
  });

  group('calls', () {
    test('parses positional arguments', () {
      final call = valueOf('x = Text("hi", "h3")') as ExprCall;
      expect(call.positional, hasLength(2));
      expect(call.named, isEmpty);
    });

    test('parses keyword arguments', () {
      final call =
          valueOf('x = Button(child=label, variant="primary")') as ExprCall;
      expect(call.positional, isEmpty);
      expect(call.named.keys, containsAll(['child', 'variant']));
      expect((call.named['child']! as ExprVar).name, 'label');
    });

    test('allows positional and keyword arguments to interleave', () {
      final call = valueOf('x = Button(label, action=Event("go"))') as ExprCall;
      expect(call.positional, hasLength(1));
      expect(call.named, hasLength(1));
    });

    test('parses the skip placeholder as a positional argument', () {
      final call = valueOf('x = Column([a], _, "center")') as ExprCall;
      expect(call.positional[1], isA<ExprSkip>());
      expect((call.positional[2] as ExprLiteral).value, 'center');
    });

    test('parses nested inline calls', () {
      final call = valueOf('x = Card(Text("inline"))') as ExprCall;
      expect((call.positional.single as ExprCall).name, 'Text');
    });

    test('parses an empty argument list', () {
      expect((valueOf('x = Divider()') as ExprCall).positional, isEmpty);
    });

    test('accepts a trailing comma', () {
      expect(
        (valueOf('x = Text("a", "b",)') as ExprCall).positional,
        hasLength(2),
      );
    });

    test('parses the _template helper like any other call', () {
      final call =
          valueOf(r'x = List(_template($/items, itemRow))') as ExprCall;
      final template = call.positional.single as ExprCall;
      expect(template.name, '_template');
      expect((template.positional[0] as ExprPath).path, '/items');
      expect((template.positional[1] as ExprVar).name, 'itemRow');
    });
  });

  group('values', () {
    test('parses paths, stripping the sigil', () {
      expect((valueOf(r'x = $/a/b') as ExprPath).path, '/a/b');
      expect((valueOf(r'x = $rel') as ExprPath).path, 'rel');
      // A lone '$' is the empty relative path.
      expect((valueOf(r'x = $') as ExprPath).path, '');
    });

    test('distinguishes absolute from relative paths', () {
      expect((valueOf(r'x = $/abs') as ExprPath).isAbsolute, isTrue);
      expect((valueOf(r'x = $rel') as ExprPath).isAbsolute, isFalse);
    });

    test('parses arrays including nesting and trailing commas', () {
      expect((valueOf('x = [a, b,]') as ExprArray).items, hasLength(2));
      expect((valueOf('x = []') as ExprArray).items, isEmpty);
      expect(
        (valueOf('x = [[a], [b]]') as ExprArray).items.first,
        isA<ExprArray>(),
      );
    });

    test('parses maps with identifier and string keys', () {
      final map = valueOf('x = {title: "Overview", "child": body}') as ExprMap;
      expect(map.entries.keys, containsAll(['title', 'child']));
      expect((map.entries['child']! as ExprVar).name, 'body');
    });

    test('parses a map value holding a path', () {
      final call = valueOf(r'x = Event("save", {rep: $/form/rep})') as ExprCall;
      final context = call.positional[1] as ExprMap;
      expect((context.entries['rep']! as ExprPath).path, '/form/rep');
    });

    test('parses bare and parameterized checks', () {
      final bare = valueOf('x = ?required') as ExprCheck;
      expect(bare.name, 'required');
      expect(bare.args, isEmpty);

      final parameterized =
          valueOf(r'x = ?regex(r"^\d+$", "digits only")') as ExprCheck;
      expect(parameterized.name, 'regex');
      expect(parameterized.args, hasLength(2));
    });

    test('parses a list of checks', () {
      final checks = valueOf('x = [?required, ?email]') as ExprArray;
      expect(checks.items.every((i) => i is ExprCheck), isTrue);
    });

    test('parses all literal kinds', () {
      expect((valueOf('x = 42') as ExprLiteral).value, 42);
      expect((valueOf('x = -3.5') as ExprLiteral).value, -3.5);
      expect((valueOf('x = true') as ExprLiteral).value, true);
      expect((valueOf('x = null') as ExprLiteral).value, isNull);
    });
  });

  group('errors', () {
    test('throws on an unclosed call', () {
      expect(
        () => parseExpress('x = Text("a"'),
        throwsA(isA<ExpressSyntaxError>()),
      );
    });

    test('throws on a missing assignment value', () {
      expect(() => parseExpress('x ='), throwsA(isA<ExpressSyntaxError>()));
    });

    test('rejects a dynamic map key', () {
      expect(
        () => parseExpress(r'x = {$/dynamic: 1}'),
        throwsA(isA<ExpressSyntaxError>()),
      );
    });

    test('reports the line the error occurred on', () {
      expect(
        () => parseExpress('a = Text("x")\nb = Text("y"'),
        throwsA(isA<ExpressSyntaxError>().having((e) => e.line, 'line', 2)),
      );
    });
  });
}
