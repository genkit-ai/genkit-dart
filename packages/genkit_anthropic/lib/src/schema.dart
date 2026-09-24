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
