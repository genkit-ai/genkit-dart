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

/// A2UI catalog types, matching the wire format of the spec's `catalog.json`.
///
/// A catalog pins what a surface may render. It is stored exactly as the A2UI
/// specification defines it - `components` and `functions` are name-keyed maps
/// of JSON Schema - so a published catalog file loads unmodified and a catalog
/// authored here stays portable to any other A2UI host.
///
/// Component *props are not restated in prose*: the Express compiler derives
/// positional signatures straight from these schemas (see
/// `src/express/schema_crawler.dart`). For hand-authored catalogs,
/// [A2uiCatalogComponent.simple] builds a conforming schema from a parameter
/// list so nobody has to write JSON Schema by hand.
library;

import 'express/schema_crawler.dart';
import 'express/signature.dart';

/// A component's API: its name and the JSON Schema declaring its props.
class A2uiCatalogComponent {
  /// The component type name, e.g. `Text`.
  final String name;

  /// The component's JSON Schema, in the spec's `catalog.json` shape.
  ///
  /// Property order is significant: it is the positional argument order the
  /// model is prompted with and that the compiler maps arguments onto.
  final Map<String, dynamic> schema;

  /// Creates an [A2uiCatalogComponent] from a raw JSON Schema.
  const A2uiCatalogComponent({required this.name, required this.schema});

  /// Builds a spec-shaped component from an ordered parameter list, for
  /// catalogs authored in Dart rather than loaded from a `catalog.json`.
  ///
  /// ```dart
  /// A2uiCatalogComponent.simple(
  ///   name: 'Gauge',
  ///   description: 'A circular gauge for a single numeric value.',
  ///   params: [
  ///     A2uiParam.dynamicValue('value', required: true),
  ///     A2uiParam.number('max', description: 'Range maximum.'),
  ///   ],
  /// );
  /// ```
  factory A2uiCatalogComponent.simple({
    required String name,
    String? description,
    required List<A2uiParam> params,
    bool checkable = false,
  }) {
    // `component` is first so the emitted schema reads like the spec's, and it
    // is filtered back out when deriving the signature.
    final properties = <String, dynamic>{
      'component': {'const': name},
    };
    final required = <String>['component'];

    for (final p in params) {
      // `checks` is contributed by the Checkable fragment, not by a property.
      if (p.name == 'checks') continue;
      properties[p.name] = _schemaForParam(p);
      if (p.required) required.add(p.name);
    }

    return A2uiCatalogComponent(
      name: name,
      schema: {
        'type': 'object',
        'description': ?description,
        if (checkable || params.any((p) => p.name == 'checks'))
          'allOf': [
            {r'$ref': '$_commonTypes#/\$defs/Checkable'},
          ],
        'properties': properties,
        'required': required,
      },
    );
  }

  /// The ordered Express signature derived from [schema].
  A2uiSignature get signature => componentSignature(name, schema);

  /// Builds an [A2uiCatalogComponent] from a `catalog.json` entry.
  factory A2uiCatalogComponent.fromJson(
    String name,
    Map<String, dynamic> schema,
  ) => A2uiCatalogComponent(name: name, schema: schema);

  /// Serializes this component back to its `catalog.json` schema.
  Map<String, dynamic> toJson() => schema;
}

/// A client function's API (`required`, `regex`, `openUrl`, ...), used for
/// `?check` rules and client-side calls.
class A2uiCatalogFunction {
  /// The function name, e.g. `regex`.
  final String name;

  /// The function's JSON Schema, in the spec's `catalog.json` shape.
  final Map<String, dynamic> schema;

  /// Creates an [A2uiCatalogFunction].
  const A2uiCatalogFunction({required this.name, required this.schema});

  /// The ordered Express signature derived from [schema].
  A2uiSignature get signature => functionSignature(name, schema);

  /// Serializes this function back to its `catalog.json` schema.
  Map<String, dynamic> toJson() => schema;
}

/// A parsed catalog: an id plus the components and client functions it exposes.
///
/// Mirrors the spec's `catalog.json`: [components] and [functions] are keyed by
/// name, and iteration order is preserved so derived Express signatures are
/// stable.
class A2uiCatalog {
  /// Globally-unique catalog id (also used as `catalogId` on `createSurface`).
  final String id;

  /// The components available in this catalog, keyed by component name.
  final Map<String, A2uiCatalogComponent> components;

  /// The client functions available for `?check` rules and client-side calls,
  /// keyed by function name. Empty for catalogs that declare none.
  final Map<String, A2uiCatalogFunction> functions;

  /// Creates an [A2uiCatalog].
  const A2uiCatalog({
    required this.id,
    required this.components,
    this.functions = const {},
  });

  /// Builds an [A2uiCatalog] from a spec `catalog.json` document.
  ///
  /// Accepts the published files verbatim: the id is read from `catalogId`
  /// (falling back to `$id`, then `id`), and `components`/`functions` are
  /// name-keyed objects of JSON Schema.
  factory A2uiCatalog.fromJson(Map<String, dynamic> json) {
    final id =
        (json['catalogId'] as String?) ??
        (json[r'$id'] as String?) ??
        (json['id'] as String?) ??
        '';

    final components = <String, A2uiCatalogComponent>{};
    final rawComponents = json['components'];
    if (rawComponents is Map) {
      for (final entry in rawComponents.entries) {
        final name = entry.key;
        final schema = entry.value;
        // Skip malformed entries defensively rather than throwing on a bad cast.
        if (name is String && schema is Map) {
          components[name] = A2uiCatalogComponent(
            name: name,
            schema: schema.cast<String, dynamic>(),
          );
        }
      }
    }

    final functions = <String, A2uiCatalogFunction>{};
    final rawFunctions = json['functions'];
    if (rawFunctions is Map) {
      for (final entry in rawFunctions.entries) {
        final name = entry.key;
        final schema = entry.value;
        if (name is String && schema is Map) {
          functions[name] = A2uiCatalogFunction(
            name: name,
            schema: schema.cast<String, dynamic>(),
          );
        }
      }
    }

    return A2uiCatalog(id: id, components: components, functions: functions);
  }

  /// Convenience for authoring in Dart: builds a catalog from a component list,
  /// keying it by component name.
  factory A2uiCatalog.of({
    required String id,
    required List<A2uiCatalogComponent> components,
    List<A2uiCatalogFunction> functions = const [],
  }) => A2uiCatalog(
    id: id,
    components: {for (final c in components) c.name: c},
    functions: {for (final f in functions) f.name: f},
  );

  /// Returns a copy with [components] and [functions] merged over this
  /// catalog's, for extending a base catalog with bespoke components.
  A2uiCatalog extend({
    required String id,
    List<A2uiCatalogComponent> components = const [],
    List<A2uiCatalogFunction> functions = const [],
  }) => A2uiCatalog(
    id: id,
    components: {...this.components, for (final c in components) c.name: c},
    functions: {...this.functions, for (final f in functions) f.name: f},
  );

  /// Serializes this catalog to its `catalog.json` shape.
  Map<String, dynamic> toJson() => {
    'catalogId': id,
    'components': {
      for (final entry in components.entries) entry.key: entry.value.toJson(),
    },
    if (functions.isNotEmpty)
      'functions': {
        for (final entry in functions.entries) entry.key: entry.value.toJson(),
      },
  };
}

const String _commonTypes =
    'https://a2ui.org/specification/v0_9/common_types.json';

/// Maps a declarative parameter onto the JSON Schema fragment the spec uses,
/// so `(static)`, enums and descriptions all round-trip through the crawler.
Map<String, dynamic> _schemaForParam(A2uiParam p) {
  final description = p.description;
  return {
    if (p.binding) r'$ref': '$_commonTypes#/\$defs/${p.bindingRef}',
    if (!p.binding && p.jsonType != null) 'type': p.jsonType,
    'description': ?description,
    if (p.enumValues != null) 'enum': p.enumValues,
  };
}
