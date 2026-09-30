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

/// Rewriting a Genkit JSON schema into the shape Anthropic's structured
/// outputs accept.
///
/// Separate from the plugin because it is pure: a map in, a map out, with no
/// request, model or client in sight.
library;

import 'dart:convert';

/// Keywords whose value is a single nested schema.
const _schemaValuedKeywords = {
  'items',
  'additionalItems',
  'contains',
  'not',
  'if',
  'then',
  'else',
  'propertyNames',
};

/// Keywords whose value is a list of schemas.
const _schemaListKeywords = {'allOf', 'anyOf', 'oneOf', 'prefixItems'};

/// Keywords Anthropic rejects by name, and the one it takes instead.
///
/// `oneOf` answers "Schema type 'oneOf' is not supported" while `anyOf` with
/// the same branches is accepted. `SchemanticType.nullable()` emits `oneOf`,
/// so an optional field would otherwise 400. The two differ only in whether
/// more than one branch may match, which a generator emitting a nullable union
/// does not rely on.
const _renamedKeywords = {'oneOf': 'anyOf'};

/// Keywords whose value maps names to schemas.
const _schemaMapKeywords = {
  'properties',
  r'$defs',
  'definitions',
  'patternProperties',
};

/// Validation keywords Anthropic's structured-output schema rejects.
///
/// `output_config.format` validates the schema strictly and 400s on these -
/// "For 'integer' type, properties maximum, minimum are not supported". The
/// tool fallback never validated, which is why they rode through unnoticed.
/// Genkit's own generator emits them from `@IntegerField(minimum:)` and
/// friends, so ordinary annotated types hit this.
///
/// Dropped rather than translated: they constrain values, and losing them
/// costs a validation the model was never guaranteed to honour anyway.
const _unsupportedValidationKeywords = {
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'multipleOf',
  'minLength',
  'maxLength',
  'pattern',
  'minItems',
  'maxItems',
  'uniqueItems',
  'minProperties',
  'maxProperties',
};

/// Whether [type] denotes an object, including the nullable `["object",
/// "null"]` spelling schemantic emits for an optional object field.
bool _isObjectType(Object? type) =>
    type == 'object' || (type is List && type.contains('object'));

/// Rewrites a Genkit JSON schema into the shape Anthropic accepts.
///
/// Anthropic rejects `$schema`, rejects the validation keywords above, and
/// requires `additionalProperties: false` on every object, including ones
/// nested under `$defs`.
///
/// Recursion follows JSON Schema structure rather than descending into every
/// map it meets. A `properties` map is not itself a schema - descending into
/// it applied the object inference and the closed marker to the map of field
/// names, which corrupted any schema with a field called `type`, `properties`
/// or `required`.
Map<String, dynamic> toAnthropicSchema(Map<String, dynamic> schema) {
  final out = <String, dynamic>{};
  for (final entry in schema.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key == r'$schema') continue;
    if (_unsupportedValidationKeywords.contains(key)) continue;
    final outKey = _renamedKeywords[key] ?? key;

    if (_schemaMapKeywords.contains(key) && value is Map) {
      out[outKey] = {
        for (final field in value.entries)
          field.key.toString(): _asSchema(field.value),
      };
    } else if (_schemaListKeywords.contains(key) && value is List) {
      out[outKey] = value.map(_asSchema).toList();
    } else if (_schemaValuedKeywords.contains(key)) {
      // `items` may be a list of schemas in older drafts.
      out[outKey] = value is List
          ? value.map(_asSchema).toList()
          : _asSchema(value);
    } else if (key == 'additionalProperties') {
      // Dropped, and re-set to `false` below. Anthropic takes no other value:
      // a schema, `true` and `{"type": "string"}` all answer "For 'object'
      // type, 'additionalProperties: object' is not supported. Please set
      // 'additionalProperties' to false". JS does the same.
      continue;
    } else {
      out[outKey] = value;
    }
  }
  // A `$ref` node may not carry sibling constraints; Anthropic rejects the
  // combination outright. Named Genkit schemas arrive as a bare `$ref` plus
  // `$defs`, and the recursion above has already closed the definitions.
  if (out.containsKey(r'$ref')) return out;

  // A hand-written schema may describe an object through its keywords alone.
  // Anthropic needs the type spelled out before it will accept the closed
  // marker below, so infer it the way the tool fallback does.
  if (!out.containsKey('type') &&
      (out.containsKey('properties') || out.containsKey('required'))) {
    out['type'] = 'object';
  }
  // Closed, always. `false` is the only value Anthropic's validator accepts,
  // so a dictionary field - `Map<String, T>`, which schemantic emits as
  // `additionalProperties: {...}` - cannot be expressed natively at all: its
  // value schema is dropped and the map is constrained to the properties named
  // here, which for an open map is none. Sending the value schema instead is
  // not an option; it is a 400. See the README note on `Map` fields.
  if (_isObjectType(out['type'])) {
    out['additionalProperties'] = false;
  }
  return out;
}

/// Normalises [value] when it is a schema, and leaves anything else alone.
Object? _asSchema(Object? value) => switch (value) {
  final Map<String, dynamic> map => toAnthropicSchema(map),
  final Map map => toAnthropicSchema(map.cast<String, dynamic>()),
  _ => value,
};

/// Whether Anthropic's structured-output validator can express [schema]
/// without changing what it means.
///
/// Three shapes it cannot, all of which schemantic emits for ordinary types:
///
/// - an empty schema, which it rejects outright - "Empty schema ({}) that
///   accepts any JSON value is not supported. Please specify a concrete type."
///   `$Schema.any()`, and so a `dynamic` or `Object?` field, is exactly that;
/// - an open map. `additionalProperties` may only be `false` here, so a
///   `Map<String, T>` field - which schemantic emits as
///   `additionalProperties: {...}` - would be closed to an object with no
///   properties at all, and the model answers `{}`. Checked live;
/// - a recursive type (`class Node { List<Node> children; }`), whose `$defs`
///   entry refers back to itself. Anthropic does not support recursive
///   schemas and answers with a 400.
///
/// None has a faithful rewrite. A union of every concrete type is accepted in
/// place of `{}`, but its object branch must carry
/// `additionalProperties: false`, and the model then answers an object value
/// as a *string* of JSON. Silently changing or dropping a field's value is
/// worse than not constraining it, so a schema this returns false for is sent
/// through the prompt instead: unenforced, but intact.
bool isNativelyExpressible(Map<String, dynamic> schema) =>
    !_isBeyondTheValidator(schema) && !_isRecursive(schema);

bool _isBeyondTheValidator(Object? node) {
  if (node is! Map) return false;
  final map = node.cast<String, dynamic>();
  // The root of a schema document is never "empty" by accident: `{}` as a
  // whole document means the same thing as `{}` in a property position.
  if (map.isEmpty) return true;
  for (final entry in map.entries) {
    final key = entry.key;
    final value = entry.value;
    // `false` is the only value the validator takes, so anything else - a
    // value schema, or `true` - is an open map it would quietly close.
    if (key == 'additionalProperties' && value != false) return true;
    if (_schemaMapKeywords.contains(key) && value is Map) {
      if (value.values.any(_isBeyondTheValidator)) return true;
    } else if (_schemaListKeywords.contains(key) && value is List) {
      if (value.any(_isBeyondTheValidator)) return true;
    } else if (_schemaValuedKeywords.contains(key)) {
      if (value is List) {
        if (value.any(_isBeyondTheValidator)) return true;
      } else if (_isBeyondTheValidator(value)) {
        return true;
      }
    }
  }
  return false;
}

/// Whether any local `$ref` in [schema] can reach itself again, either as `#`
/// (the document root) or through the document's `$defs` (or legacy
/// `definitions`).
///
/// Refs that point outside the document, or at a definition that does not
/// exist, are left to Anthropic's validator to judge.
bool _isRecursive(Map<String, dynamic> schema) {
  if (_refsIn(schema).contains('#')) return true;
  final defs = <String, Object?>{
    for (final key in const [r'$defs', 'definitions'])
      if (schema[key] case final Map<dynamic, dynamic> map)
        for (final entry in map.entries)
          '#/$key/${_escapePointerToken('${entry.key}')}': entry.value,
  };
  if (defs.isEmpty) return false;

  // Refs each definition mentions directly, then a depth-first search for a
  // cycle over that graph. `done` marks definitions already proven acyclic.
  final edges = {
    for (final entry in defs.entries) entry.key: _refsIn(entry.value),
  };
  final done = <String>{};
  bool reachesCycle(String ref, Set<String> path) {
    if (path.contains(ref)) return true;
    if (done.contains(ref) || !edges.containsKey(ref)) return false;
    path.add(ref);
    final cyclic = edges[ref]!.any((next) => reachesCycle(next, path));
    path.remove(ref);
    if (!cyclic) done.add(ref);
    return cyclic;
  }

  return edges.keys.any((ref) => reachesCycle(ref, <String>{}));
}

/// Escapes a `$defs` key into a JSON Pointer token, so it matches the `$ref`
/// that names it: `~` becomes `~0` and `/` becomes `~1`, in that order.
///
/// A key holding either character is not something schemantic emits, but a
/// hand-written schema can: unescaped, `a/b` would be looked up as
/// `#/$defs/a/b` while the ref says `#/$defs/a~1b`, and a cycle through it
/// would read as acyclic and reach Anthropic as a 400.
String _escapePointerToken(String key) =>
    key.replaceAll('~', '~0').replaceAll('/', '~1');

/// Every `$ref` under [node] that JSON Schema reads as a reference.
///
/// Follows schema structure rather than descending into every map, because a
/// `$ref` key can also appear in *instance data* - a `default`, `const` or
/// `enum` value is an ordinary JSON value, and `{"$ref": "#"}` there is a
/// two-character string field, not a cycle. Walking those would report a
/// self-reference that does not exist and send an expressible schema to the
/// prompt instead of constraining it natively.
Set<String> _refsIn(Object? node) {
  final refs = <String>{};
  void collect(Object? n) {
    if (n is! Map) return;
    if (n[r'$ref'] case final String ref) refs.add(ref);
    for (final entry in n.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_schemaMapKeywords.contains(key) && value is Map) {
        value.values.forEach(collect);
      } else if (_schemaListKeywords.contains(key) && value is List) {
        value.forEach(collect);
      } else if (_schemaValuedKeywords.contains(key)) {
        if (value is List) {
          value.forEach(collect);
        } else {
          collect(value);
        }
      }
    }
  }

  collect(node);
  return refs;
}

/// The schema, rendered for a prompt, when it cannot travel as a constraint.
///
/// Worded like core's JSON format instructions, so a model reads the same
/// text whichever path put it there.
String schemaInstructions(Map<String, dynamic> schema) =>
    'Output should be in JSON format and conform to the following schema:\n\n'
    '```\n${const JsonEncoder.withIndent('  ').convert(schema)}\n```\n';
