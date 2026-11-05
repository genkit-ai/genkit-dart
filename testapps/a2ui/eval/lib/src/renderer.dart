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

/// A headless stand-in for a v0.9 A2UI renderer.
///
/// Applies messages the way a renderer would (create, update, delete) and
/// reports protocol violations instead of drawing anything. Deliberately small:
/// `a2ui_core`'s `MessageProcessor` needs function implementations for every
/// catalog function, which is more than this harness needs. The middleware
/// already runs `a2ui_agent`'s per-block checks under `validate: 'strict'`;
/// this layer adds the cross-turn rules a single block cannot see.
library;

/// What a turn did to one surface.
enum SurfaceChange { created, replaced, updated, deleted }

/// One rendered surface.
final class SurfaceState {
  SurfaceState(this.id, this.catalogId, this.order, this.createdTurn);

  final String id;
  final String catalogId;

  /// Creation order across the conversation (stable across replacements), so
  /// scenarios can refer to "the first surface".
  final int order;

  /// The turn that first created this surface (kept across replacements).
  final int createdTurn;

  final Map<String, Map<String, dynamic>> components = {};
  Map<String, dynamic> data = {};

  /// Every literal string and data-model value on the surface, lowercased, for
  /// content assertions like "mentions Paris".
  String get searchableText {
    final out = StringBuffer();
    void walk(Object? v) {
      switch (v) {
        case String s:
          out
            ..write(s.toLowerCase())
            ..write(' ');
        case num n:
          out
            ..write(n)
            ..write(' ');
        case Map m:
          m.values.forEach(walk);
        case List l:
          l.forEach(walk);
      }
    }

    components.values.forEach(walk);
    walk(data);
    return out.toString();
  }

  Set<String> get componentTypes => {
    for (final c in components.values)
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

  /// A dynamic value as display text: literals as-is, `{path}` bindings
  /// resolved against the data model.
  String resolveString(Object? v) => switch (resolve(v)) {
    null => '',
    final String s => s,
    final Object o => '$o',
  };

  /// Resolves a `{path: ...}` binding against the data model; literals pass
  /// through. Relative (template) paths are not supported.
  Object? resolve(Object? v) {
    if (v case {'path': final String path}) return readPointer(data, path);
    return v;
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
            s.components[cid] = c.cast<String, dynamic>();
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
        if (path == '/' || path.isEmpty) {
          s.data = (u['value'] as Map?)?.cast<String, dynamic>() ?? {};
        } else {
          writePointer(s.data, path, u['value']);
        }
        changes.putIfAbsent(id, () => SurfaceChange.updated);
      } else if (m['deleteSurface'] case {'surfaceId': final String id}) {
        final s = _surfaces.remove(id);
        if (s == null) {
          violations.add('deleteSurface for unknown surface "$id"');
          continue;
        }
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
      for (final ref in _childRefs(c)) {
        if (!s.components.containsKey(ref)) {
          out.add('surface "${s.id}": "$cid" references missing "$ref"');
        }
      }
    }
    return out;
  }

  /// Component ids a component points at, per the v0.9 basic catalog's
  /// `ComponentId` / `ChildList` properties.
  static Iterable<String> _childRefs(Map<String, dynamic> c) sync* {
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

/// Reads a JSON Pointer (`/a/0/b`) out of [root].
Object? readPointer(Object? root, String pointer) {
  Object? cur = root;
  for (final seg in _segments(pointer)) {
    cur = switch (cur) {
      Map m => m[seg],
      List l => switch (int.tryParse(seg)) {
        final i? when i >= 0 && i < l.length => l[i],
        _ => null,
      },
      _ => null,
    };
    if (cur == null) return null;
  }
  return cur;
}

/// Writes [value] at a JSON Pointer in [root], creating maps along the way.
void writePointer(Map<String, dynamic> root, String pointer, Object? value) {
  final segs = _segments(pointer).toList();
  if (segs.isEmpty) return;
  Map<String, dynamic> cur = root;
  for (final seg in segs.take(segs.length - 1)) {
    cur = switch (cur[seg]) {
      final Map m => m.cast<String, dynamic>(),
      _ => cur[seg] = <String, dynamic>{},
    };
  }
  cur[segs.last] = value;
}

Iterable<String> _segments(String pointer) => pointer
    .split('/')
    .where((s) => s.isNotEmpty)
    .map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~'));
