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

/// A headless stand-in for an A2UI renderer (v0.9 and v1.0).
///
/// Applies messages the way a renderer would (create, update, delete) and
/// reports protocol violations instead of drawing anything. Deliberately small:
/// `a2ui_core`'s `MessageProcessor` needs function implementations for every
/// catalog function, which is more than this harness needs. The middleware
/// already runs `a2ui_agent`'s per-block checks under `validate: 'strict'`;
/// this layer adds the cross-turn rules a single block cannot see.
library;

import 'package:a2ui_core/a2ui_core.dart'
    show A2uiDataError, A2uiExpressionError, DataModel, ExpressionParser;

/// What a turn did to one surface.
enum SurfaceChange { created, replaced, updated, deleted }

/// One rendered surface.
final class SurfaceState {
  SurfaceState(this.id, this.catalogId, this.order, this.createdTurn);

  final String id;
  final String catalogId;

  /// The protocol version of the message that created the surface, which the
  /// actions it sends back carry.
  String version = 'v0.9';

  /// Creation order across the conversation (stable across replacements), so
  /// scenarios can refer to "the first surface".
  final int order;

  /// The turn that first created this surface (kept across replacements).
  final int createdTurn;

  final Map<String, Map<String, dynamic>> components = {};
  final DataModel _model = DataModel();

  /// A snapshot view of the surface's data model.
  Map<String, dynamic> get data => switch (_model.get('/')) {
    final Map m => _deepCopyJson(m) as Map<String, dynamic>,
    _ => <String, dynamic>{},
  };

  /// Reads [path] from the surface's data model.
  Object? getData(String path) => _model.get(path);

  /// Writes [value] at [path] using `a2ui_core`'s [DataModel] rules (list
  /// append/pad, key deletion on `null`, and [A2uiDataError] on type mismatch).
  void setData(String path, Object? value) => _model.set(path, value);

  /// Components reachable from `'root'`, in traversal order. Detached
  /// components left in [components] after an in-place `updateComponents` are
  /// excluded, matching what a renderer draws.
  Map<String, Map<String, dynamic>> get reachableComponents {
    if (!components.containsKey('root')) return const {};
    final out = <String, Map<String, dynamic>>{};
    final queue = <String>['root'];
    for (var i = 0; i < queue.length; i++) {
      final id = queue[i];
      if (out.containsKey(id)) continue;
      final c = components[id];
      if (c == null) continue;
      out[id] = c;
      for (final child in HeadlessRenderer.childRefs(c)) {
        if (!out.containsKey(child)) queue.add(child);
      }
    }
    return out;
  }

  static const _notShown = {
    'id',
    'component',
    'catalogId',
    '@catalogId',
    'action',
    'checks',
    '@checks',
    'metadata',
    '@metadata',
    'child',
    'children',
    'trigger',
    'content',
    'call',
    '@call',
  };

  /// Displayed text and resolved bindings on reachable components, lowercased,
  /// for content assertions like "mentions Paris". Excludes component ids, type
  /// names, binding path strings, actions, and unbound data-model entries.
  String get searchableText {
    if (!components.containsKey('root')) return '';
    final out = StringBuffer();

    void walkValue(Object? v, Object? scope) {
      switch (v) {
        case final String s:
          out
            ..write(s.toLowerCase())
            ..write(' ');
        case final num n:
          out
            ..write(n)
            ..write(' ');
        case final Map m
            when bindingPath(m, version: version) != null ||
                isFormatStringCall(m, version: version):
          walkValue(resolve(m, scope: scope), scope);
        case final Map m:
          for (final MapEntry(:key, :value) in m.entries) {
            if (!_notShown.contains(key)) walkValue(value, scope);
          }
        case final List l:
          for (final item in l) {
            walkValue(item, scope);
          }
      }
    }

    void walkComponent(String cid, Object? scope, int depth) {
      if (depth > 16) return;
      final c = components[cid];
      if (c == null) return;
      for (final MapEntry(:key, :value) in c.entries) {
        if (!_notShown.contains(key)) walkValue(value, scope);
      }
      for (final key in const ['child', 'trigger', 'content']) {
        if (c[key] case final String childId) {
          walkComponent(childId, scope, depth + 1);
        }
      }
      switch (c['children']) {
        case final List ids:
          for (final childId in ids.whereType<String>()) {
            walkComponent(childId, scope, depth + 1);
          }
        case {'path': final String listPath, 'componentId': final String tplId}:
          final items = listPath.startsWith('/')
              ? getData(listPath)
              : (scope != null ? readPointer(scope, '/$listPath') : null);
          if (items is List) {
            for (final item in items) {
              walkComponent(tplId, item, depth + 1);
            }
          }
      }
      if (c['tabs'] case final List tabs) {
        for (final t in tabs) {
          if (t case {'child': final String childId}) {
            walkComponent(childId, scope, depth + 1);
          }
        }
      }
    }

    walkComponent('root', null, 0);
    return out.toString();
  }

  Set<String> get componentTypes => {
    for (final c in reachableComponents.values)
      if (c['component'] case final String t) t,
  };

  /// The text a user would see on [componentId], resolving `Text` children and
  /// data bindings. Used to find a button by its label.
  String labelOf(String componentId, [int depth = 0]) {
    final c = components[componentId];
    if (c == null || depth > 4) return '';
    final parts = <String>[
      for (final key in const ['text', 'label'])
        if (c[key] != null) resolveString(c[key]),
      if (c['child'] case final String child) labelOf(child, depth + 1),
      if (c['children'] case final List children)
        for (final child in children.whereType<String>())
          labelOf(child, depth + 1),
    ];
    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  /// A dynamic value as display text: literals as-is, bindings resolved against
  /// the data model.
  String resolveString(Object? v) => switch (resolve(v)) {
    null => '',
    final String s => s,
    final Object o => '$o',
  };

  /// Resolves version-matching data bindings (`{path}` in v0.9, `{@path}` from
  /// v1.0) and `formatString` calls recursively across maps and lists.
  ///
  /// Relative (template) paths resolve against [scope] when given; otherwise
  /// they return `null`, or throw [FormatException] when [rejectRelative] is
  /// true (such as when building an outbound `action`).
  Object? resolve(Object? v, {bool rejectRelative = false, Object? scope}) {
    if (isFormatStringCall(v, version: version)) {
      final raw = ((v as Map)['args'] as Map)['value'];
      final resolved = resolve(
        raw,
        rejectRelative: rejectRelative,
        scope: scope,
      );
      if (resolved == null) return '';
      final template = '$resolved';
      final List<Object?> parts;
      try {
        parts = ExpressionParser().parse(template);
      } on A2uiExpressionError {
        return template;
      }
      return [
        for (final part in parts)
          switch (resolve(
            _adaptExpressionPart(part),
            rejectRelative: rejectRelative,
            scope: scope,
          )) {
            null => '',
            final String s => s,
            // Nested formatter calls (`${formatNumber(value: /temp)}`) resolve
            // their `args` map; render the resolved `value` rather than
            // stringifying the call map.
            final Map m when m['args'] is Map => switch ((m['args']
                as Map)['value']) {
              null => '',
              final val => '$val',
            },
            final val => '$val',
          },
      ].join();
    }
    if (bindingPath(v, version: version) case final path?) {
      if (!path.startsWith('/')) {
        if (scope != null) return readPointer(scope, '/$path');
        if (rejectRelative) {
          throw FormatException('relative binding "$path"');
        }
        return null;
      }
      return getData(path);
    }
    return switch (v) {
      final Map m => <String, Object?>{
        for (final MapEntry(:key, :value) in m.entries)
          '$key': resolve(value, rejectRelative: rejectRelative, scope: scope),
      },
      final List l => <Object?>[
        for (final x in l)
          resolve(x, rejectRelative: rejectRelative, scope: scope),
      ],
      _ => v,
    };
  }

  /// Rewrites `ExpressionParser`'s v0.9-shaped `{path}` / `{call}` parts into
  /// `@path` / `@call` on v1.0+ surfaces so [resolve] handles them uniformly.
  Object? _adaptExpressionPart(Object? part) {
    if (version.startsWith('v0.')) return part;
    return switch (part) {
      {'path': final String p} => {'@path': p},
      {'call': final String fn, 'args': final Map args} => {
        '@call': fn,
        'args': {
          for (final MapEntry(:key, :value) in args.entries)
            '$key': _adaptExpressionPart(value),
        },
      },
      final List l => [for (final item in l) _adaptExpressionPart(item)],
      _ => part,
    };
  }
}

/// Applies A2UI messages and records violations.
final class HeadlessRenderer {
  final Map<String, SurfaceState> _surfaces = {};
  int _created = 0;

  /// Live surfaces in creation order.
  List<SurfaceState> get surfaces =>
      _surfaces.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  SurfaceState? operator [](String id) => _surfaces[id];

  /// Applies one turn's messages. Returns what changed per surface and the
  /// protocol violations a real renderer would have rejected.
  ({Map<String, SurfaceChange> changes, List<String> violations}) applyTurn(
    int turn,
    List<Map<String, dynamic>> messages,
  ) {
    final changes = <String, SurfaceChange>{};
    final violations = <String>[];
    // Surfaces deleted earlier in this same turn, so a delete followed by a
    // create of the same id reads as a replace.
    final deletedThisTurn = <String, SurfaceState>{};

    for (final m in messages) {
      if (m['createSurface'] case {'surfaceId': final String id}) {
        final c = m['createSurface'] as Map;
        if (_surfaces.containsKey(id)) {
          violations.add('createSurface for live surface "$id"');
          continue;
        }
        final prior = deletedThisTurn.remove(id);
        _surfaces[id] = SurfaceState(
          id,
          (c['catalogId'] as String?) ?? '',
          prior?.order ?? _created++,
          prior?.createdTurn ?? turn,
        );
        final s = _surfaces[id]!;
        if (m['version'] case final String v) s.version = v;
        // From v1.0 a createSurface may carry the whole tree and data model.
        if (c['components'] case final List components) {
          for (final comp in components.whereType<Map>()) {
            if (comp['id'] case final String cid) {
              s.components[cid] = _deepCopyJson(comp) as Map<String, dynamic>;
            }
          }
        }
        if (c['dataModel'] case final Map data) {
          s.setData('/', data);
        }
        changes[id] = prior != null
            ? SurfaceChange.replaced
            : SurfaceChange.created;
      } else if (m['updateComponents'] case {
        'surfaceId': final String id,
        'components': final List components,
      }) {
        final s = _surfaces[id];
        if (s == null) {
          violations.add('updateComponents for unknown surface "$id"');
          continue;
        }
        for (final c in components.whereType<Map>()) {
          if (c['id'] case final String cid) {
            s.components[cid] = _deepCopyJson(c) as Map<String, dynamic>;
          }
        }
        changes.putIfAbsent(id, () => SurfaceChange.updated);
      } else if (m['updateDataModel'] case {'surfaceId': final String id}) {
        final s = _surfaces[id];
        if (s == null) {
          violations.add('updateDataModel for unknown surface "$id"');
          continue;
        }
        final u = m['updateDataModel'] as Map;
        final path = (u['path'] as String?) ?? '/';
        final atRoot = path.isEmpty || path == '/';
        try {
          if (atRoot && u.containsKey('value') && u['value'] is! Map) {
            violations.add(
              'updateDataModel on "$id": root value must be an object',
            );
            s.setData('/', null);
          } else {
            s.setData(path, u['value']);
          }
        } on A2uiDataError catch (e) {
          violations.add('updateDataModel on "$id": ${e.message}');
        }
        changes.putIfAbsent(id, () => SurfaceChange.updated);
      } else if (m['deleteSurface'] case {'surfaceId': final String id}) {
        // Like a2ui_core: deleting an unknown surface is a no-op. The agent
        // deletes before every create, so this is the normal path for a new
        // surface.
        final s = _surfaces.remove(id);
        if (s == null) continue;
        deletedThisTurn[id] = s;
        changes[id] = SurfaceChange.deleted;
      }
    }

    // Graph checks on every surface this turn left in place.
    for (final MapEntry(key: id, value: change) in changes.entries) {
      if (change == SurfaceChange.deleted) continue;
      violations.addAll(_graphViolations(_surfaces[id]!));
    }
    return (changes: changes, violations: violations);
  }

  List<String> _graphViolations(SurfaceState s) {
    final out = <String>[];
    if (!s.components.containsKey('root')) {
      out.add('surface "${s.id}" has no root component');
    }
    for (final MapEntry(key: cid, value: c) in s.components.entries) {
      for (final ref in childRefs(c)) {
        if (!s.components.containsKey(ref)) {
          out.add('surface "${s.id}": "$cid" references missing "$ref"');
        }
      }
    }
    return out;
  }

  /// Component ids a component points at, per the basic catalog's
  /// `ComponentId` / `ChildList` properties.
  static Iterable<String> childRefs(Map<String, dynamic> c) sync* {
    for (final key in const ['child', 'trigger', 'content']) {
      if (c[key] case final String id) yield id;
    }
    switch (c['children']) {
      case final List ids:
        yield* ids.whereType<String>();
      case {'componentId': final String id}:
        yield id; // template
    }
    if (c['tabs'] case final List tabs) {
      for (final t in tabs) {
        if (t case {'child': final String id}) yield id;
      }
    }
  }
}

/// The data path [v] binds to under [version]: `{path}` in v0.9 (excluding
/// template `ChildList` maps), `{@path}` from v1.0.
String? bindingPath(Object? v, {String version = '1.0'}) {
  final v1 = !version.startsWith('v0.');
  return switch (v) {
    {'@path': final String path} when v1 => path,
    {'path': final String path} when !v1 && !v.containsKey('componentId') =>
      path,
    _ => null,
  };
}

/// Whether [v] is a `formatString` call under [version]
/// (`{call: 'formatString', args: ...}` in v0.9, `{@call: ...}` from v1.0).
bool isFormatStringCall(Object? v, {String version = '1.0'}) {
  final v1 = !version.startsWith('v0.');
  return switch (v) {
    {'@call': 'formatString', 'args': Map()} when v1 => true,
    {'call': 'formatString', 'args': Map()} when !v1 => true,
    _ => false,
  };
}

/// Reads a JSON Pointer (`/a/0/b`) out of [root].
Object? readPointer(Object? root, String pointer) {
  var cur = root;
  for (final seg in _segments(pointer)) {
    cur = switch (cur) {
      final Map m => m[seg],
      final List l => switch (int.tryParse(seg)) {
        final i? when i >= 0 && i < l.length => l[i],
        _ => null,
      },
      _ => null,
    };
    if (cur == null) return null;
  }
  return cur;
}

/// Writes [value] at a JSON Pointer in [root] using `a2ui_core`'s [DataModel].
void writePointer(Map<String, dynamic> root, String pointer, Object? value) {
  final model = DataModel(root)..set(pointer, value);
  root
    ..clear()
    ..addAll(switch (model.get('/')) {
      final Map m => _deepCopyJson(m) as Map<String, dynamic>,
      _ => const {},
    });
}

Iterable<String> _segments(String pointer) => pointer
    .split('/')
    .where((s) => s.isNotEmpty)
    .map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~'));

Object? _deepCopyJson(Object? v) => switch (v) {
  final Map m => <String, dynamic>{
    for (final MapEntry(:key, :value) in m.entries)
      '$key': _deepCopyJson(value),
  },
  final List l => <dynamic>[for (final item in l) _deepCopyJson(item)],
  _ => v,
};
