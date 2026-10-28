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

/// Derives A2UI Express positional signatures from catalog JSON Schemas.
///
/// A2UI Express is positional: the model writes `Text("Hello", "h3")` and the
/// compiler maps those arguments onto the component's properties *in schema
/// definition order*. Everything needed for that mapping already exists in the
/// spec's `catalog.json`, so this module derives it rather than asking catalog
/// authors to restate it:
///
/// | Express needs      | Comes from                                      |
/// |--------------------|-------------------------------------------------|
/// | positional order   | JSON property insertion order                    |
/// | required vs `?`    | the `required` array                             |
/// | `(static)`         | absence of a `$ref` to a Dynamic*/DataBinding    |
/// | enum values        | `enum`                                           |
/// | per-param docs     | `description`                                    |
/// | trailing `checks`  | a `$ref` to `Checkable`                          |
///
/// This mirrors `CatalogSchemaHelper` in the reference Python implementation;
/// [A2uiSignature.render] output is asserted against the upstream signature
/// strings in `test/express_signature_test.dart`.
library;

/// A single positional parameter in a component's or function's Express
/// signature.
class A2uiParam {
  /// The property name this argument maps to (e.g. `text`).
  final String name;

  /// Model-facing description, taken from the schema's `description`.
  final String? description;

  /// Whether the property is listed in the schema's `required` array.
  final bool required;

  /// Whether the value must be an inline literal. Data-model bindings
  /// (`$/path`) are rejected for these, per the spec's `(static)` annotation.
  final bool static;

  /// Allowed values, when the schema constrains them with `enum`.
  final List<String>? enumValues;

  /// The JSON Schema `type` to emit when authoring a catalog in Dart. Null for
  /// binding-capable params, which are emitted as a `$ref` instead.
  final String? jsonType;

  /// Whether this param accepts a data-model binding (`$/path`). The inverse of
  /// [static]; kept separate so authoring constructors can pick the right
  /// `$ref`.
  final bool binding;

  /// The `common_types.json` definition a binding-capable param refs.
  final String bindingRef;

  /// Whether this slot holds component *id(s)* rather than a value, as
  /// `Card.child` and `Column.children` do.
  ///
  /// The distinction is invisible in the compiled JSON (an id and a label are
  /// both strings), so it has to come from the schema. Without it a literal
  /// like `Button("Refresh", ...)` compiles to `"child": "Refresh"` and the
  /// renderer fails looking up a widget with that id.
  final bool isComponentRef;

  /// Creates an [A2uiParam]. Prefer the named constructors below when authoring
  /// a catalog; this one is what the schema crawler produces when reading one.
  const A2uiParam(
    this.name, {
    this.description,
    this.required = false,
    this.static = false,
    this.enumValues,
    this.jsonType,
    this.binding = false,
    this.bindingRef = 'DynamicString',
    this.isComponentRef = false,
  });

  /// A param accepting either a literal string or a `$/path` binding. This is
  /// the common case for text-like props (`Text.text`, `Image.url`).
  const A2uiParam.dynamicValue(
    String name, {
    String? description,
    bool required = false,
    String ref = 'DynamicString',
  }) : this(
         name,
         description: description,
         required: required,
         binding: true,
         bindingRef: ref,
       );

  /// A literal-only string param. Rendered as `(static)`.
  const A2uiParam.string(
    String name, {
    String? description,
    bool required = false,
    List<String>? enumValues,
  }) : this(
         name,
         description: description,
         required: required,
         static: true,
         enumValues: enumValues,
         jsonType: 'string',
       );

  /// A literal-only number param. Rendered as `(static)`.
  const A2uiParam.number(
    String name, {
    String? description,
    bool required = false,
  }) : this(
         name,
         description: description,
         required: required,
         static: true,
         jsonType: 'number',
       );

  /// A literal-only boolean param. Rendered as `(static)`.
  const A2uiParam.boolean(
    String name, {
    String? description,
    bool required = false,
  }) : this(
         name,
         description: description,
         required: required,
         static: true,
         jsonType: 'boolean',
       );

  /// A reference to one child component by id (`Card.child`).
  ///
  /// Emitted as a `ComponentId` `$ref` so the crawler reads it back as an id
  /// slot, matching the published catalogs.
  const A2uiParam.child(
    String name, {
    String? description,
    bool required = false,
  }) : this(
         name,
         description: description,
         required: required,
         static: true,
         binding: true,
         bindingRef: 'ComponentId',
         isComponentRef: true,
       );

  /// A reference to a list of child components by id (`Column.children`), or a
  /// `_template(...)` binding that generates them from a data list.
  const A2uiParam.children(
    String name, {
    String? description,
    bool required = false,
  }) : this(
         name,
         description: description,
         required: required,
         binding: true,
         bindingRef: 'ChildList',
         isComponentRef: true,
       );
}

/// A component's or function's ordered Express signature.
class A2uiSignature {
  /// The component or function name (e.g. `Button`).
  final String name;

  /// Parameters in positional order.
  final List<A2uiParam> params;

  /// Creates an [A2uiSignature].
  const A2uiSignature(this.name, this.params);

  /// Looks up a parameter by name.
  A2uiParam? operator [](String paramName) {
    for (final p in params) {
      if (p.name == paramName) return p;
    }
    return null;
  }

  /// Renders the one-line signature shown to the model, e.g.
  /// `Button(child (id), variant? (static), action (static))`.
  ///
  /// `(id)` wins over `(static)` for component-reference slots. Both are
  /// literal-only, but `(id)` is the stronger constraint and the one models get
  /// wrong, so it is what the marker should say.
  String render() {
    final args = params
        .map((p) {
          final optional = p.required ? '' : '?';
          final marker = p.isComponentRef
              ? ' (id)'
              : p.static
              ? ' (static)'
              : '';
          return '${p.name}$optional$marker';
        })
        .join(', ');
    return '$name($args)';
  }
}
