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

import 'dart:convert';

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

export 'package:json_schema_builder/json_schema_builder.dart'
    show Schema, SchemaValidation;

export 'package:schemantic/src/basic_types.dart';
export 'package:schemantic/src/flatten.dart' show SchemaFlatten;

/// Annotation to mark a class as a schema definition.
///
/// This annotation triggers the generation of a counterpart `Schema.g.dart`
/// file with a concrete implementation of the schema class and a type utility.
class Schematic {
  /// A description of the schema, to be included in the generated JSON Schema.
  final String? description;

  const Schematic({this.description});
}

class AnyOf {
  final List<Type> anyOf;

  const AnyOf(this.anyOf);
}

/// Annotation to customize valid JSON fields.
///
/// Use this annotation (or a subclass like [StringField], [IntegerField]) on a
/// getter
/// to specify a custom JSON key name, description, and other schema
/// constraints.
class Field {
  /// The key name to use in the JSON map.
  final String? name;

  /// A description of the field, which will be included in the generated JSON
  /// Schema.
  final String? description;

  /// The default value for the field.
  final Object? defaultValue;

  const Field({this.name, this.description, this.defaultValue});
}

/// Annotation for String fields with specific schema constraints.
class StringField extends Field {
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final List<String>? enumValues;

  const StringField({
    super.name,
    super.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.enumValues,
    String? defaultValue,
  }) : super(defaultValue: defaultValue);
}

/// Annotation for Integer fields with specific schema constraints.
class IntegerField extends Field {
  final int? minimum;
  final int? maximum;
  final int? exclusiveMinimum;
  final int? exclusiveMaximum;
  final int? multipleOf;

  const IntegerField({
    super.name,
    super.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    int? defaultValue,
  }) : super(defaultValue: defaultValue);
}

/// Annotation for Number (double) fields with specific schema constraints.
class DoubleField extends Field {
  final num? minimum;
  final num? maximum;
  final num? exclusiveMinimum;
  final num? exclusiveMaximum;
  final num? multipleOf;

  const DoubleField({
    super.name,
    super.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    num? defaultValue,
  }) : super(defaultValue: defaultValue);
}

/// Metadata associated with a [SchemanticType], primarily used for schema
/// generation.
class JsonSchemaMetadata {
  /// The name of the type in the schema (e.g. for $defs).
  final String? name;

  /// The JSON Schema definition.
  final jsb.Schema definition;

  /// Other types that this type depends on (for referencing via $defs).
  final List<SchemanticType> dependencies;

  const JsonSchemaMetadata({
    this.name,
    required this.definition,
    this.dependencies = const [],
  });
}

/// Base class for all runtime type utilities.
///
/// Provides methods to parse JSON and retrieve the JSON Schema.
abstract class SchemanticType<T> {
  const SchemanticType();

  /// Parses the given [json] object into type [T].
  ///
  /// Throws if the JSON data does not match the expected structure.
  T parse(Object? json);

  /// Returns the [jsb.Schema] for this type.
  ///
  /// If [useRefs] is true, the schema will use `$ref` to reference dependent
  /// types in a global `$defs` section. This is required for recursive schemas.
  jsb.Schema jsonSchema({bool useRefs = false}) {
    if (!useRefs) {
      if (schemaMetadata == null) return jsb.Schema.any();
      try {
        final inlinedMap = SchemaHelpers._inlineSchema(
          schemaMetadata!.definition,
          schemaMetadata!.dependencies,
          {},
        );
        return jsb.Schema.fromMap(inlinedMap);
      } catch (e) {
        throw StateError(
          'Failed to inline schema for ${schemaMetadata?.name}: $e',
        );
      }
    }
    return SchemaHelpers.buildSchema(this);
  }

  /// Metadata for this type, if available.
  JsonSchemaMetadata? get schemaMetadata => null;
}

/// Internal utilities for building JSON Schemas.
class SchemaHelpers {
  /// Builds a complete [jsb.Schema] for the [root] type, including all `$defs`.
  static jsb.Schema buildSchema(SchemanticType root) {
    if (root.schemaMetadata == null) {
      return root.jsonSchema(useRefs: false);
    }

    final definitions = <String, jsb.Schema>{};
    _collectDefinitions(root, definitions, {});

    final rootMeta = root.schemaMetadata!;

    if (rootMeta.name != null) {
      definitions[rootMeta.name!] = rootMeta.definition;
      return jsb.Schema.fromMap({
        r'$ref': '#/\$defs/${rootMeta.name}',
        r'$defs': definitions.map(
          (k, v) => MapEntry(k, jsonDecode(v.toJson())),
        ),
      });
    }

    return jsb.Schema.fromMap({
      'allOf': [rootMeta.definition.toJson()],
      r'$defs': definitions.map((k, v) => MapEntry(k, jsonDecode(v.toJson()))),
    });
  }

  static void _collectDefinitions(
    SchemanticType node,
    Map<String, jsb.Schema> definitions,
    Set<SchemanticType> visited,
  ) {
    if (visited.contains(node)) return;
    visited.add(node);

    final meta = node.schemaMetadata;
    if (meta == null) return;

    if (meta.name != null) {
      if (!definitions.containsKey(meta.name)) {
        definitions[meta.name!] = meta.definition;
      }
    }

    for (final dep in meta.dependencies) {
      _collectDefinitions(dep, definitions, visited);
    }
  }

  static Map<String, dynamic> _inlineSchema(
    jsb.Schema schema,
    List<SchemanticType> dependencies,
    Set<String> visited,
  ) {
    final json = jsonDecode(schema.toJson()) as Map<String, dynamic>;
    return _traverseAndInline(json, dependencies, visited);
  }

  static Map<String, dynamic> _traverseAndInline(
    Map<String, dynamic> json,
    List<SchemanticType> dependencies,
    Set<String> visited,
  ) {
    if (json.containsKey(r'$ref') || json.containsKey('ref')) {
      final ref = (json[r'$ref'] ?? json['ref']) as String;
      if (ref.startsWith('#/\$defs/')) {
        final name = ref.replaceFirst('#/\$defs/', '');
        if (visited.contains(name)) {
          throw StateError(
            'Recursive schema detected for $name without useRefs=true',
          );
        }

        final dependency = dependencies.firstWhere(
          (d) => d.schemaMetadata?.name == name,
          orElse: () =>
              throw StateError('Dependency $name not found for inlining'),
        );

        final meta = dependency.schemaMetadata!;
        return _inlineSchema(meta.definition, meta.dependencies, {
          ...visited,
          name,
        });
      }
    }

    final result = <String, dynamic>{};
    for (final key in json.keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        result[key] = _traverseAndInline(value, dependencies, visited);
      } else if (value is List) {
        result[key] = value.map((e) {
          if (e is Map<String, dynamic>) {
            return _traverseAndInline(e, dependencies, visited);
          }
          return e;
        }).toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }
}
