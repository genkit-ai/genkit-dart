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

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

import 'src/basic_types.dart' as bt;


/// Metadata associated with a [SchemanticType], primarily used for schema
/// generation.
final class JsonSchemaMetadata {
  /// The name of the type in the schema (e.g. for $defs).
  final String? name;

  /// The JSON Schema definition.
  final Map<String, Object?> definition;

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

  /// Creates a schema from a JSON schema and a parse function.
  static SchemanticType<T> from<T>({
    required Map<String, Object?> jsonSchema,
    required T Function(dynamic json) parse,
  }) => _AdHocSchema(jsonSchema, parse);

  /// Parses the given [json] object into type [T].
  ///
  /// Throws if the JSON data does not match the expected structure.
  T parse(Object? json);

  /// Returns the schema for this type.
  ///
  /// If [useRefs] is true, the schema will use `$ref` to reference dependent
  /// types in a global `$defs` section. This is required for recursive schemas.
  Map<String, Object?> jsonSchema({bool useRefs = false}) {
    if (!useRefs) {
      if (schemaMetadata == null) return jsb.Schema.any().value;
      try {
        final inlinedMap = schemaMetadata!.definition.inlineSchema(
          schemaMetadata!.dependencies,
          {},
        );
        return jsb.Schema.fromMap(inlinedMap).value;
      } catch (e) {
        throw StateError(
          'Failed to inline schema for ${schemaMetadata?.name}: $e',
        );
      }
    }
    return buildSchema();
  }

  /// Metadata for this type, if available.
  JsonSchemaMetadata? get schemaMetadata => null;

  /// Creates a string schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.string();
  /// schema.parse('hello');
  /// ```
  static SchemanticType<String> string({
    String? description,
    int? minLength,
    int? maxLength,
    String? pattern,
    String? format,
    List<String>? enumValues,
    String? defaultValue,
  }) => bt.stringSchema(
    description: description,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
    enumValues: enumValues,
    defaultValue: defaultValue,
  );

  /// Creates an integer schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.integer();
  /// schema.parse(123);
  /// ```
  static SchemanticType<int> integer({
    String? description,
    int? minimum,
    int? maximum,
    int? exclusiveMinimum,
    int? exclusiveMaximum,
    int? multipleOf,
    int? defaultValue,
  }) => bt.intSchema(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
    defaultValue: defaultValue,
  );

  /// Creates a double schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.doubleSchema();
  /// schema.parse(12.34);
  /// ```
  static SchemanticType<double> doubleSchema({
    String? description,
    double? minimum,
    double? maximum,
    double? exclusiveMinimum,
    double? exclusiveMaximum,
    double? multipleOf,
    double? defaultValue,
  }) => bt.doubleSchema(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
    defaultValue: defaultValue,
  );

  /// A boolean schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.boolean();
  /// schema.parse(true);
  /// ```
  static SchemanticType<bool> boolean({
    String? description,
    bool? defaultValue,
  }) => bt.boolSchema(description: description, defaultValue: defaultValue);

  /// Creates a void schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.voidSchema();
  /// schema.parse(null);
  /// ```
  static SchemanticType<void> voidSchema({String? description}) =>
      bt.voidSchema(description: description);

  /// Creates a dynamic schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.dynamicSchema();
  /// schema.parse('anything');
  /// ```
  static SchemanticType<dynamic> dynamicSchema({String? description}) =>
      bt.dynamicSchema(description: description);

  /// Creates a strongly typed List schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.list(.string());
  /// schema.parse(['a', 'b']);
  /// ```
  static SchemanticType<List<T>> list<T>(
    SchemanticType<T> itemType, {
    String? description,
    int? minItems,
    int? maxItems,
    bool? uniqueItems,
  }) => bt.listSchema(
    itemType,
    description: description,
    minItems: minItems,
    maxItems: maxItems,
    uniqueItems: uniqueItems,
  );

  /// Creates a strongly typed Map schema.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.map(.string(), .integer());
  /// schema.parse({'a': 1});
  /// ```
  static SchemanticType<Map<K, V>> map<K, V>(
    SchemanticType<K> keyType,
    SchemanticType<V> valueType, {
    String? description,
    int? minProperties,
    int? maxProperties,
  }) => bt.mapSchema(
    keyType,
    valueType,
    description: description,
    minProperties: minProperties,
    maxProperties: maxProperties,
  );

  /// Makes a schema nullable.
  ///
  /// Example:
  /// ```dart
  /// final schema = SchemanticType.nullable(.string());
  /// schema.parse(null);
  /// ```
  static SchemanticType<T?> nullable<T>(SchemanticType<T> type) =>
      bt.nullable(type);
}

/// Internal utilities for building JSON Schemas.
extension on SchemanticType {
  /// Builds a complete schema for this type, including all `$defs`.
  Map<String, Object?> buildSchema() {
    final rootMeta = schemaMetadata;
    if (rootMeta == null) return jsonSchema(useRefs: false);

    final definitions = <String, Map<String, Object?>>{};
    collectDefinitions(definitions, {});

    if (rootMeta.name != null) {
      definitions[rootMeta.name!] = rootMeta.definition;
      return {
        r'$ref': '#/\$defs/${rootMeta.name}',
        r'$defs': definitions.map(
          (k, v) => MapEntry(k, jsb.Schema.fromMap(v).value),
        ),
      };
    }

    return {
      'allOf': [rootMeta.definition],
      r'$defs': definitions.map(
        (k, v) => MapEntry(k, jsb.Schema.fromMap(v).value),
      ),
    };
  }

  void collectDefinitions(
    Map<String, Map<String, Object?>> definitions,
    Set<SchemanticType> visited,
  ) {
    if (!visited.add(this)) return;

    final meta = schemaMetadata;
    if (meta == null) return;

    if (meta.name != null) {
      if (!definitions.containsKey(meta.name)) {
        definitions[meta.name!] = meta.definition;
      }
    }

    for (final dep in meta.dependencies) {
      dep.collectDefinitions(definitions, visited);
    }
  }
}

extension on Map<String, Object?> {
  Map<String, dynamic> inlineSchema(
    List<SchemanticType> dependencies,
    Set<String> visited,
  ) => traverseAndInline(dependencies, visited);

  Map<String, dynamic> traverseAndInline(
    List<SchemanticType> dependencies,
    Set<String> visited,
  ) {
    if (containsKey(r'$ref') || containsKey('ref')) {
      final ref = (this[r'$ref'] ?? this['ref']) as String;
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
        return meta.definition.inlineSchema(meta.dependencies, {
          ...visited,
          name,
        });
      }
    }

    final result = <String, dynamic>{};
    for (final key in keys) {
      final value = this[key];
      if (value is Map<String, dynamic>) {
        result[key] = value.traverseAndInline(dependencies, visited);
      } else if (value is List) {
        result[key] = value.map((e) {
          if (e is Map<String, dynamic>) {
            return e.traverseAndInline(dependencies, visited);
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

class _AdHocSchema<T> extends SchemanticType<T> {
  final Map<String, Object?> _jsonSchema;
  final T Function(dynamic json) _parse;

  const _AdHocSchema(this._jsonSchema, this._parse);

  @override
  T parse(Object? json) => _parse(json);

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      Map.from(_jsonSchema);
}
