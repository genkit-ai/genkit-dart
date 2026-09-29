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

/// Recursive-descent parser for the A2UI Express DSL.
///
/// Transcribes the parser rules of `Express.g4`. It consumes a *token stream*
/// rather than lines: the grammar skips newlines and `program : statement* EOF`
/// declares no separator, so statement boundaries are found by lookahead. That
/// is what lets a single assignment span several lines.
library;

import 'ast.dart';
import 'lexer.dart';

/// Parses [source] into a list of statements.
///
/// Throws [ExpressSyntaxError] on malformed input.
List<ExprStatement> parseExpress(String source) =>
    _Parser(tokenize(source)).parseProgram();

class _Parser {
  final List<Token> _tokens;
  int _pos = 0;

  _Parser(this._tokens);

  Token get _current => _tokens[_pos];

  Token _advance() => _tokens[_pos++];

  bool _isPunct(String value) =>
      _current.kind == TokenKind.punctuation && _current.value == value;

  bool _matchPunct(String value) {
    if (!_isPunct(value)) return false;
    _pos++;
    return true;
  }

  void _expectPunct(String value) {
    if (!_matchPunct(value)) {
      throw ExpressSyntaxError(
        "expected '$value' but found ${_describe(_current)}",
        _current.line,
      );
    }
  }

  static String _describe(Token token) => switch (token.kind) {
    TokenKind.eof => 'end of input',
    TokenKind.string => 'a string',
    _ => "'${token.value}'",
  };

  /// program : statement* EOF
  List<ExprStatement> parseProgram() {
    final statements = <ExprStatement>[];
    while (_current.kind != TokenKind.eof) {
      statements.add(_parseStatement());
    }
    return statements;
  }

  /// statement : assignment | expression
  ///
  /// `assignment : (identifier | path) '=' expression`, so one token of
  /// lookahead past the target distinguishes the two.
  ExprStatement _parseStatement() {
    final start = _current;

    if (start.kind == TokenKind.identifier || start.kind == TokenKind.path) {
      final next = _tokens[_pos + 1];
      if (next.kind == TokenKind.punctuation && next.value == '=') {
        _advance(); // target
        _advance(); // '='
        final value = _parseExpression();
        return ExprAssignment(
          start.value! as String,
          start.kind == TokenKind.path,
          value,
          start.line,
        );
      }
    }

    return ExprStatementExpression(_parseExpression(), start.line);
  }

  /// expression : array | map | path | check | call | variable | literal
  ExprNode _parseExpression() {
    final token = _current;

    switch (token.kind) {
      case TokenKind.string:
      case TokenKind.number:
      case TokenKind.boolean:
      case TokenKind.nullLiteral:
        _advance();
        return ExprLiteral(token.value, token.line);

      case TokenKind.path:
        _advance();
        // Strip the '$' sigil; the AST keeps the path itself.
        return ExprPath((token.value! as String).substring(1), token.line);

      case TokenKind.check:
        _advance();
        final args = _isPunct('(') ? _parseParenList() : const <ExprNode>[];
        return ExprCheck(token.value! as String, args, token.line);

      case TokenKind.underscore:
        _advance();
        return ExprSkip(token.line);

      case TokenKind.identifier:
        _advance();
        final name = token.value! as String;
        // A following '(' makes this a call; otherwise it is a variable
        // reference (`variable : '_' | identifier`).
        if (_isPunct('(')) return _parseCallArgs(name, token.line);
        return ExprVar(name, token.line);

      case TokenKind.punctuation:
        if (token.value == '[') return _parseArray();
        if (token.value == '{') return _parseMap();
        throw ExpressSyntaxError('unexpected ${_describe(token)}', token.line);

      case TokenKind.eof:
        throw ExpressSyntaxError('unexpected end of input', token.line);
    }
  }

  /// call : identifier '(' (arg (',' arg)* ','?)? ')'
  ///
  /// arg : named_arg | expression, and the two may be freely interleaved.
  ExprCall _parseCallArgs(String name, int line) {
    _expectPunct('(');
    final positional = <ExprNode>[];
    final named = <String, ExprNode>{};

    while (!_isPunct(')')) {
      // named_arg : identifier '=' expression
      if (_current.kind == TokenKind.identifier) {
        final next = _tokens[_pos + 1];
        if (next.kind == TokenKind.punctuation && next.value == '=') {
          final argName = _advance().value! as String;
          _advance(); // '='
          named[argName] = _parseExpression();
          if (!_matchPunct(',')) break;
          continue;
        }
      }

      positional.add(_parseExpression());
      if (!_matchPunct(',')) break;
    }

    _expectPunct(')');
    return ExprCall(name, positional, named, line);
  }

  /// A parenthesized expression list, used by `check`.
  List<ExprNode> _parseParenList() {
    _expectPunct('(');
    final items = <ExprNode>[];
    while (!_isPunct(')')) {
      items.add(_parseExpression());
      if (!_matchPunct(',')) break;
    }
    _expectPunct(')');
    return items;
  }

  /// array : '[' (expression (',' expression)* ','?)? ']'
  ExprArray _parseArray() {
    final line = _current.line;
    _expectPunct('[');
    final items = <ExprNode>[];
    while (!_isPunct(']')) {
      items.add(_parseExpression());
      if (!_matchPunct(',')) break;
    }
    _expectPunct(']');
    return ExprArray(items, line);
  }

  /// map : '{' (map_entry (',' map_entry)* ','?)? '}'
  ///
  /// map_entry : (identifier | string) ':' expression. Keys are always literal;
  /// the grammar has no dynamic-key form.
  ExprMap _parseMap() {
    final line = _current.line;
    _expectPunct('{');
    final entries = <String, ExprNode>{};

    while (!_isPunct('}')) {
      final keyToken = _current;
      if (keyToken.kind != TokenKind.identifier &&
          keyToken.kind != TokenKind.string) {
        throw ExpressSyntaxError(
          'map keys must be an identifier or a string, found '
          '${_describe(keyToken)}',
          keyToken.line,
        );
      }
      _advance();
      _expectPunct(':');
      entries[keyToken.value! as String] = _parseExpression();
      if (!_matchPunct(',')) break;
    }

    _expectPunct('}');
    return ExprMap(entries, line);
  }
}
