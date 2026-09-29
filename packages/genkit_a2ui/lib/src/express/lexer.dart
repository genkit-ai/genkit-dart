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

/// Tokenizer for the A2UI Express DSL.
///
/// A direct transcription of the lexer rules in the normative `Express.g4`
/// ANTLR grammar. Two behaviours of that grammar are worth stating explicitly,
/// because they are easy to get wrong:
///
/// - **Whitespace, including newlines, is skipped.** Express is *not*
///   line-oriented despite the prose in the spec; statement boundaries fall out
///   of the parse, which is what lets one assignment span several lines.
/// - **Identifier-like literals win ties.** ANTLR prefers an implicit literal
///   over a lexer rule of the same length, but longest-match still wins overall.
///   So `_` is the skip placeholder while `_template` is an identifier.
library;

/// The kinds of token the Express grammar defines.
enum TokenKind {
  /// A quoted string in any of the four supported forms.
  string,

  /// A numeric literal.
  number,

  /// `true` or `false`.
  boolean,

  /// The `null` literal.
  nullLiteral,

  /// A data-model path such as `$/user/name`, `$item` or a lone `$`.
  path,

  /// A validation rule such as `?required`.
  check,

  /// A bare identifier.
  identifier,

  /// The `_` skipped-argument placeholder.
  underscore,

  /// `(`, `)`, `[`, `]`, `{`, `}`, `,`, `:`, `=`.
  punctuation,

  /// End of input.
  eof,
}

/// A single lexed token.
class Token {
  /// What kind of token this is.
  final TokenKind kind;

  /// The token's decoded value: the unescaped contents for [TokenKind.string],
  /// a [num] for [TokenKind.number], a [bool] for [TokenKind.boolean], and the
  /// raw lexeme otherwise.
  final Object? value;

  /// Byte offset of the token's first character, used for error messages.
  final int offset;

  /// 1-based line number, used for error messages.
  final int line;

  /// Creates a [Token].
  const Token(this.kind, this.value, this.offset, this.line);

  @override
  String toString() => '$kind(${value ?? ''})@$line';
}

/// Thrown when the source cannot be tokenized or parsed.
class ExpressSyntaxError implements Exception {
  /// What went wrong.
  final String message;

  /// 1-based line the problem was found on.
  final int line;

  /// Creates an [ExpressSyntaxError].
  const ExpressSyntaxError(this.message, this.line);

  @override
  String toString() => 'Express syntax error on line $line: $message';
}

/// Tokenizes [source] into the token stream the Express parser consumes.
///
/// Always ends with a [TokenKind.eof] token.
List<Token> tokenize(String source) {
  final tokens = <Token>[];
  var i = 0;
  var line = 1;

  // Tracks newlines inside a consumed span (strings and block comments may
  // legally contain them) so error messages stay accurate.
  void countLines(int from, int to) {
    for (var j = from; j < to; j++) {
      if (source.codeUnitAt(j) == 0x0a) line++;
    }
  }

  while (i < source.length) {
    final c = source[i];

    // WS : [ \t\r\n]+ -> skip
    if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
      if (c == '\n') line++;
      i++;
      continue;
    }

    // SEMICOLON : ';' -> skip. Semicolons separate statements but, like
    // whitespace, carry no meaning of their own.
    if (c == ';') {
      i++;
      continue;
    }

    // COMMENT : ( '#' | '//' ) ~[\r\n]* -> skip
    if (c == '#' ||
        (c == '/' && i + 1 < source.length && source[i + 1] == '/')) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }

    // BLOCK_COMMENT : '/*' .*? '*/' -> skip
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      final end = source.indexOf('*/', i + 2);
      if (end < 0) throw ExpressSyntaxError('unterminated block comment', line);
      countLines(i, end);
      i = end + 2;
      continue;
    }

    final start = i;

    // String literals. Triple-quoted forms must be tried before single-quoted
    // ones, and the raw (`r`) prefix before either.
    if (c == 'r' || c == 'R') {
      if (source.startsWith('"""', i + 1)) {
        final end = source.indexOf('"""', i + 4);
        if (end < 0) throw ExpressSyntaxError('unterminated raw string', line);
        tokens.add(Token(.string, source.substring(i + 4, end), start, line));
        countLines(i, end);
        i = end + 3;
        continue;
      }
      if (source.startsWith('"', i + 1)) {
        // RAW_STRING : [rR] '"' ~[\r\n"]* '"' - no escapes, no newlines.
        final end = source.indexOf('"', i + 2);
        if (end < 0) throw ExpressSyntaxError('unterminated raw string', line);
        tokens.add(Token(.string, source.substring(i + 2, end), start, line));
        i = end + 1;
        continue;
      }
      // Otherwise `r` just begins an identifier; fall through.
    }

    if (source.startsWith('"""', i)) {
      final (value, next) = _readEscapedString(source, i + 3, '"""', line);
      tokens.add(Token(.string, value, start, line));
      countLines(i, next);
      i = next;
      continue;
    }

    if (c == '"') {
      final (value, next) = _readEscapedString(source, i + 1, '"', line);
      tokens.add(Token(.string, value, start, line));
      countLines(i, next);
      i = next;
      continue;
    }

    // PATH : '$' [a-zA-Z0-9_/]* - a lone '$' is legal and means "this item".
    if (c == r'$') {
      i++;
      while (i < source.length && _isPathChar(source[i])) {
        i++;
      }
      tokens.add(Token(.path, source.substring(start, i), start, line));
      continue;
    }

    // CHECK : '?' [a-zA-Z_] [a-zA-Z0-9_]*
    if (c == '?') {
      i++;
      if (i >= source.length || !_isIdentStart(source[i])) {
        throw ExpressSyntaxError("expected a name after '?'", line);
      }
      while (i < source.length && _isIdentPart(source[i])) {
        i++;
      }
      // Store without the '?' so the compiler can look the name up directly.
      tokens.add(Token(.check, source.substring(start + 1, i), start, line));
      continue;
    }

    // NUMBER : '-'? [0-9]+ ('.' [0-9]+)? - no exponent, no leading '.'.
    if (_isDigit(c) ||
        (c == '-' && i + 1 < source.length && _isDigit(source[i + 1]))) {
      if (c == '-') i++;
      while (i < source.length && _isDigit(source[i])) {
        i++;
      }
      if (i + 1 < source.length &&
          source[i] == '.' &&
          _isDigit(source[i + 1])) {
        i++;
        while (i < source.length && _isDigit(source[i])) {
          i++;
        }
      }
      tokens.add(
        Token(.number, num.parse(source.substring(start, i)), start, line),
      );
      continue;
    }

    // IDENTIFIER : [a-zA-Z_] [a-zA-Z0-9_]*, then reclassify exact matches of
    // the implicit literals. Munching maximally first is what keeps
    // `_template` an identifier rather than `_` followed by `template`.
    if (_isIdentStart(c)) {
      while (i < source.length && _isIdentPart(source[i])) {
        i++;
      }
      final word = source.substring(start, i);
      tokens.add(switch (word) {
        'true' => Token(.boolean, true, start, line),
        'false' => Token(.boolean, false, start, line),
        'null' => Token(.nullLiteral, null, start, line),
        '_' => Token(.underscore, word, start, line),
        _ => Token(.identifier, word, start, line),
      });
      continue;
    }

    if ('()[]{},:='.contains(c)) {
      i++;
      tokens.add(Token(.punctuation, c, start, line));
      continue;
    }

    throw ExpressSyntaxError("unexpected character '$c'", line);
  }

  tokens.add(Token(.eof, null, source.length, line));
  return tokens;
}

/// Reads a `\`-escaped string body starting at [from], up to [terminator].
/// Returns the decoded value and the offset just past the terminator.
(String, int) _readEscapedString(
  String source,
  int from,
  String terminator,
  int line,
) {
  final buffer = StringBuffer();
  var i = from;
  while (i < source.length) {
    if (source.startsWith(terminator, i)) {
      return (buffer.toString(), i + terminator.length);
    }
    final c = source[i];
    if (c == r'\' && i + 1 < source.length) {
      final escaped = source[i + 1];
      buffer.write(switch (escaped) {
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        '"' => '"',
        r'\' => r'\',
        // Unknown escapes keep the backslash, mirroring the grammar's `'\\' .`
        // which consumes the pair without ascribing meaning to it.
        _ => '\\$escaped',
      });
      i += 2;
      continue;
    }
    buffer.write(c);
    i++;
  }
  throw ExpressSyntaxError('unterminated string', line);
}

bool _isDigit(String c) => c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;

/// `Express.g4` restricts identifiers to ASCII, while the spec prose calls for
/// Unicode UAX #31. The grammar is the normative artifact, and what the
/// reference implementation is generated from, so it wins here.
bool _isIdentStart(String c) {
  final u = c.codeUnitAt(0);
  return (u >= 0x41 && u <= 0x5a) || (u >= 0x61 && u <= 0x7a) || c == '_';
}

bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);

bool _isPathChar(String c) => _isIdentPart(c) || c == '/';
