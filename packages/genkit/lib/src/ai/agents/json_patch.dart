// Copyright 2026 Google LLC
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

/// A tiny, dependency-free RFC 6902 (JSON Patch) implementation.
///
/// This module is intentionally self-contained and browser-safe (no `dart:io`,
/// no runtime dependencies) so it can be shared by the in-process server agent
/// and the browser-facing agent client.
///
/// Genkit uses JSON Patch to stream incremental changes to a session's custom
/// state (`AgentStreamChunk.customPatch`). The [diff] helper only emits
/// `add` / `remove` / `replace` operations (a valid RFC 6902 subset — `move` /
/// `copy` are optimizations we deliberately skip), while [applyPatch]
/// understands the full operation set for interoperability.
///
/// Values are plain JSON: `Map<String, dynamic>`, `List<dynamic>`, `String`,
/// `num`, `bool`, or `null`. This mirrors the JS `json-patch.ts` module so the
/// two implementations stay in sync (and produce identical wire output).
library;

/// A single RFC 6902 (JSON Patch) operation, as a plain JSON map:
/// `{op, path, from?, value?}`.
typedef JsonPatchOperationMap = Map<String, dynamic>;

/// An RFC 6902 JSON Patch: an ordered list of operations.
typedef JsonPatch = List<JsonPatchOperationMap>;

/// Escapes a single JSON Pointer reference token per RFC 6901 (`~` -> `~0`,
/// `/` -> `~1`).
String _escapeToken(String token) =>
    token.replaceAll('~', '~0').replaceAll('/', '~1');

/// Unescapes a single JSON Pointer reference token per RFC 6901.
String _unescapeToken(String token) =>
    token.replaceAll('~1', '/').replaceAll('~0', '~');

/// Parses a JSON Pointer string into its reference tokens.
///
/// The root pointer (`""`) parses to an empty list.
List<String> _parsePointer(String pointer) {
  if (pointer == '') return [];
  if (!pointer.startsWith('/')) {
    throw ArgumentError(
      'Invalid JSON Pointer: "$pointer" must start with "/".',
    );
  }
  return pointer.substring(1).split('/').map(_unescapeToken).toList();
}

/// Returns `true` for values that are plain JSON objects (not lists / null).
bool _isObject(Object? value) => value is Map;

/// Deep structural equality for JSON-serializable values.
bool _deepEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEqual(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

/// Deep clone of a JSON-serializable value.
T _clone<T>(T value) => _cloneValue(value) as T;

Object? _cloneValue(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key as String: _cloneValue(entry.value),
    };
  }
  if (value is List) {
    return <dynamic>[for (final item in value) _cloneValue(item)];
  }
  return value;
}

/// Computes an RFC 6902 JSON Patch that transforms [from] into [to].
///
/// The diff is rooted at the document, so pointers are bare (e.g.
/// `/agentStatus`, `/items/0`). Only `add` / `remove` / `replace` operations
/// are emitted.
///
/// When the two documents differ at the root in a way that cannot be expressed
/// as member-level changes (e.g. an object becomes a list, or a primitive
/// changes), a single whole-document `replace` at path `""` is returned.
JsonPatch diff(Object? from, Object? to) {
  final patch = <JsonPatchOperationMap>[];
  _diffRecursive(from, to, '', patch);
  return patch;
}

void _diffRecursive(Object? from, Object? to, String pointer, JsonPatch patch) {
  if (_deepEqual(from, to)) return;

  // Both plain objects - recurse member by member.
  if (_isObject(from) && _isObject(to)) {
    final fromMap = from as Map;
    final toMap = to as Map;
    final keys = <String>{
      ...fromMap.keys.cast<String>(),
      ...toMap.keys.cast<String>(),
    };
    for (final key in keys) {
      final childPointer = '$pointer/${_escapeToken(key)}';
      final inFrom = fromMap.containsKey(key);
      final inTo = toMap.containsKey(key);
      if (inFrom && !inTo) {
        patch.add({'op': 'remove', 'path': childPointer});
      } else if (!inFrom && inTo) {
        patch.add({
          'op': 'add',
          'path': childPointer,
          'value': _clone(toMap[key]),
        });
      } else {
        _diffRecursive(fromMap[key], toMap[key], childPointer, patch);
      }
    }
    return;
  }

  // Both lists - recurse by index, then add/remove the tail difference.
  if (from is List && to is List) {
    final min = from.length < to.length ? from.length : to.length;
    for (var i = 0; i < min; i++) {
      _diffRecursive(from[i], to[i], '$pointer/$i', patch);
    }
    if (to.length > from.length) {
      for (var i = from.length; i < to.length; i++) {
        // Appends use the "-" end-of-array token per RFC 6902.
        patch.add({'op': 'add', 'path': '$pointer/-', 'value': _clone(to[i])});
      }
    } else if (from.length > to.length) {
      // Remove from the tail backwards so indices stay valid as we go.
      for (var i = from.length - 1; i >= to.length; i--) {
        patch.add({'op': 'remove', 'path': '$pointer/$i'});
      }
    }
    return;
  }

  // Type mismatch or differing primitives - replace at this location.
  patch.add({'op': 'replace', 'path': pointer, 'value': _clone(to)});
}

/// Applies an RFC 6902 JSON Patch to [document], returning the new value.
///
/// The input is not mutated; a clone is patched and returned. Operating on the
/// root pointer (`""`) replaces / adds the whole document.
///
/// Apply is intentionally lenient to keep streaming robust: applying an `add` /
/// `replace` whose parent container is missing initializes the parent as an
/// object, and a `remove` / `replace` targeting a missing member is a no-op
/// rather than an error. `test` operations are honored and throw on mismatch.
Object? applyPatch(Object? document, JsonPatch patch) {
  var doc = _clone(document);
  for (final op in patch) {
    doc = _applyOperation(doc, op);
  }
  return doc;
}

Object? _applyOperation(Object? doc, JsonPatchOperationMap op) {
  final opName = op['op'] as String;
  final path = op['path'] as String;
  final tokens = _parsePointer(path);

  // Root operations replace / set the entire document.
  if (tokens.isEmpty) {
    switch (opName) {
      case 'add':
      case 'replace':
        return _clone(op['value']);
      case 'remove':
        return null;
      case 'test':
        if (!_deepEqual(doc, op['value'])) {
          throw StateError("JSON Patch 'test' failed at root.");
        }
        return doc;
      case 'move':
      case 'copy':
        return _clone(_getValue(doc, _parsePointer(op['from'] as String)));
      default:
        throw ArgumentError('Unsupported JSON Patch op: $opName');
    }
  }

  // Lenient: initialize a missing root container so member-level adds/replaces
  // still land (e.g. applying `/status` onto a null document).
  if (doc == null && (opName == 'add' || opName == 'replace')) {
    doc = <String, dynamic>{};
  }

  switch (opName) {
    case 'add':
      _setValue(doc, tokens, _clone(op['value']), true);
      return doc;
    case 'replace':
      _setValue(doc, tokens, _clone(op['value']), false);
      return doc;
    case 'remove':
      _removeValue(doc, tokens);
      return doc;
    case 'test':
      final actual = _getValue(doc, tokens);
      if (!_deepEqual(actual, op['value'])) {
        throw StateError("JSON Patch 'test' failed at \"$path\".");
      }
      return doc;
    case 'move':
      final fromTokens = _parsePointer(op['from'] as String);
      final value = _clone(_getValue(doc, fromTokens));
      _removeValue(doc, fromTokens);
      _setValue(doc, tokens, value, true);
      return doc;
    case 'copy':
      final value = _clone(_getValue(doc, _parsePointer(op['from'] as String)));
      _setValue(doc, tokens, value, true);
      return doc;
    default:
      throw ArgumentError('Unsupported JSON Patch op: $opName');
  }
}

/// Reads the value at [tokens], returning `null` for any missing segment.
Object? _getValue(Object? doc, List<String> tokens) {
  var cur = doc;
  for (final token in tokens) {
    if (cur == null) return null;
    if (cur is List) {
      final idx = int.tryParse(token);
      if (idx == null || idx < 0 || idx >= cur.length) return null;
      cur = cur[idx];
    } else if (cur is Map) {
      cur = cur[token];
    } else {
      return null;
    }
  }
  return cur;
}

/// Sets the value at [tokens], creating intermediate object containers as
/// needed. When [isAdd] is true and the parent is a list, the special `-`
/// token appends and a numeric token inserts at that index.
void _setValue(Object? doc, List<String> tokens, Object? value, bool isAdd) {
  final parent = _ensureParent(doc, tokens);
  if (parent == null) return; // Lenient: nothing to set onto.
  final last = tokens.last;
  if (parent is List) {
    if (last == '-') {
      parent.add(value);
      return;
    }
    final idx = int.tryParse(last);
    if (idx == null) return;
    if (isAdd) {
      if (idx < 0 || idx > parent.length) return;
      parent.insert(idx, value);
    } else {
      if (idx < 0 || idx >= parent.length) return;
      parent[idx] = value;
    }
    return;
  }
  if (parent is Map) {
    parent[last] = value;
  }
}

/// Removes the value at [tokens]. Missing members are a no-op.
void _removeValue(Object? doc, List<String> tokens) {
  final parent = _getValue(doc, tokens.sublist(0, tokens.length - 1));
  if (parent == null) return;
  final last = tokens.last;
  if (parent is List) {
    final idx = int.tryParse(last);
    if (idx != null && idx >= 0 && idx < parent.length) {
      parent.removeAt(idx);
    }
    return;
  }
  if (parent is Map) {
    parent.remove(last);
  }
}

/// Walks to the parent container of [tokens], lazily creating intermediate
/// objects for missing segments so leniently-applied patches still land.
Object? _ensureParent(Object? doc, List<String> tokens) {
  var cur = doc;
  for (var i = 0; i < tokens.length - 1; i++) {
    final token = tokens[i];
    if (cur == null) return null;
    Object? next;
    if (cur is List) {
      final idx = int.tryParse(token);
      next = (idx != null && idx >= 0 && idx < cur.length) ? cur[idx] : null;
    } else if (cur is Map) {
      next = cur[token];
    } else {
      return null;
    }
    if (next is! Map && next is! List) {
      final created = <String, dynamic>{};
      if (cur is List) {
        final idx = int.tryParse(token);
        if (idx == null || idx < 0 || idx >= cur.length) return null;
        cur[idx] = created;
      } else if (cur is Map) {
        cur[token] = created;
      }
      cur = created;
    } else {
      cur = next;
    }
  }
  return cur;
}
