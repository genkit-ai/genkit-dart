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

/// Abstract syntax tree for the A2UI Express DSL.
///
/// Mirrors the parser rules in `Express.g4` one-to-one. The hierarchy is sealed
/// so the compiler's `switch`es are exhaustive and a future grammar addition
/// fails to compile rather than silently falling through.
library;

/// A parsed expression.
sealed class ExprNode {
  /// 1-based source line, used for error messages.
  final int line;

  /// Creates an [ExprNode].
  const ExprNode(this.line);
}

/// A call such as `Text("hi")`, `Event("save")` or `_template($/xs, item)`.
///
/// Also covers the standalone lifecycle commands `surface(...)` and
/// `deleteSurface(...)`: the grammar has no special production for them, so the
/// compiler recognizes them by [name].
class ExprCall extends ExprNode {
  /// The component, function or command name.
  final String name;

  /// Positional arguments, in source order.
  final List<ExprNode> positional;

  /// Keyword arguments (`param=value`).
  final Map<String, ExprNode> named;

  /// Creates an [ExprCall].
  const ExprCall(this.name, this.positional, this.named, super.line);
}

/// A data-model path such as `$/user/name`, `$item`, or a lone `$`.
class ExprPath extends ExprNode {
  /// The path without its `$` prefix. Absolute paths keep their leading `/`;
  /// an empty string is the lone `$` (the current template item).
  final String path;

  /// Creates an [ExprPath].
  const ExprPath(this.path, super.line);

  /// Whether this is an absolute path into the data model root.
  bool get isAbsolute => path.startsWith('/');
}

/// A validation rule such as `?required` or `?regex("^\\d+$", "digits only")`.
class ExprCheck extends ExprNode {
  /// The check's function name, without the `?`.
  final String name;

  /// Arguments supplied in parentheses, if any.
  final List<ExprNode> args;

  /// Creates an [ExprCheck].
  const ExprCheck(this.name, this.args, super.line);
}

/// A reference to a variable defined elsewhere in the block.
class ExprVar extends ExprNode {
  /// The referenced variable name.
  final String name;

  /// Creates an [ExprVar].
  const ExprVar(this.name, super.line);
}

/// The `_` placeholder marking a skipped positional argument.
class ExprSkip extends ExprNode {
  /// Creates an [ExprSkip].
  const ExprSkip(super.line);
}

/// A string, number, boolean or null literal.
class ExprLiteral extends ExprNode {
  /// The literal's Dart value.
  final Object? value;

  /// Creates an [ExprLiteral].
  const ExprLiteral(this.value, super.line);
}

/// A bracketed list such as `[header, body]`.
class ExprArray extends ExprNode {
  /// The list's elements.
  final List<ExprNode> items;

  /// Creates an [ExprArray].
  const ExprArray(this.items, super.line);
}

/// A braced map such as `{title: "Overview", child: body}`.
class ExprMap extends ExprNode {
  /// The map's entries. Keys are always literal strings.
  final Map<String, ExprNode> entries;

  /// Creates an [ExprMap].
  const ExprMap(this.entries, super.line);
}

/// A single top-level statement.
sealed class ExprStatement {
  /// 1-based source line, used for error messages.
  final int line;

  /// Creates an [ExprStatement].
  const ExprStatement(this.line);
}

/// An assignment to a variable (`root = Card(body)`) or to a data path
/// (`$/title = "Hello"`).
class ExprAssignment extends ExprStatement {
  /// The assignment target: a variable name, or a `$`-prefixed data path.
  final String target;

  /// Whether [target] is a data path rather than a variable name.
  final bool isPath;

  /// The assigned expression.
  final ExprNode value;

  /// Creates an [ExprAssignment].
  const ExprAssignment(this.target, this.isPath, this.value, super.line);
}

/// A bare expression statement, used for the standalone lifecycle commands
/// (`surface("id")`, `deleteSurface("id")`) and client function calls.
class ExprStatementExpression extends ExprStatement {
  /// The expression evaluated for its effect.
  final ExprNode expression;

  /// Creates an [ExprStatementExpression].
  const ExprStatementExpression(this.expression, super.line);
}
