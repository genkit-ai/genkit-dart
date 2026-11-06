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
/// the catalog through [A2uiCatalogCore.toCore]. For hand-authored catalogs,
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
  ///     A2uiParam.dynamicValue('value', required: true, type: .number),
  ///     A2uiParam.number('max', description: 'Range maximum.'),
  ///   ],
  /// );
  /// ```
  ///
  /// [params] order is the Express positional argument order, so put the most
  /// important values first. [checkable] adds the spec's `checks` property.
  /// Param names must be unique, and `component` and `id` are reserved.
  factory A2uiCatalogComponent.simple({
    required String name,
    String? description,
    required List<A2uiParam> params,
    bool checkable = false,
  }) {
    // Thrown rather than asserted: a production build would otherwise ship a
    // schema where one param silently overwrites another (or the
    // `component` discriminator).
    if (params.map((p) => p.name).toSet().length != params.length) {
      throw ArgumentError.value(
        params.map((p) => p.name).toList(),
        'params',
        'A2uiCatalogComponent.simple($name): duplicate param names',
      );
    }
    if (params.any((p) => p.name == 'component' || p.name == 'id')) {
      throw ArgumentError.value(
        params.map((p) => p.name).toList(),
        'params',
        'A2uiCatalogComponent.simple($name): `component` and `id` are reserved',
      );
    }
    final properties = <String, dynamic>{
      'component': {'const': name},
      for (final p in params) p.name: p._schema(),
    };
    return A2uiCatalogComponent(
      name: name,
      schema: _frozen({
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
      }),
    );
  }

  /// Builds an [A2uiCatalogComponent] from a `catalog.json` entry, keeping a
  /// frozen copy of [schema].
  factory A2uiCatalogComponent.fromJson(
    String name,
    Map<String, dynamic> schema,
  ) => A2uiCatalogComponent(name: name, schema: _frozen(schema));

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

  /// The value type of a [A2uiParam.dynamicValue].
  final A2uiDynamicType? _dynamicType;

  /// The schema of an [A2uiParam.schema], used as given.
  final Map<String, dynamic>? _rawSchema;

  /// Allowed values, for literal-only string params.
  final List<String>? enumValues;

  const A2uiParam._(
    this.name, {
    this.description,
    this.required = false,
    this._type,
    this._ref,
    this._dynamicType,
    this._rawSchema,
    this.enumValues,
  });

  /// A literal or a `$/path` binding, of the value [type] (a string unless
  /// set).
  const A2uiParam.dynamicValue(
    String name, {
    String? description,
    bool required = false,
    A2uiDynamicType type = A2uiDynamicType.string,
  }) : this._(
         name,
         description: description,
         required: required,
         dynamicType: type,
       );

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

  /// A property with a hand-written JSON Schema, for the one property the
  /// other kinds do not cover (keeping the rest of the component on
  /// [A2uiCatalogComponent.simple]).
  ///
  /// ```dart
  /// A2uiParam.schema('size', {'type': 'integer', 'minimum': 1, 'maximum': 5})
  /// ```
  const A2uiParam.schema(
    String name,
    Map<String, dynamic> schema, {
    bool required = false,
  }) : this._(name, required: required, rawSchema: schema);

  Map<String, dynamic> _schema() =>
      _rawSchema ??
      {
        if (_ref ?? _dynamicType?._ref case final ref?)
          r'$ref': '$_commonTypes#/\$defs/$ref',
        if (_type != null) 'type': _type,
        'description': ?description,
        'enum': ?enumValues,
      };
}

/// The value type of an [A2uiParam.dynamicValue], i.e. which of the spec's
/// `common_types.json` dynamic types it references.
enum A2uiDynamicType {
  /// `DynamicString`.
  string('DynamicString'),

  /// `DynamicNumber`.
  number('DynamicNumber'),

  /// `DynamicBoolean`.
  boolean('DynamicBoolean'),

  /// `DynamicStringList`.
  stringList('DynamicStringList'),

  /// `DynamicValue`: any JSON value.
  value('DynamicValue');

  const A2uiDynamicType(this._ref);

  final String _ref;
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

  /// Builds an [A2uiCatalogFunction] from a `catalog.json` entry, keeping a
  /// frozen copy of [schema].
  factory A2uiCatalogFunction.fromJson(
    String name,
    Map<String, dynamic> schema,
  ) => A2uiCatalogFunction(name: name, schema: _frozen(schema));

  /// Serializes this function back to its `catalog.json` schema.
  Map<String, dynamic> toJson() => schema;
}

/// A parsed catalog: an id plus the components and client functions it exposes.
///
/// Mirrors the spec's `catalog.json`: [components] and [functions] are keyed by
/// name. Their order is kept for round trips, but is not what the model sees
/// (`a2ui_agent` lists signatures alphabetically); the order of a component's
/// properties is, since Express arguments are positional.
///
/// A catalog is immutable, schemas included: [A2uiCatalog.fromJson] and
/// `A2uiCatalogComponent.simple` keep frozen copies. A schema passed to the
/// raw `A2uiCatalogComponent(...)` constructor must not be changed later,
/// since the form `a2ui_agent` reads is derived once per catalog.
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

  /// Catalog-wide guidance for the model (the spec's `instructions`), included
  /// in the prompt after the component signatures.
  final String? instructions;

  /// Creates an [A2uiCatalog] from its components and functions, keyed by
  /// name. Names must be unique.
  ///
  /// The maps are unmodifiable: build a new catalog (see [extend]) rather than
  /// editing one, since the form `a2ui_agent` reads is derived once per
  /// instance.
  A2uiCatalog({
    required String id,
    required Iterable<A2uiCatalogComponent> components,
    Iterable<A2uiCatalogFunction> functions = const [],
    String? instructions,
  }) : this._(
         id: id,
         components: _byName(components, (c) => c.name),
         functions: _byName(functions, (f) => f.name),
         instructions: instructions,
       );

  A2uiCatalog._({
    required this.id,
    required Map<String, A2uiCatalogComponent> components,
    required Map<String, A2uiCatalogFunction> functions,
    Map<String, dynamic> defs = const {},
    this.instructions,
    Map<String, dynamic> extra = const {},
  }) : components = Map.unmodifiable(components),
       functions = Map.unmodifiable(functions),
       defs = _frozen(defs),
       _extra = _frozen(extra);

  /// Top-level `catalog.json` fields this class does not model (such as
  /// `protocolVersion` or `theme`), kept so a loaded document round-trips
  /// and reaches `a2ui_core` whole.
  final Map<String, dynamic> _extra;

  static const _modeled = {
    'catalogId',
    r'$id',
    'id',
    'components',
    'functions',
    r'$defs',
    'instructions',
  };

  static Map<String, T> _byName<T>(
    Iterable<T> items,
    String Function(T) nameOf,
  ) {
    final out = <String, T>{};
    for (final item in items) {
      if (out.containsKey(nameOf(item))) {
        throw ArgumentError('duplicate name "${nameOf(item)}"');
      }
      out[nameOf(item)] = item;
    }
    return out;
  }

  /// Builds an [A2uiCatalog] from a spec `catalog.json` document.
  ///
  /// Accepts the published files verbatim: the id is read from `catalogId`
  /// (falling back to `$id`, then `id`), and `components`/`functions` are
  /// name-keyed objects of JSON Schema. A `$defs.anyComponent` (or
  /// `anyFunction`) union that lists only some entries restricts the catalog
  /// to those, as it does for `a2ui_core`. Malformed entries are skipped
  /// rather than thrown on; `loadCatalog` checks the raw document first.
  ///
  /// Throws a [FormatException] for the pre-spec shape, where `components` is
  /// a list.
  factory A2uiCatalog.fromJson(Map<String, dynamic> json) {
    if (json['components'] is List) {
      throw const FormatException(
        'A2uiCatalog.fromJson: "components" must be an object keyed by '
        'component name (the A2UI catalog.json shape), not a list.',
      );
    }
    final allowedComponents = _unionMembers(json, 'anyComponent', 'components');
    final allowedFunctions = _unionMembers(json, 'anyFunction', 'functions');
    final id = [
      json['catalogId'],
      json[r'$id'],
      json['id'],
    ].whereType<String>().firstOrNull;

    Map<String, Map<String, dynamic>> schemas(Object? raw) => {
      if (raw is Map)
        for (final MapEntry(:key, :value) in raw.entries)
          if (key is String && value is Map) key: value.cast<String, dynamic>(),
    };

    return A2uiCatalog._(
      id: id ?? '',
      components: {
        for (final MapEntry(:key, :value) in schemas(
          json['components'],
        ).entries)
          if (allowedComponents?.contains(key) ?? true)
            key: A2uiCatalogComponent.fromJson(key, value),
      },
      functions: {
        for (final MapEntry(:key, :value) in schemas(json['functions']).entries)
          if (allowedFunctions?.contains(key) ?? true)
            key: A2uiCatalogFunction.fromJson(key, value),
      },
      defs: {
        if (json[r'$defs'] case final Map defs)
          for (final MapEntry(:key, :value) in defs.entries)
            if (key is String && !_derivedDefs.contains(key)) key: value,
      },
      instructions: switch (json['instructions']) {
        final String s => s,
        _ => null,
      },
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_modeled.contains(key)) key: value,
      },
    );
  }

  /// `$defs` entries computed from [components] and [functions]. A published
  /// catalog lists its own components in them, and `a2ui_core` reads such a
  /// list as "the document defines only these", so keeping them would make
  /// [extend] silently drop every component it adds.
  static const _derivedDefs = {'anyComponent', 'anyFunction'};

  /// The names a `$defs.<union>` lists (`{"oneOf": [{"$ref":
  /// "#/<section>/Name"}, ...]}`), or null if the document has no such union.
  static Set<String>? _unionMembers(
    Map<String, dynamic> json,
    String union,
    String section,
  ) {
    if (json[r'$defs'] case final Map defs when defs[union] is Map) {
      final u = defs[union] as Map;
      return {
        for (final key in const ['oneOf', 'anyOf'])
          if (u[key] case final List refs)
            for (final r in refs)
              if (r case {
                r'$ref': final String ref,
              } when ref.startsWith('#/$section/'))
                ref.substring('#/$section/'.length),
      };
    }
    return null;
  }

  /// Top-level fields that describe one document, which an extension under a
  /// new id should not inherit.
  static const _documentOnly = {'title', 'description'};

  /// Returns a copy under a new [id] with [components] and [functions] added,
  /// for extending a base catalog with bespoke components.
  ///
  /// An entry named like one of this catalog's replaces it; overriding a
  /// component changes its Express positional signature, so do it
  /// deliberately. Names within each argument must be unique.
  /// [instructions], when given, replaces this catalog's (pass `''` to clear
  /// them). The base document's `title` and `description` are not carried
  /// over.
  A2uiCatalog extend({
    required String id,
    Iterable<A2uiCatalogComponent> components = const [],
    Iterable<A2uiCatalogFunction> functions = const [],
    String? instructions,
  }) => A2uiCatalog._(
    id: id,
    components: {...this.components, ..._byName(components, (c) => c.name)},
    functions: {...this.functions, ..._byName(functions, (f) => f.name)},
    defs: defs,
    instructions: switch (instructions ?? this.instructions) {
      '' => null,
      final i => i,
    },
    extra: {
      for (final MapEntry(:key, :value) in _extra.entries)
        if (!_documentOnly.contains(key)) key: value,
    },
  );

  /// Returns a copy registered under a different [id].
  A2uiCatalog withId(String id) => A2uiCatalog._(
    id: id,
    components: components,
    functions: functions,
    defs: defs,
    instructions: instructions,
    extra: _extra,
  );

  /// Serializes this catalog to its `catalog.json` shape.
  Map<String, dynamic> toJson() => {
    ..._extra,
    'catalogId': id,
    'components': {
      for (final entry in components.entries) entry.key: entry.value.toJson(),
    },
    if (functions.isNotEmpty)
      'functions': {
        for (final entry in functions.entries) entry.key: entry.value.toJson(),
      },
    if (defs.isNotEmpty) r'$defs': defs,
    'instructions': ?instructions,
  };
}

/// A deep, unmodifiable copy of a JSON value.
T _frozen<T>(T value) => _freeze(value) as T;

Object? _freeze(Object? value) => switch (value) {
  final Map m => Map<String, dynamic>.unmodifiable({
    for (final MapEntry(:key, :value) in m.entries) '$key': _freeze(value),
  }),
  final List l => List<dynamic>.unmodifiable(l.map(_freeze)),
  _ => value,
};

/// Checks a raw `catalog.json` document the way `a2ui_core` will, before
/// [A2uiCatalog.fromJson] skips anything malformed. Throws `A2uiCatalogError`.
void checkCatalogDocument(Map<String, dynamic> json) =>
    core.Catalog.fromJson(json.cast<String, Object?>());

/// The bridge to `a2ui_core`, kept out of the public API so a breaking
/// `a2ui_core` release is not a breaking change here.
extension A2uiCatalogCore on A2uiCatalog {
  /// This catalog as an `a2ui_core` catalog, the form `a2ui_agent` prompts
  /// and compiles against. Parsed once per instance.
  ///
  /// Throws `A2uiCatalogError` if the catalog is not a valid catalog document.
  core.CatalogApi toCore() =>
      _coreCatalogs[this] ??= core.Catalog.fromJson(toJson());
}

final _coreCatalogs = Expando<core.CatalogApi>();

const String _commonTypes =
    'https://a2ui.org/specification/v0_9/common_types.json';
