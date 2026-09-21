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

/// Renders A2UI envelopes back into A2UI Express source.
///
/// The inverse of `compiler.dart`, and load-bearing for prompting rather than
/// for the wire: when a prior turn's surface is replayed as history, the model
/// must see its own UI output *in the format it is asked to produce*. Replaying
/// JSON while asking for Express would teach the model the wrong format.
///
/// Port of the reference `decompiler.py`, including its string-form heuristics
/// (raw strings for backslash-heavy values, triple quotes for multi-line ones).
library;

import '../catalog_types.dart';
import '../types.dart';

/// The sentinel tag that opens an Express block.
const String expressOpenTag = '<a2ui>';

/// The sentinel tag that closes an Express block.
const String expressCloseTag = '</a2ui>';

/// Renders [envelopes] as Express source, without the sentinel tags.
///
/// Envelope kinds the DSL has no statement for are skipped.
String decompileExpress(
  List<A2uiEnvelope> envelopes, {
  required A2uiCatalog catalog,
}) {
  final lines = <String>[];

  for (final envelope in envelopes) {
    final create = envelope['createSurface'];
    if (create is Map) {
      final surfaceId = create['surfaceId'];
      final catalogId = create['catalogId'];
      if (surfaceId is String) {
        // Only emit the catalog when it differs from the active one; otherwise
        // it is redundant and the surface would recompile against the same id
        // anyway.
        lines.add(
          catalogId is String && catalogId != catalog.id
              ? 'surface(${_string(surfaceId)}, ${_string(catalogId)})'
              : 'surface(${_string(surfaceId)})',
        );
      }
      continue;
    }

    final update = envelope['updateComponents'];
    if (update is Map) {
      final components = update['components'];
      if (components is List) lines.addAll(_components(components, catalog));
      continue;
    }

    final data = envelope['updateDataModel'];
    if (data is Map) {
      lines.addAll(_dataModel(data));
      continue;
    }

    final delete = envelope['deleteSurface'];
    if (delete is Map) {
      final surfaceId = delete['surfaceId'];
      if (surfaceId is String) {
        lines.add('deleteSurface(${_string(surfaceId)})');
      }
    }
  }

  return lines.join('\n');
}

/// Renders [envelopes] as a complete `<a2ui>` block.
String decompileExpressBlock(
  List<A2uiEnvelope> envelopes, {
  required A2uiCatalog catalog,
}) {
  final body = decompileExpress(envelopes, catalog: catalog);
  return '$expressOpenTag\n$body\n$expressCloseTag';
}

/// Renders each component as `id = Component(args...)`.
List<String> _components(List<Object?> components, A2uiCatalog catalog) {
  final lines = <String>[];

  for (final raw in components) {
    if (raw is! Map) continue;
    final component = raw.cast<String, dynamic>();
    final id = component['id'];
    final name = component['component'];
    if (id is! String || name is! String) continue;

    final signature = catalog.components[name]?.signature;
    if (signature == null) continue;

    // Walk the signature in order so the output is positional, tracking which
    // slots were supplied.
    final rendered = <String?>[];
    for (final param in signature.params) {
      if (!component.containsKey(param.name)) {
        rendered.add(null);
        continue;
      }
      // `checks` is a list of validation rules, which Express writes with the
      // `?name(...)` sigil rather than as ordinary calls.
      rendered.add(
        param.name == 'checks'
            ? _checks(component[param.name])
            : _value(
                component[param.name],
                isComponentRef: param.isComponentRef,
              ),
      );
    }

    // Trailing omissions are simply left off; interior ones need `_` so later
    // arguments stay aligned with their parameters.
    var last = rendered.length - 1;
    while (last >= 0 && rendered[last] == null) {
      last--;
    }
    final args = [for (var i = 0; i <= last; i++) rendered[i] ?? '_'];

    lines.add('$id = $name(${args.join(', ')})');
  }

  return lines;
}

/// Renders a `checks` list, writing each rule with its `?` sigil.
///
/// The check's `value` argument is dropped when it merely repeats the binding
/// the compiler injects from the component's own `value`, keeping the common
/// `[?required]` form compact.
String _checks(Object? checks) {
  if (checks is! List) return _value(checks);

  final rules = <String>[];
  for (final raw in checks) {
    if (raw is! Map) {
      rules.add(_value(raw));
      continue;
    }
    final call = raw['call'];
    if (call is! String) {
      rules.add(_value(raw));
      continue;
    }
    final args = raw['args'];
    final rest = <Object?>[
      if (args is Map)
        for (final entry in args.entries)
          if (entry.key != 'value') entry.value,
    ];
    rules.add(
      rest.isEmpty ? '?$call' : '?$call(${rest.map(_value).join(', ')})',
    );
  }
  return '[${rules.join(', ')}]';
}

/// Renders a `dataModel` back into `$/path = value` assignments, one per leaf.
List<String> _dataModel(Map<Object?, Object?> update) {
  final root = update['path'];
  final prefix = root is String && root != '/' ? root : '';
  final lines = <String>[];

  void walk(Object? node, String path) {
    if (node is Map && node.isNotEmpty) {
      for (final entry in node.entries) {
        walk(entry.value, '$path/${entry.key}');
      }
      return;
    }
    lines.add('\$$path = ${_value(node)}');
  }

  walk(update['value'], prefix);
  return lines;
}

/// Renders one compiled JSON value back into Express syntax.
///
/// [isComponentRef] comes from the catalog schema rather than the property
/// name, so a custom component whose child slot is named something other than
/// `child` round-trips correctly.
String _value(Object? value, {bool isComponentRef = false}) {
  if (value == null) return 'null';
  if (value is bool || value is num) return '$value';
  if (value is String) {
    // A string in a component-reference slot is an id, so it is emitted as a
    // bare variable rather than a quoted literal.
    return isComponentRef ? value : _string(value);
  }

  if (value is List) {
    return '[${value.map((v) => _value(v, isComponentRef: isComponentRef)).join(', ')}]';
  }

  if (value is Map) {
    final map = value.cast<String, dynamic>();

    // A template child list: {path, componentId}.
    final componentId = map['componentId'];
    if (map.containsKey('path') && componentId != null) {
      return '_template(\$${map['path']}, $componentId)';
    }

    // A data binding: {path}.
    final path = map['path'];
    if (path is String && map.length == 1) return '\$$path';

    // An action: {event: {name, context}}.
    final event = map['event'];
    if (event is Map) {
      final name = _string('${event['name'] ?? ''}');
      final context = event['context'];
      if (context is Map && context.isNotEmpty) {
        return 'Event($name, ${_value(context)})';
      }
      return 'Event($name)';
    }

    // A client function or check: {call, args}. Rendered with `name=value`
    // keyword arguments; wrapping them in braces would instead parse back as a
    // single map literal in the first positional slot.
    final call = map['call'];
    if (call is String) {
      final args = map['args'];
      if (args is Map && args.isNotEmpty) {
        final rendered = args.entries
            .map((e) => '${e.key}=${_value(e.value)}')
            .join(', ');
        return '$call($rendered)';
      }
      return '$call()';
    }

    final entries = map.entries
        .map((e) => '${e.key}: ${_value(e.value)}')
        .join(', ');
    return '{$entries}';
  }

  return _string('$value');
}

/// Picks the cleanest literal form for [value], mirroring the reference.
String _string(String value) {
  final hasNewline = value.contains('\n') || value.contains('\r');
  final hasQuote = value.contains('"');
  final hasBackslash = value.contains(r'\');
  final hasTab = value.contains('\t');

  // Triple quotes carry embedded quotes and newlines without escaping, as long
  // as the value neither contains nor ends with the delimiter.
  //
  // A literal CR is excluded deliberately: it would sit unescaped in the
  // output, where any line-ending normalization in transit (a diff tool, an
  // editor, git's autocrlf) would silently rewrite it. Those values take the
  // escaped single-quoted form below instead, where CR survives as `\r`.
  if ((hasQuote || hasNewline) &&
      !value.contains('\r') &&
      !value.contains('"""') &&
      !value.endsWith('"')) {
    if (hasBackslash && !hasTab) return 'r"""$value"""';
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('\t', r'\t');
    return '"""$escaped"""';
  }

  // A raw string keeps regex patterns readable.
  if (hasBackslash && !hasNewline && !hasTab && !hasQuote) return 'r"$value"';

  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}
