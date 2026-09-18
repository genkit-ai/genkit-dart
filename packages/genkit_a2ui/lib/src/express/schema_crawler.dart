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

/// Crawls A2UI catalog JSON Schemas into Express positional signatures.
///
/// Port of `CatalogSchemaHelper` from the reference Python implementation. See
/// `signature.dart` for the mapping from schema constructs to signature parts.
library;

import 'signature.dart';

/// Structural keys that describe the component itself rather than one of its
/// props, so they never become positional arguments.
const _structuralKeys = {'component', 'id'};

/// Reads a component's ordered Express signature out of its JSON Schema.
///
/// The schema's property insertion order *is* the positional argument order.
/// `jsonDecode` produces a `LinkedHashMap`, so order survives a round trip
/// through a catalog file - but it also means reordering two properties in a
/// catalog silently rebinds every existing Express statement written against
/// it. Treat property order in a published catalog as part of its contract.
A2uiSignature componentSignature(String name, Map<String, dynamic> schema) {
  final props = <String, Map<String, dynamic>>{};
  final required = <String>{};
  var checkable = false;

  // Flatten `allOf` into the root schema. The spec's catalogs compose each
  // component from shared fragments (ComponentCommon, Checkable, ...) plus one
  // inline object holding the component's own props.
  for (final sub in _selfAndAllOf(schema)) {
    if (_refMentions(sub[r'$ref'], 'Checkable')) checkable = true;

    final subProps = sub['properties'];
    if (subProps is Map) {
      for (final entry in subProps.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map) {
          props[key] = value.cast<String, dynamic>();
        }
      }
    }

    final subRequired = sub['required'];
    if (subRequired is List) {
      required.addAll(subRequired.whereType<String>());
    }
  }

  final params = <A2uiParam>[];
  for (final entry in props.entries) {
    if (_structuralKeys.contains(entry.key)) continue;
    params.add(_paramFor(entry.key, entry.value, required.contains(entry.key)));
  }

  // Checkable components accept a trailing `checks` list of validation rules.
  // It is not a declared property, so the reference appends it explicitly.
  if (checkable) {
    params.add(
      const A2uiParam(
        'checks',
        description: 'Client-side validation rules, e.g. [?required, ?email].',
        static: true,
      ),
    );
  }

  return A2uiSignature(name, params);
}

/// Reads a client function's ordered Express signature out of its JSON Schema.
///
/// Functions nest their parameters under `properties.args.properties` rather
/// than declaring them at the top level like components do.
A2uiSignature functionSignature(String name, Map<String, dynamic> schema) {
  final params = <A2uiParam>[];

  for (final sub in _selfAndAllOf(schema)) {
    final properties = sub['properties'];
    if (properties is! Map) continue;
    final args = properties['args'];
    if (args is! Map) continue;

    final argProps = args['properties'];
    if (argProps is! Map) continue;

    final argRequired = <String>{};
    final rawRequired = args['required'];
    if (rawRequired is List) {
      argRequired.addAll(rawRequired.whereType<String>());
    }

    for (final entry in argProps.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is Map) {
        params.add(
          _paramFor(
            key,
            value.cast<String, dynamic>(),
            argRequired.contains(key),
          ),
        );
      }
    }
  }

  return A2uiSignature(name, params);
}

/// Builds a single parameter from its property schema.
A2uiParam _paramFor(String name, Map<String, dynamic> schema, bool isRequired) {
  final description = schema['description'];
  return A2uiParam(
    name,
    description: description is String ? description : null,
    required: isRequired,
    // A property is `(static)` exactly when it cannot hold a binding.
    static: !allowsDataBinding(schema),
    enumValues: _enumOf(schema),
  );
}

/// The schema itself followed by its `allOf` members (non-recursive, matching
/// the reference implementation).
Iterable<Map<String, dynamic>> _selfAndAllOf(
  Map<String, dynamic> schema,
) sync* {
  yield schema;
  final allOf = schema['allOf'];
  if (allOf is List) {
    for (final sub in allOf) {
      if (sub is Map) yield sub.cast<String, dynamic>();
    }
  }
}

/// Whether a property accepts a data-model binding (`{"path": "/x"}`), which
/// is the inverse of the spec's `(static)` annotation.
///
/// Detected structurally, by looking for a `$ref` to one of the protocol's
/// dynamic value types (`DynamicString`, `DataBinding`, ...). This mirrors the
/// reference implementation; a catalog naming its own binding types something
/// else would need an inline `{ path }` object property instead.
bool allowsDataBinding(Object? schema) {
  if (schema is! Map) return false;

  final ref = schema[r'$ref'];
  if (_refMentions(ref, 'DataBinding') ||
      _refMentions(ref, 'Dynamic') ||
      _refMentions(ref, 'ChildList')) {
    return true;
  }

  // An inline `{ path }` object. `componentId` marks a template child list
  // rather than a value binding, so it does not count.
  final properties = schema['properties'];
  if (properties is Map &&
      properties.containsKey('path') &&
      !properties.containsKey('componentId')) {
    return true;
  }

  final items = schema['items'];
  if (items != null && allowsDataBinding(items)) return true;

  for (final key in const ['allOf', 'oneOf', 'anyOf']) {
    final branch = schema[key];
    if (branch is List && branch.any(allowsDataBinding)) return true;
  }

  return false;
}

/// Whether a property references other components by id (`child`, `children`,
/// `trigger`, ...). The compiler uses this to turn variable references into
/// component ids, and the decompiler to turn them back.
bool isComponentReference(Object? schema) {
  if (schema is! Map) return false;

  final ref = schema[r'$ref'];
  if (_refMentions(ref, 'ComponentId') ||
      _refMentions(ref, 'ChildList') ||
      _refMentions(ref, 'Child')) {
    return true;
  }

  if (schema['type'] == 'array') {
    final items = schema['items'];
    if (items != null && isComponentReference(items)) return true;
  }

  for (final key in const ['allOf', 'oneOf', 'anyOf']) {
    final branch = schema[key];
    if (branch is List && branch.any(isComponentReference)) return true;
  }

  return false;
}

/// Recursively finds an `enum` constraint, following composition branches.
List<String>? _enumOf(Object? schema) {
  if (schema is! Map) return null;

  final values = schema['enum'];
  if (values is List) {
    final strings = values.whereType<String>().toList();
    if (strings.isNotEmpty) return strings;
  }

  for (final key in const ['oneOf', 'anyOf', 'allOf']) {
    final branch = schema[key];
    if (branch is List) {
      for (final sub in branch) {
        final found = _enumOf(sub);
        if (found != null) return found;
      }
    }
  }

  return null;
}

/// Whether a `$ref` mentions [needle]. Refs are absolute URLs into the spec's
/// `common_types.json`, so a substring test is how the reference identifies
/// them too.
bool _refMentions(Object? ref, String needle) =>
    ref is String && ref.contains(needle);
