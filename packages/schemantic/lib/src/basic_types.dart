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
import '../schemantic.dart';

/// A string schema.
///
/// Example:
/// ```dart
/// stringSchema().parse('hello');
/// ```
SchemanticType<String> stringSchema({
  String? description,
  int? minLength,
  int? maxLength,
  String? pattern,
  String? format,
  List<String>? enumValues,
  String? defaultValue,
}) {
  return _StringSchemaFactory(
    description: description,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
    enumValues: enumValues,
    defaultValue: defaultValue,
  );
}

class _StringSchemaFactory extends SchemanticType<String> {
  final String? description;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final List<String>? enumValues;
  final String? defaultValue;

const _StringSchemaFactory({
    this.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.enumValues,
    this.defaultValue,
  });

  @override
  String parse(Object? json) => json as String;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'string',
      if (description != null) 'description': description,
      if (minLength != null) 'minLength': minLength,
      if (maxLength != null) 'maxLength': maxLength,
      if (pattern != null) 'pattern': pattern,
      if (format != null) 'format': format,
      if (enumValues != null) 'enum': enumValues,
      if (defaultValue != null) 'default': defaultValue,
    });
  }
}

/// An integer schema.
///
/// Example:
/// ```dart
/// intSchema().parse(123);
/// ```

SchemanticType<int> intSchema({
  String? description,
  int? minimum,
  int? maximum,
  int? exclusiveMinimum,
  int? exclusiveMaximum,
  int? multipleOf,
  int? defaultValue,
}) {
  return _IntSchemaFactory(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
    defaultValue: defaultValue,
  );
}

class _IntSchemaFactory extends SchemanticType<int> {
  final String? description;
  final int? minimum;
  final int? maximum;
  final int? exclusiveMinimum;
  final int? exclusiveMaximum;
  final int? multipleOf;
  final int? defaultValue;

  const _IntSchemaFactory({
    this.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    this.defaultValue,
  });

  @override
  int parse(Object? json) => json as int;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'integer',
      if (description != null) 'description': description,
      if (minimum != null) 'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
      if (exclusiveMinimum != null) 'exclusiveMinimum': exclusiveMinimum,
      if (exclusiveMaximum != null) 'exclusiveMaximum': exclusiveMaximum,
      if (multipleOf != null) 'multipleOf': multipleOf,
      if (defaultValue != null) 'default': defaultValue,
    });
  }
}

/// A double schema.
///
/// Example:
/// ```dart
/// doubleSchema().parse(12.34);
/// ```

SchemanticType<double> doubleSchema({
  String? description,
  double? minimum,
  double? maximum,
  double? exclusiveMinimum,
  double? exclusiveMaximum,
  double? multipleOf,
  double? defaultValue,
}) {
  return _DoubleSchemaFactory(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
    defaultValue: defaultValue,
  );
}

class _DoubleSchemaFactory extends SchemanticType<double> {
  final String? description;
  final double? minimum;
  final double? maximum;
  final double? exclusiveMinimum;
  final double? exclusiveMaximum;
  final double? multipleOf;
  final double? defaultValue;

  const _DoubleSchemaFactory({
    this.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    this.defaultValue,
  });

  @override
  double parse(Object? json) {
    if (json is int) return json.toDouble();
    return json as double;
  }

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'number',
      if (description != null) 'description': description,
      if (minimum != null) 'minimum': minimum,
      if (maximum != null) 'maximum': maximum,
      if (exclusiveMinimum != null) 'exclusiveMinimum': exclusiveMinimum,
      if (exclusiveMaximum != null) 'exclusiveMaximum': exclusiveMaximum,
      if (multipleOf != null) 'multipleOf': multipleOf,
      if (defaultValue != null) 'default': defaultValue,
    });
  }
}

/// A boolean schema.
///
/// Example:
/// ```dart
/// boolSchema().parse(true);
/// ```
SchemanticType<bool> boolSchema({
  String? description,
  bool? defaultValue,
}) {
  return _BoolSchemaFactory(
    description: description,
    defaultValue: defaultValue,
  );
}

class _BoolSchemaFactory extends SchemanticType<bool> {
  final String? description;
  final bool? defaultValue;

  const _BoolSchemaFactory({this.description, this.defaultValue});

  @override
  bool parse(Object? json) => json as bool;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'boolean',
      if (description != null) 'description': description,
      if (defaultValue != null) 'default': defaultValue,
    });
  }
}

/// A void schema.
///
/// Example:
/// ```dart
/// voidSchema().parse(null);
/// ```
SchemanticType<void> voidSchema({String? description}) {
  return _VoidSchemaFactory(description: description);
}

class _VoidSchemaFactory extends SchemanticType<void> {
  final String? description;
  const _VoidSchemaFactory({this.description});
  @override
  void parse(Object? json) {}

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'null',
      if (description != null) 'description': description,
    });
  }
}

/// A dynamic schema.
///
/// Example:
/// ```dart
/// dynamicSchema().parse(anything);
/// ```
SchemanticType<dynamic> dynamicSchema({String? description}) {
  return _DynamicSchemaFactory(description: description);
}

class _DynamicSchemaFactory extends SchemanticType<dynamic> {
  final String? description;
  const _DynamicSchemaFactory({this.description});
  @override
  dynamic parse(Object? json) => json;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    // Empty schema allows anything
    return jsb.Schema.fromMap({
      if (description != null) 'description': description,
    });
  }
}

/// Creates a strongly typed List schema.
///
/// Example:
/// ```dart
/// final stringList = listSchema(stringSchema(), description: 'List of strings');
/// stringList.parse(['a', 'b']);
/// ```
SchemanticType<List<T>> listSchema<T>(
  SchemanticType<T> itemType, {
  String? description,
  int? minItems,
  int? maxItems,
  bool? uniqueItems,
}) {
  return _ListSchemaFactory<T>(
    itemType,
    description: description,
    minItems: minItems,
    maxItems: maxItems,
    uniqueItems: uniqueItems,
  );
}

class _ListSchemaFactory<T> extends SchemanticType<List<T>> {
  final SchemanticType<T> itemType;
  final String? description;
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  const _ListSchemaFactory(
    this.itemType, {
    this.description,
    this.minItems,
    this.maxItems,
    this.uniqueItems,
  });

  @override
  List<T> parse(Object? json) => (json as List).map(itemType.parse).toList();

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    final itemSchema = itemType.jsonSchema(useRefs: useRefs);
    var schema = jsb.Schema.list(
      items: itemSchema,
      description: description,
      minItems: minItems,
      maxItems: maxItems,
      uniqueItems: uniqueItems,
    );
    if (!useRefs) {
      return schema;
    }

    // Check if item schema has $defs or ref that implies definitions
    final itemJson = jsonDecode(itemSchema.toJson());
    if (itemJson is Map<String, dynamic> && itemJson.containsKey(r'$defs')) {
      final defs = itemJson.remove(r'$defs') as Map<String, dynamic>;

      return jsb.Schema.fromMap({
        'type': 'array',
        'items': itemJson,
        r'$defs': defs,
        if (description != null) 'description': description,
        if (minItems != null) 'minItems': minItems,
        if (maxItems != null) 'maxItems': maxItems,
        if (uniqueItems != null) 'uniqueItems': uniqueItems,
      });
    }

    return schema;
  }
}

/// Creates a strongly typed Map schema.
///
/// Example:
/// ```dart
/// final myMap = mapSchema(stringSchema(), intSchema(), description: 'My Map');
/// myMap.parse({'a': 1, 'b': 2});
/// ```
SchemanticType<Map<K, V>> mapSchema<K, V>(
  SchemanticType<K> keyType,
  SchemanticType<V> valueType, {
  String? description,
  int? minProperties,
  int? maxProperties,
}) {
  return _MapSchemaFactory<K, V>(
    keyType,
    valueType,
    description: description,
    minProperties: minProperties,
    maxProperties: maxProperties,
  );
}

class _MapSchemaFactory<K, V> extends SchemanticType<Map<K, V>> {
  final SchemanticType<K> keyType;
  final SchemanticType<V> valueType;
  final String? description;
  final int? minProperties;
  final int? maxProperties;

  const _MapSchemaFactory(
    this.keyType,
    this.valueType, {
    this.description,
    this.minProperties,
    this.maxProperties,
  });

  @override
  Map<K, V> parse(Object? json) {
    return (json as Map).map((k, v) {
      return MapEntry(keyType.parse(k), valueType.parse(v));
    });
  }

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    final valueSchema = valueType.jsonSchema(useRefs: useRefs);
    var schema = jsb.Schema.object(
      additionalProperties: valueSchema,
      description: description,
      minProperties: minProperties,
      maxProperties: maxProperties,
    );
    if (!useRefs) {
      return schema;
    }

    // Check if value schema has $defs or ref that implies definitions
    final valueJson = jsonDecode(valueSchema.toJson());
    if (valueJson is Map<String, dynamic> && valueJson.containsKey(r'$defs')) {
      final defs = valueJson.remove(r'$defs') as Map<String, dynamic>;

      return jsb.Schema.fromMap({
        'type': 'object',
        'additionalProperties': valueJson,
        r'$defs': defs,
        if (description != null) 'description': description,
        if (minProperties != null) 'minProperties': minProperties,
        if (maxProperties != null) 'maxProperties': maxProperties,
      });
    }

    return schema;
  }
}
