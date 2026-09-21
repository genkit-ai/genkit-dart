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

/// Errors raised while compiling A2UI Express into A2UI envelopes.
///
/// Mirrors the error taxonomy of the reference implementation. All of them are
/// [ExpressCompileError]s so the middleware's `validate` modes can treat them
/// uniformly: `strict` rethrows, `warn` logs and drops the statement.
library;

/// A problem found while compiling Express source against a catalog.
class ExpressCompileError implements Exception {
  /// What went wrong, phrased for whoever is reading the server log.
  final String message;

  /// 1-based source line, when the compiler knows it.
  final int? line;

  /// Whether rewriting the block could plausibly fix this.
  ///
  /// True for mistakes in what the model wrote (a literal in an id slot, a bad
  /// argument count). False for configuration problems - a component the
  /// catalog does not define, a missing catalog - where a retry cannot help and
  /// would only cost a call.
  final bool isModelFixable;

  /// Creates an [ExpressCompileError].
  const ExpressCompileError(
    this.message, [
    this.line,
    this.isModelFixable = true,
  ]);

  /// A component referenced a prop its catalog schema does not declare.
  factory ExpressCompileError.unknownProperty(
    String component,
    String property,
    Iterable<String> known, [
    int? line,
  ]) => ExpressCompileError(
    'component "$component" has no property "$property" '
    '(expected one of: ${known.join(', ')}).',
    line,
  );

  /// The same prop was supplied twice, positionally and by keyword.
  factory ExpressCompileError.duplicateProperty(
    String component,
    String property, [
    int? line,
  ]) => ExpressCompileError(
    'property "$property" of component "$component" was given twice.',
    line,
  );

  /// A `(static)` prop was handed a `$/path` binding.
  factory ExpressCompileError.forbiddenBinding(
    String component,
    String property, [
    int? line,
  ]) => ExpressCompileError(
    'property "$property" of component "$component" is static and cannot take '
    'a data-model binding.',
    line,
  );

  /// A component-id slot was handed a string literal.
  ///
  /// The single most common Express mistake: `Button("Refresh", ...)` reads
  /// naturally but compiles to `"child": "Refresh"`, and the renderer then
  /// fails looking up a widget with that id. The message spells out the fix
  /// because it is also what gets shown to the model on a repair attempt.
  factory ExpressCompileError.literalInIdSlot(
    String component,
    String property,
    String literal, [
    int? line,
  ]) => ExpressCompileError(
    'property "$property" of component "$component" expects a component id, '
    'not the literal "$literal". Define a component and reference it by '
    'variable, e.g. `label = Text("$literal")` then '
    '`$component(label, ...)`.',
    line,
  );

  /// The block defined no `root` variable, so there is no tree to render.
  factory ExpressCompileError.undefinedRoot([int? line]) =>
      const ExpressCompileError(
        'the block must assign a component to the reserved variable "root".',
      );

  /// A component referenced a variable that was never defined.
  factory ExpressCompileError.undefinedChild(String reference, [int? line]) =>
      ExpressCompileError(
        'reference to undefined variable "$reference".',
        line,
      );

  /// A component name that is not in the catalog.
  ///
  /// Not model-fixable: the component genuinely does not exist, so the block
  /// cannot be rewritten into something valid. Either the catalog is wrong or
  /// the model invented a component.
  factory ExpressCompileError.unknownComponent(
    String component,
    String catalogId, [
    int? line,
  ]) => ExpressCompileError(
    'component "$component" is not in catalog "$catalogId".',
    line,
    false,
  );

  @override
  String toString() => line == null
      ? 'Express compile error: $message'
      : 'Express compile error on line $line: $message';
}
