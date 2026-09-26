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

/// Lexer tests, checked against the rules in the normative `Express.g4`.
library;

import 'package:genkit_a2ui/src/express/lexer.dart';
import 'package:test/test.dart';

/// Tokenizes and drops the trailing EOF, which every stream ends with.
List<Token> lex(String source) =>
    tokenize(source).where((t) => t.kind != TokenKind.eof).toList();

void main() {
  group('strings', () {
    test('decodes escapes in a standard string', () {
      final tokens = lex(r'"line\nnext\ttab\"quote\\slash"');
      expect(tokens.single.kind, TokenKind.string);
      expect(tokens.single.value, 'line\nnext\ttab"quote\\slash');
    });

    test('leaves escapes untouched in a raw string', () {
      final tokens = lex(r'r"^[0-9]{5}\d+$"');
      expect(tokens.single.value, r'^[0-9]{5}\d+$');
    });

    test('supports triple-quoted strings spanning lines', () {
      final tokens = lex('"""first\nsecond"""');
      expect(tokens.single.value, 'first\nsecond');
    });

    test('supports raw triple-quoted strings', () {
      final tokens = lex(r'r"""a\nb"""');
      expect(tokens.single.value, r'a\nb');
    });

    test('a triple quote is preferred over a single quote', () {
      // Lexed as one triple-quoted string, not an empty string followed by
      // a stray quote.
      final tokens = lex('"""has "inner" quotes"""');
      expect(tokens, hasLength(1));
      expect(tokens.single.value, 'has "inner" quotes');
    });

    test('throws on an unterminated string', () {
      expect(() => lex('"oops'), throwsA(isA<ExpressSyntaxError>()));
    });
  });

  group('identifiers and implicit literals', () {
    test('a lone underscore is the skip placeholder', () {
      expect(lex('_').single.kind, TokenKind.underscore);
    });

    test('_template is an identifier, not underscore + template', () {
      // Longest-match beats the implicit '_' literal.
      final tokens = lex('_template');
      expect(tokens, hasLength(1));
      expect(tokens.single.kind, TokenKind.identifier);
      expect(tokens.single.value, '_template');
    });

    test('true, false and null are their own token kinds', () {
      expect(lex('true').single.kind, TokenKind.boolean);
      expect(lex('true').single.value, true);
      expect(lex('false').single.value, false);
      expect(lex('null').single.kind, TokenKind.nullLiteral);
    });

    test('a word merely starting with null is still an identifier', () {
      expect(lex('nullable').single.kind, TokenKind.identifier);
    });

    test('r is an identifier when not prefixing a string', () {
      expect(lex('r').single.kind, TokenKind.identifier);
      expect(lex('row').single.kind, TokenKind.identifier);
    });
  });

  group('paths', () {
    test('reads an absolute path', () {
      final token = lex(r'$/user/first_name').single;
      expect(token.kind, TokenKind.path);
      expect(token.value, r'$/user/first_name');
    });

    test('reads a relative path', () {
      expect(lex(r'$firstName').single.value, r'$firstName');
    });

    test('a lone dollar is a valid empty path', () {
      final token = lex(r'$').single;
      expect(token.kind, TokenKind.path);
      expect(token.value, r'$');
    });
  });

  group('checks', () {
    test('reads a bare check without the question mark', () {
      final token = lex('?required').single;
      expect(token.kind, TokenKind.check);
      expect(token.value, 'required');
    });

    test('throws when no name follows the question mark', () {
      expect(() => lex('?('), throwsA(isA<ExpressSyntaxError>()));
    });
  });

  group('numbers', () {
    test('reads integers, decimals and negatives', () {
      expect(lex('42').single.value, 42);
      expect(lex('3.14').single.value, 3.14);
      expect(lex('-1').single.value, -1);
    });

    test('a trailing dot is not part of the number', () {
      // NUMBER requires a digit after '.', so the dot is a separate character
      // and (being unknown punctuation) is rejected.
      expect(() => lex('42.'), throwsA(isA<ExpressSyntaxError>()));
    });
  });

  group('skipped content', () {
    test('drops hash, line and block comments', () {
      expect(lex('# comment\n42'), hasLength(1));
      expect(lex('// comment\n42'), hasLength(1));
      expect(lex('/* a\nb */ 42'), hasLength(1));
    });

    test('drops semicolons and all whitespace', () {
      expect(lex('a;\n\tb'), hasLength(2));
    });

    test('throws on an unterminated block comment', () {
      expect(() => lex('/* open'), throwsA(isA<ExpressSyntaxError>()));
    });
  });

  group('line tracking', () {
    test('counts lines across newlines and multi-line strings', () {
      final tokens = lex('a\nb\n"""x\ny"""\nc');
      expect(tokens[0].line, 1);
      expect(tokens[1].line, 2);
      expect(tokens[2].line, 3);
      // The string spans lines 3-4, so the token after it is on line 5.
      expect(tokens[3].line, 5);
    });

    test('reports the offending line in errors', () {
      expect(
        () => lex('ok\nok\n"unterminated'),
        throwsA(isA<ExpressSyntaxError>().having((e) => e.line, 'line', 3)),
      );
    });
  });
}
