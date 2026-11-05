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
/// specification defines it (`components` and `functions` are name-keyed maps
/// of JSON Schema), so a published catalog file loads unmodified and a catalog
/// authored here stays portable to any other A2UI host.
///
/// Prompting and Express compilation are delegated to `a2ui_agent`, which reads
/// the catalog through [A2uiCatalog.toCore]. For hand-authored catalogs,
/// [A2uiCatalogComponent.simple] builds a conforming schema from a parameter
/// list so nobody has to write JSON Schema by hand.
library;

import 'package:a2ui_core/a2ui_core.dart' as core;

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
  ///     A2uiParam.dynamicValue('value', required: true, ref: 'DynamicNumber'),
  ///     A2uiParam.number('max', description: 'Range maximum.'),
  ///   ],
  /// );
  /// ```
  ///
  /// [params] order is the Express positional argument order, so put the most
  /// important values first. [checkable] adds the spec's `checks` property.
  factory A2uiCatalogComponent.simple({
    required String name,
    String? description,
    required List<A2uiParam> params,
    bool checkable = false,
  }) {
    final properties = <String, dynamic>{
      'component': {'const': name},
      for (final p in params) p.name: p._schema(),
    };
    return A2uiCatalogComponent(
      name: name,
      schema: {
        'type': 'object',
        'description': ?description,
        if (checkable)
          'allOf': [
            {r'$ref': '$_commonTypes#/\$defs/Checkable'},
          ],
        'properties': properties,
        'required': [
          'component',
          for (final p in params)
            if (p.required) p.name,
        ],
      },
    );
  }

  /// Builds an [A2uiCatalogComponent] from a `catalog.json` entry.
  factory A2uiCatalogComponent.fromJson(
    String name,
    Map<String, dynamic> schema,
  ) => A2uiCatalogComponent(name: name, schema: schema);

  /// Serializes this component back to its `catalog.json` schema.
  Map<String, dynamic> toJson() => schema;
}

/// One property of a component authored with [A2uiCatalogComponent.simple].
///
/// Each constructor emits the JSON Schema fragment the spec uses for that kind
/// of property, which is what tells the Express compiler whether a slot takes
/// a literal, a `$/path` binding, a component id or an action.
class A2uiParam {
  /// The property name, e.g. `text`.
  final String name;

  /// Model-facing description.
  final String? description;

  /// Whether the component must set this property.
  final bool required;

  /// The JSON Schema `type`, for literal-only params.
  final String? _type;

  /// The `common_types.json` definition this param references, if any.
  final String? _ref;

  /// Allowed values, for literal-only string params.
  final List<String>? enumValues;

  const A2uiParam._(
    this.name, {
    this.description,
    this.required = false,
    this._type,
    this._ref,
    this.enumValues,
  });

  /// A literal or a `$/path` binding. [ref] picks the value type:
  /// `DynamicString` (the default), `DynamicNumber`, `DynamicBoolean`,
  /// `DynamicStringList` or `DynamicValue`.
  const A2uiParam.dynamicValue(
    String name, {
    String? description,
    bool required = false,
    String ref = 'DynamicString',
  }) : this._(name, description: description, required: required, ref: ref);

  /// A literal-only string, optionally restricted to [enumValues].
  const A2uiParam.string(
    String name, {
    String? description,
    bool required = false,
    List<String>? enumValues,
  }) : this._(
         name,
         description: description,
         required: required,
         type: 'string',
         enumValues: enumValues,
       );

  /// A literal-only number.
  const A2uiParam.number(
    String name, {
    String? description,
    bool required = false,
  }) : this._(
         name,
         description: description,
         required: required,
         type: 'number',
       );

  /// A literal-only boolean.
  const A2uiParam.boolean(
    String name, {
    String? description,
    bool required = false,
  }) : this._(
         name,
         description: description,
         required: required,
         type: 'boolean',
       );

  /// The id of one child component (`Card.child`).
  const A2uiParam.child(
    String name, {
    String? description,
    bool required = false,
  }) : this._(
         name,
         description: description,
         required: required,
         ref: 'ComponentId',
       );

  /// A list of child component ids (`Column.children`), or a `_template(...)`
  /// binding that generates them from a data-model list.
  const A2uiParam.children(
    String name, {
    String? description,
    bool required = false,
  }) : this._(
         name,
         description: description,
         required: required,
         ref: 'ChildList',
       );

  /// An action fired on interaction (`Button.action`), written
  /// `Event("name", {context})` in Express.
  const A2uiParam.action(
    String name, {
    String? description,
    bool required = false,
  }) : this._(
         name,
         description: description,
         required: required,
         ref: 'Action',
       );

  Map<String, dynamic> _schema() => {
    if (_ref != null) r'$ref': '$_commonTypes#/\$defs/$_ref',
    if (_type != null) 'type': _type,
    'description': ?description,
    'enum': ?enumValues,
  };
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

  /// Serializes this function back to its `catalog.json` schema.
  Map<String, dynamic> toJson() => schema;
}

/// A parsed catalog: an id plus the components and client functions it exposes.
///
/// Mirrors the spec's `catalog.json`: [components] and [functions] are keyed by
/// name, and iteration order is preserved because it is the order the model is
/// prompted with.
class A2uiCatalog {
  /// Globally-unique catalog id (also used as `catalogId` on `createSurface`).
  final String id;

  /// The components available in this catalog, keyed by component name.
  final Map<String, A2uiCatalogComponent> components;

  /// The client functions available for `?check` rules and client-side calls,
  /// keyed by function name. Empty for catalogs that declare none.
  final Map<String, A2uiCatalogFunction> functions;

  /// Any document-level `$defs`, kept so local `#/$defs/...` references in a
  /// published catalog still resolve after a round trip.
  final Map<String, dynamic> defs;

  /// Creates an [A2uiCatalog].
  const A2uiCatalog({
    required this.id,
    required this.components,
    this.functions = const {},
    this.defs = const {},
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

    // Skip malformed entries defensively rather than throwing on a bad cast.
    Map<String, Map<String, dynamic>> schemas(Object? raw) => {
      if (raw is Map)
        for (final MapEntry(:key, :value) in raw.entries)
          if (key is String && value is Map) key: value.cast<String, dynamic>(),
    };

    return A2uiCatalog(
      id: id,
      components: {
        for (final MapEntry(:key, :value) in schemas(
          json['components'],
        ).entries)
          key: A2uiCatalogComponent(name: key, schema: value),
      },
      functions: {
        for (final MapEntry(:key, :value) in schemas(json['functions']).entries)
          key: A2uiCatalogFunction(name: key, schema: value),
      },
      defs: (json[r'$defs'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
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
    defs: defs,
  );

  /// Returns a copy registered under a different [id].
  A2uiCatalog withId(String id) => A2uiCatalog(
    id: id,
    components: components,
    functions: functions,
    defs: defs,
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
    if (defs.isNotEmpty) r'$defs': defs,
  };

  /// This catalog as an `a2ui_core` catalog, the form `a2ui_agent` prompts
  /// and compiles against. Parsed once per instance.
  ///
  /// Throws `A2uiCatalogError` if the catalog is not a valid catalog document.
  core.CatalogApi toCore() =>
      _coreCatalogs[this] ??= core.Catalog.fromJson(toJson());
}

// An Expando rather than a `late final` field, which would rule out the const
// constructor.
final _coreCatalogs = Expando<core.CatalogApi>();

const String _commonTypes =
    'https://a2ui.org/specification/v0_9/common_types.json';
