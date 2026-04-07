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
import 'package:schemantic_api/schemantic.dart' show SchemanticType;

export 'package:json_schema_builder/json_schema_builder.dart'
    show SchemaValidation;

export 'package:schemantic/src/flatten.dart' show SchemaFlatten;
export 'package:schemantic_api/schemantic.dart';

typedef $Schema = jsb.Schema;

/// Annotation to mark a class as a schema definition.
///
/// This annotation triggers the generation of a counterpart `Schema.g.dart`
/// file with a concrete implementation of the schema class and a type utility.
final class Schema {
  /// A description of the schema, to be included in the generated JSON Schema.
  final String? description;

  /// Whether to allow additional properties on the schema object.
  final bool? additionalProperties;

  const Schema({this.description, this.additionalProperties});
}

final class AnyOf {
  final List<Type> anyOf;

  const AnyOf(this.anyOf);
}

/// Annotation to customize valid JSON fields.
///
/// Use this annotation (or a subclass like [StringField], [IntegerField]) on a
/// getter
/// to specify a custom JSON key name, description, and other schema
/// constraints.
final class Field {
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
final class StringField extends Field {
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
final class IntegerField extends Field {
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
final class DoubleField extends Field {
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

extension ValidateSchemanticType on SchemanticType {
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
