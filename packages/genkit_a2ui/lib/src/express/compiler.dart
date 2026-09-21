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

/// Compiles A2UI Express into A2UI protocol envelopes.
///
/// Port of the reference `ExpressCompiler`, targeting the v0.9 envelope triple
/// (`createSurface` + `updateComponents` + `updateDataModel`) that this package
/// emits. The pipeline is: parse to AST, map positional arguments onto catalog
/// properties, flatten variable references into an adjacency list, then wrap
/// the result in envelopes.
library;

import '../catalog_types.dart';
import '../types.dart';
import 'ast.dart';
import 'errors.dart';
import 'parser.dart';
import 'signature.dart';

/// Reserved call names that are commands rather than components.
const _surfaceCall = 'surface';
const _deleteSurfaceCall = 'deleteSurface';
const _templateCall = '_template';
const _eventCall = 'Event';

/// The variable name that must hold the root of the component tree.
const _rootVariable = 'root';

/// Compiles Express [source] into A2UI envelopes.
///
/// [surfaceId] is used when the block does not name a surface itself; the
/// middleware passes a freshly-minted id so each render targets its own
/// surface. Throws [ExpressCompileError] on a catalog mismatch and
/// `ExpressSyntaxError` on malformed source.
List<A2uiEnvelope> compileExpress(
  String source, {
  required A2uiCatalog catalog,
  required String surfaceId,
  String version = a2uiVersion,
}) {
  final statements = parseExpress(source);
  return _Compiler(catalog, surfaceId, version).run(statements);
}

/// One `surface(...)` scope: the variables and data assignments that belong to
/// a single target surface. A block may switch surfaces, so there can be
/// several.
class _Scope {
  final String surfaceId;
  final String? catalogId;

  /// Variable name to its assigned expression, in declaration order.
  final Map<String, ExprNode> symbols = {};

  /// Data path (including the `$` sigil) to its assigned value.
  final Map<String, ExprNode> dataPaths = {};

  _Scope(this.surfaceId, this.catalogId);
}

class _Compiler {
  final A2uiCatalog _catalog;
  final String _defaultSurfaceId;
  final String _version;

  /// Components hoisted out of inline constructors, e.g. the `Text` in
  /// `Card(Text("hi"))`.
  final List<A2uiComponent> _hoisted = [];
  int _inlineCounter = 0;

  /// The `{path: ...}` of the component's `value` prop, if it has one. Checks
  /// declared on that component default their target to it, so `?required`
  /// needs no explicit argument.
  Map<String, dynamic>? _activeValuePath;

  _Compiler(this._catalog, this._defaultSurfaceId, this._version);

  List<A2uiEnvelope> run(List<ExprStatement> statements) {
    final scopes = <_Scope>[];
    _Scope? current;
    String? deleteTarget;

    for (final statement in statements) {
      switch (statement) {
        case ExprStatementExpression(:final expression):
          if (expression is! ExprCall) continue;
          switch (expression.name) {
            case _surfaceCall:
              current = _openScope(expression);
              scopes.add(current);
            case _deleteSurfaceCall:
              deleteTarget = _firstString(expression) ?? _defaultSurfaceId;
            default:
              // Standalone client function calls compile to `callFunction`,
              // which v0.9 has no envelope for. Reject rather than silently
              // dropping the model's intent.
              throw ExpressCompileError(
                'standalone function call "${expression.name}" requires A2UI '
                'v1.0; this package emits $_version.',
                expression.line,
              );
          }

        case ExprAssignment(:final target, :final isPath, :final value):
          // Statements before any `surface()` land in an implicit scope on the
          // middleware-supplied id.
          current ??= _Scope(_defaultSurfaceId, null);
          if (scopes.isEmpty) scopes.add(current);
          if (isPath) {
            current.dataPaths[target] = value;
          } else {
            current.symbols[target] = value;
          }
      }
    }

    if (deleteTarget != null) {
      return [
        {
          'version': _version,
          'deleteSurface': {'surfaceId': deleteTarget},
        },
      ];
    }

    if (scopes.isEmpty) throw ExpressCompileError.undefinedRoot();

    final envelopes = <A2uiEnvelope>[];
    for (final scope in scopes) {
      envelopes.addAll(_compileScope(scope));
    }
    return envelopes;
  }

  /// Reads the target surface (and optional catalog) out of `surface(...)`.
  _Scope _openScope(ExprCall call) {
    final positional = call.positional;
    final id =
        _asString(call.named['surfaceId']) ??
        (positional.isNotEmpty ? _asString(positional[0]) : null) ??
        _defaultSurfaceId;
    final catalogId =
        _asString(call.named['catalogId']) ??
        (positional.length > 1 ? _asString(positional[1]) : null);
    return _Scope(id, catalogId);
  }

  String? _firstString(ExprCall call) =>
      call.positional.isNotEmpty ? _asString(call.positional.first) : null;

  static String? _asString(ExprNode? node) =>
      node is ExprLiteral && node.value is String
      ? node.value! as String
      : null;

  /// Compiles one surface scope into its envelopes.
  List<A2uiEnvelope> _compileScope(_Scope scope) {
    final dataModel = <String, dynamic>{};
    for (final entry in scope.dataPaths.entries) {
      _setPath(dataModel, entry.key, _value(entry.value, scope));
    }

    // A block of only data assignments patches an existing surface rather than
    // rendering a new one.
    if (!scope.symbols.containsKey(_rootVariable)) {
      if (dataModel.isNotEmpty) {
        return [_dataEnvelope(scope.surfaceId, dataModel)];
      }
      throw ExpressCompileError.undefinedRoot();
    }

    final components = <A2uiComponent>[];
    for (final entry in scope.symbols.entries) {
      final component = _component(entry.key, entry.value, scope);
      if (component != null) components.add(component);
    }
    components.addAll(_hoisted);
    _hoisted.clear();

    return [
      {
        'version': _version,
        'createSurface': {
          'surfaceId': scope.surfaceId,
          'catalogId': scope.catalogId ?? _catalog.id,
        },
      },
      {
        'version': _version,
        'updateComponents': {
          'surfaceId': scope.surfaceId,
          'components': components,
        },
      },
      if (dataModel.isNotEmpty) _dataEnvelope(scope.surfaceId, dataModel),
    ];
  }

  A2uiEnvelope _dataEnvelope(String surfaceId, Map<String, dynamic> value) => {
    'version': _version,
    'updateDataModel': {'surfaceId': surfaceId, 'path': '/', 'value': value},
  };

  /// Compiles one variable into an adjacency-list component entry. The variable
  /// name becomes the component id, so `root` stays `root`.
  ///
  /// Returns null when the variable holds something other than a component
  /// (a shared map, say), which is legal: it is referenced by value elsewhere.
  A2uiComponent? _component(String id, ExprNode node, _Scope scope) {
    if (node is! ExprCall) return null;

    final component = _catalog.components[node.name];
    if (component == null) {
      // Reserved helpers are values, not components; anything else is a typo
      // or a component the catalog does not have.
      if (node.name == _eventCall || node.name == _templateCall) return null;
      if (_catalog.functions.containsKey(node.name)) return null;
      throw ExpressCompileError.unknownComponent(
        node.name,
        _catalog.id,
        node.line,
      );
    }

    final signature = component.signature;
    final params = signature.params.where((p) => p.name != 'checks').toList();
    final result = <String, dynamic>{'id': id, 'component': node.name};

    // Positional args fill the signature in order; checks are collected out of
    // band because `checks` is always last regardless of where it appears.
    final pairs = <(String, ExprNode)>[];
    final checks = <ExprNode>[];
    var index = 0;

    for (final arg in node.positional) {
      if (_isCheck(arg)) {
        checks.addAll(arg is ExprArray ? arg.items : [arg]);
        continue;
      }
      if (index >= params.length) {
        throw ExpressCompileError(
          'too many positional arguments for component "${node.name}" '
          '(it takes at most ${params.length}: '
          '${params.map((p) => p.name).join(', ')}).',
          node.line,
        );
      }
      pairs.add((params[index].name, arg));
      index++;
    }

    for (final entry in node.named.entries) {
      if (_isCheck(entry.value)) {
        final v = entry.value;
        checks.addAll(v is ExprArray ? v.items : [v]);
        continue;
      }
      pairs.add((entry.key, entry.value));
    }

    Map<String, dynamic>? valuePath;
    final seen = <String>{};

    for (final (name, arg) in pairs) {
      final param = signature[name];
      if (param == null) {
        throw ExpressCompileError.unknownProperty(
          node.name,
          name,
          params.map((p) => p.name),
          node.line,
        );
      }
      if (!seen.add(name)) {
        throw ExpressCompileError.duplicateProperty(node.name, name, node.line);
      }
      // `_` leaves the property unset so a later positional argument can land
      // on the right parameter.
      if (arg is ExprSkip) continue;

      final compiled = _value(arg, scope);
      if (param.static && _containsBinding(compiled)) {
        throw ExpressCompileError.forbiddenBinding(node.name, name, node.line);
      }
      result[name] = compiled;

      if (name == 'value' &&
          compiled is Map<String, dynamic> &&
          compiled.containsKey('path')) {
        valuePath = compiled;
      }
    }

    // Checks default to validating this component's own `value` binding.
    // Save and restore rather than clearing: a check argument may hold an
    // inline component, which re-enters this method and would otherwise leave
    // the remaining checks without their target.
    final enclosingValuePath = _activeValuePath;
    _activeValuePath = valuePath;
    try {
      if (checks.isNotEmpty) {
        result['checks'] = checks.map((c) => _value(c, scope)).toList();
      }
    } finally {
      _activeValuePath = enclosingValuePath;
    }

    return result;
  }

  static bool _isCheck(ExprNode node) =>
      node is ExprCheck ||
      (node is ExprArray &&
          node.items.isNotEmpty &&
          node.items.every((i) => i is ExprCheck));

  /// Compiles one expression into its A2UI JSON value.
  Object? _value(ExprNode node, _Scope scope) {
    switch (node) {
      case ExprLiteral(:final value):
        return value;

      case ExprPath(:final path):
        return {'path': path};

      case ExprSkip():
        return null;

      case ExprArray(:final items):
        return items.map((i) => _value(i, scope)).toList();

      case ExprMap(:final entries):
        return {for (final e in entries.entries) e.key: _value(e.value, scope)};

      case ExprVar(:final name, :final line):
        final target = scope.symbols[name];
        if (target == null) {
          throw ExpressCompileError.undefinedChild(name, line);
        }
        // A reference to a component becomes its id (the adjacency list);
        // anything else is inlined by value.
        if (target is ExprCall &&
            _catalog.components.containsKey(target.name)) {
          return name;
        }
        return _value(target, scope);

      case ExprCheck():
        return _check(node, scope);

      case ExprCall():
        return _call(node, scope);
    }
  }

  /// Compiles a call appearing in value position.
  Object? _call(ExprCall node, _Scope scope) {
    // An inline component is hoisted into its own adjacency-list entry and
    // replaced by the generated id, e.g. `Card(Text("hi"))`.
    if (_catalog.components.containsKey(node.name)) {
      _inlineCounter++;
      final id = '${node.name}_inline_$_inlineCounter';
      final component = _component(id, node, scope);
      if (component != null) _hoisted.add(component);
      return id;
    }

    if (node.name == _templateCall) {
      if (node.positional.length < 2) {
        throw ExpressCompileError(
          '_template requires a path and a template component.',
          node.line,
        );
      }
      final path = _value(node.positional[0], scope);
      if (path is! Map || !path.containsKey('path')) {
        throw ExpressCompileError(
          "_template's first argument must be a data-model path (\$/...).",
          node.line,
        );
      }
      return {
        'path': path['path'],
        'componentId': _value(node.positional[1], scope),
      };
    }

    if (node.name == _eventCall) {
      final name = node.positional.isNotEmpty
          ? _value(node.positional[0], scope)
          : '';
      final context = node.positional.length > 1
          ? _value(node.positional[1], scope)
          : const <String, dynamic>{};
      return {
        'event': {
          'name': name,
          'context': context is Map<String, dynamic>
              ? context
              : const <String, dynamic>{},
        },
      };
    }

    // A catalog client function, e.g. `formatString(...)` or `openUrl(...)`.
    final function = _catalog.functions[node.name];
    if (function != null) {
      return {
        'call': node.name,
        'args': _functionArgs(node, function.signature.params, scope),
      };
    }

    throw ExpressCompileError.unknownComponent(
      node.name,
      _catalog.id,
      node.line,
    );
  }

  /// Maps a client function call's arguments onto its declared parameters,
  /// with the same strictness as components: no overflow, no unknown names, no
  /// duplicates. `_` skips a positional slot.
  Map<String, dynamic> _functionArgs(
    ExprCall node,
    List<A2uiParam> params,
    _Scope scope,
  ) {
    final args = <String, dynamic>{};
    final seen = <String>{};
    var index = 0;

    for (final arg in node.positional) {
      if (index >= params.length) {
        throw ExpressCompileError(
          'too many positional arguments for function "${node.name}" '
          '(it takes at most ${params.length}: '
          '${params.map((p) => p.name).join(', ')}).',
          node.line,
        );
      }
      final name = params[index].name;
      index++;
      if (arg is ExprSkip) continue;
      args[name] = _value(arg, scope);
      seen.add(name);
    }

    for (final entry in node.named.entries) {
      final name = entry.key;
      if (!params.any((p) => p.name == name)) {
        throw ExpressCompileError(
          'function "${node.name}" has no parameter "$name" '
          '(expected one of: ${params.map((p) => p.name).join(', ')}).',
          node.line,
        );
      }
      if (!seen.add(name)) {
        throw ExpressCompileError(
          'parameter "$name" of function "${node.name}" was given twice.',
          node.line,
        );
      }
      args[name] = _value(entry.value, scope);
    }

    return args;
  }

  /// Compiles a `?check` into its client function call.
  ///
  /// When the check's first parameter is `value` and the model supplied no
  /// path, it defaults to the enclosing component's `value` binding, so
  /// `?required` on a bound TextField needs no argument.
  Map<String, dynamic> _check(ExprCheck node, _Scope scope) {
    // A check is a catalog function; an unknown name is a typo (`?requried`)
    // that would otherwise compile to a rule the renderer silently ignores.
    final function = _catalog.functions[node.name];
    if (function == null) {
      throw ExpressCompileError(
        'unknown check "?${node.name}" in catalog "${_catalog.id}".',
        node.line,
      );
    }

    final params = function.signature.params;
    final args = <String, dynamic>{};
    final explicit = node.args;
    var offset = 0;

    if (params.isNotEmpty && params.first.name == 'value') {
      final suppliedPath = explicit.isNotEmpty && explicit.first is ExprPath;
      if (!suppliedPath && _activeValuePath != null) {
        args['value'] = _activeValuePath;
        offset = 1;
      }
    }

    for (var i = 0; i < explicit.length; i++) {
      final index = i + offset;
      if (index >= params.length) {
        throw ExpressCompileError(
          'too many arguments for check "?${node.name}" '
          '(it takes at most ${params.length - offset}).',
          node.line,
        );
      }
      final arg = explicit[i];
      if (arg is ExprSkip) continue;
      args[params[index].name] = _value(arg, scope);
    }

    return {'call': node.name, 'args': args};
  }

  /// Whether a compiled value carries a data-model binding, used to enforce
  /// `(static)`. A `componentId` marks a template child list, and `call`/`event`
  /// wrap their own arguments, so none of those count.
  static bool _containsBinding(Object? value) {
    if (value is Map) {
      if (value.containsKey('call') || value.containsKey('event')) return false;
      if (value.containsKey('path') && !value.containsKey('componentId')) {
        return true;
      }
      return value.values.any(_containsBinding);
    }
    if (value is List) return value.any(_containsBinding);
    return false;
  }

  /// Writes [value] into [target] at a `$/a/b` style path, creating
  /// intermediate maps. Used to rebuild the nested `dataModel`.
  static void _setPath(
    Map<String, dynamic> target,
    String rawPath,
    Object? value,
  ) {
    var path = rawPath;
    if (path.startsWith(r'$')) path = path.substring(1);
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) return;

    final keys = path.split('/');
    var node = target;
    for (final key in keys.take(keys.length - 1)) {
      final next = node[key];
      if (next is Map<String, dynamic>) {
        node = next;
      } else {
        node = node[key] = <String, dynamic>{};
      }
    }
    node[keys.last] = value;
  }
}
