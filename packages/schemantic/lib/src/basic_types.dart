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

/// A string type.
///
/// Example:
/// ```dart
/// stringType().parse('hello');
/// ```
SchemanticType<String> stringType({
  String? description,
  int? minLength,
  int? maxLength,
  String? pattern,
  String? format,
  List<String>? enumValues,
}) {
  return _StringTypeFactory(
    description: description,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
    enumValues: enumValues,
  );
}

class _StringTypeFactory extends SchemanticType<String> {
  final String? description;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final List<String>? enumValues;

  const _StringTypeFactory({
    this.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.enumValues,
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
    });
  }
}

/// An integer type.
///
/// Example:
/// ```dart
/// intType().parse(123);
/// ```
SchemanticType<int> intType({
  String? description,
  int? minimum,
  int? maximum,
  int? exclusiveMinimum,
  int? exclusiveMaximum,
  int? multipleOf,
}) {
  return _IntTypeFactory(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
  );
}

class _IntTypeFactory extends SchemanticType<int> {
  final String? description;
  final int? minimum;
  final int? maximum;
  final int? exclusiveMinimum;
  final int? exclusiveMaximum;
  final int? multipleOf;

  const _IntTypeFactory({
    this.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
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
    });
  }
}

/// A double type.
///
/// Example:
/// ```dart
/// doubleType().parse(12.34);
/// ```
SchemanticType<double> doubleType({
  String? description,
  double? minimum,
  double? maximum,
  double? exclusiveMinimum,
  double? exclusiveMaximum,
  double? multipleOf,
}) {
  return _DoubleTypeFactory(
    description: description,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
    multipleOf: multipleOf,
  );
}

class _DoubleTypeFactory extends SchemanticType<double> {
  final String? description;
  final double? minimum;
  final double? maximum;
  final double? exclusiveMinimum;
  final double? exclusiveMaximum;
  final double? multipleOf;

  const _DoubleTypeFactory({
    this.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
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
    });
  }
}

/// A boolean type.
///
/// Example:
/// ```dart
/// boolType().parse(true);
/// ```
SchemanticType<bool> boolType({String? description}) {
  return _BoolTypeFactory(description: description);
}

class _BoolTypeFactory extends SchemanticType<bool> {
  final String? description;
  const _BoolTypeFactory({this.description});

  @override
  bool parse(Object? json) => json as bool;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) {
    return jsb.Schema.fromMap({
      'type': 'boolean',
      if (description != null) 'description': description,
    });
  }
}

/// A void type.
///
/// Example:
/// ```dart
/// voidType().parse(null);
/// ```
SchemanticType<void> voidType({String? description}) {
  return _VoidTypeFactory(description: description);
}

class _VoidTypeFactory extends SchemanticType<void> {
  final String? description;
  const _VoidTypeFactory({this.description});
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

/// A dynamic type.
///
/// Example:
/// ```dart
/// dynamicType().parse(anything);
/// ```
SchemanticType<dynamic> dynamicType({String? description}) {
  return _DynamicTypeFactory(description: description);
}

class _DynamicTypeFactory extends SchemanticType<dynamic> {
  final String? description;
  const _DynamicTypeFactory({this.description});
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

/// Creates a strongly typed List type schema.
///
/// Example:
/// ```dart
/// final stringList = listType(StringType, description: 'List of strings');
/// stringList.parse(['a', 'b']);
/// ```
SchemanticType<List<T>> listType<T>(
  SchemanticType<T> itemType, {
  String? description,
  int? minItems,
  int? maxItems,
  bool? uniqueItems,
}) {
  return _ListTypeFactory<T>(
    itemType,
    description: description,
    minItems: minItems,
    maxItems: maxItems,
    uniqueItems: uniqueItems,
  );
}

class _ListTypeFactory<T> extends SchemanticType<List<T>> {
  final SchemanticType<T> itemType;
  final String? description;
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  const _ListTypeFactory(
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

/// Creates a strongly typed Map type schema.
///
/// Example:
/// ```dart
/// final myMap = mapType(StringType, IntType, description: 'My Map');
/// myMap.parse({'a': 1, 'b': 2});
/// ```
SchemanticType<Map<K, V>> mapType<K, V>(
  SchemanticType<K> keyType,
  SchemanticType<V> valueType, {
  String? description,
  int? minProperties,
  int? maxProperties,
}) {
  return _MapTypeFactory<K, V>(
    keyType,
    valueType,
    description: description,
    minProperties: minProperties,
    maxProperties: maxProperties,
  );
}

class _MapTypeFactory<K, V> extends SchemanticType<Map<K, V>> {
  final SchemanticType<K> keyType;
  final SchemanticType<V> valueType;
  final String? description;
  final int? minProperties;
  final int? maxProperties;

  const _MapTypeFactory(
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
