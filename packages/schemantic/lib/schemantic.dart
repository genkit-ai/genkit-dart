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

import 'src/basic_types.dart' as bt;

export 'package:json_schema_builder/json_schema_builder.dart'
    show SchemaValidation;

export 'package:schemantic/src/flatten.dart' show SchemaFlatten;

typedef $Schema = jsb.Schema;

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

  /// Parses the given [json] object into type [T].
  ///
  /// Throws if the JSON data does not match the expected structure.
  T parse(Object? json);

  /// Validates the given [data] against this schema.
  ///
  /// Returns a list of [ValidationError] if validation fails,
  /// or an empty list if validation succeeds.
  Future<List<ValidationError>> validate(
    Object? data, {
    bool useRefs = false,
  }) async => (await jsb.Schema.fromMap(
    jsonSchema(useRefs: useRefs),
  ).validate(data)).map(ValidationError._).toList();

  /// Returns the schema for this type.
  ///
  /// If [useRefs] is true, the schema will use `$ref` to reference dependent
  /// types in a global `$defs` section. This is required for recursive schemas.
  Map<String, Object?> jsonSchema({bool useRefs = false}) {
    if (!useRefs) {
      if (schemaMetadata == null) return jsb.Schema.any().value;
      try {
        final inlinedMap = SchemaHelpers._inlineSchema(
          schemaMetadata!.definition,
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
    return SchemaHelpers.buildSchema(this);
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
class SchemaHelpers {
  /// Builds a complete schema for the [root] type, including all `$defs`.
  static Map<String, Object?> buildSchema(SchemanticType root) {
    if (root.schemaMetadata == null) {
      return root.jsonSchema(useRefs: false);
    }

    final definitions = <String, Map<String, Object?>>{};
    _collectDefinitions(root, definitions, {});

    final rootMeta = root.schemaMetadata!;

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

  static void _collectDefinitions(
    SchemanticType node,
    Map<String, Map<String, Object?>> definitions,
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
    Map<String, Object?> schema,
    List<SchemanticType> dependencies,
    Set<String> visited,
  ) {
    final json = jsb.Schema.fromMap(schema).value;
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

extension type ValidationError._(jsb.ValidationError _error) {
  /// The type of validation error that occurred.
  ValidationErrorType get error => _error.error.wrapped;

  /// The path to the object that had the error.
  List<String> get path => _error.path;

  /// Additional details about the error (optional).
  String? get details => _error.details;

  /// Returns a human-readable string representation of the error.
  String toErrorString() {
    return '${details != null ? '$details' : error.name} at path '
        '#root${path.map((p) => '["$p"]').join('')}'
        '';
  }
}

enum ValidationErrorType {
  // For custom validation.
  custom,

  // General
  typeMismatch,
  constMismatch,
  enumValueNotAllowed,
  formatInvalid,
  refResolutionError,

  // Schema combinators
  allOfNotMet,
  anyOfNotMet,
  oneOfNotMet,
  notConditionViolated,
  ifThenElseInvalid,

  // Object specific
  requiredPropertyMissing,
  dependentRequiredMissing,
  additionalPropertyNotAllowed,
  minPropertiesNotMet,
  maxPropertiesExceeded,
  propertyNamesInvalid,
  patternPropertyValueInvalid,
  unevaluatedPropertyNotAllowed,

  // Array/List specific
  minItemsNotMet,
  maxItemsExceeded,
  uniqueItemsViolated,
  containsInvalid,
  minContainsNotMet,
  maxContainsExceeded,
  itemInvalid,
  prefixItemInvalid,
  unevaluatedItemNotAllowed,

  // String specific
  minLengthNotMet,
  maxLengthExceeded,
  patternMismatch,

  // Number/Integer specific
  minimumNotMet,
  maximumExceeded,
  exclusiveMinimumNotMet,
  exclusiveMaximumExceeded,
  multipleOfInvalid,
}

extension on jsb.ValidationErrorType {
  ValidationErrorType get wrapped => switch (this) {
    .custom => .custom,
    .typeMismatch => .typeMismatch,
    .constMismatch => .constMismatch,
    .enumValueNotAllowed => .enumValueNotAllowed,
    .formatInvalid => .formatInvalid,
    .refResolutionError => .refResolutionError,
    .allOfNotMet => .allOfNotMet,
    .anyOfNotMet => .anyOfNotMet,
    .oneOfNotMet => .oneOfNotMet,
    .notConditionViolated => .notConditionViolated,
    .ifThenElseInvalid => .ifThenElseInvalid,
    .requiredPropertyMissing => .requiredPropertyMissing,
    .dependentRequiredMissing => .dependentRequiredMissing,
    .additionalPropertyNotAllowed => .additionalPropertyNotAllowed,
    .minPropertiesNotMet => .minPropertiesNotMet,
    .maxPropertiesExceeded => .maxPropertiesExceeded,
    .propertyNamesInvalid => .propertyNamesInvalid,
    .patternPropertyValueInvalid => .patternPropertyValueInvalid,
    .unevaluatedPropertyNotAllowed => .unevaluatedPropertyNotAllowed,
    .minItemsNotMet => .minItemsNotMet,
    .maxItemsExceeded => .maxItemsExceeded,
    .uniqueItemsViolated => .uniqueItemsViolated,
    .containsInvalid => .containsInvalid,
    .minContainsNotMet => .minContainsNotMet,
    .maxContainsExceeded => .maxContainsExceeded,
    .itemInvalid => .itemInvalid,
    .prefixItemInvalid => .prefixItemInvalid,
    .unevaluatedItemNotAllowed => .unevaluatedItemNotAllowed,
    .minLengthNotMet => .minLengthNotMet,
    .maxLengthExceeded => .maxLengthExceeded,
    .patternMismatch => .patternMismatch,
    .minimumNotMet => .minimumNotMet,
    .maximumExceeded => .maximumExceeded,
    .exclusiveMinimumNotMet => .exclusiveMinimumNotMet,
    .exclusiveMaximumExceeded => .exclusiveMaximumExceeded,
    .multipleOfInvalid => .multipleOfInvalid,
  };
}
