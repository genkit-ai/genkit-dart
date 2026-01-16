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

import 'package:schemantic/schemantic.dart';
import 'dart:convert';
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class _StringTypeFactory extends JsonExtensionType<String> {
  const _StringTypeFactory();

  @override
  String parse(Object json) => json as String;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.string();
}

/// A string type.
///
/// Example:
/// ```dart
/// StringType.parse('hello');
/// ```
// ignore: constant_identifier_names
const StringType = _StringTypeFactory();

class _IntTypeFactory extends JsonExtensionType<int> {
  const _IntTypeFactory();

  @override
  int parse(Object json) => json as int;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.integer();
}

/// An integer type.
///
/// Example:
/// ```dart
/// IntType.parse(123);
/// ```
// ignore: constant_identifier_names
const IntType = _IntTypeFactory();

class _DoubleTypeFactory extends JsonExtensionType<double> {
  const _DoubleTypeFactory();

  @override
  double parse(Object json) {
    if (json is int) return json.toDouble();
    return json as double;
  }

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.number();
}

/// A double type.
///
/// Example:
/// ```dart
/// DoubleType.parse(12.34);
/// ```
// ignore: constant_identifier_names
const DoubleType = _DoubleTypeFactory();

class _BoolTypeFactory extends JsonExtensionType<bool> {
  const _BoolTypeFactory();

  @override
  bool parse(Object json) => json as bool;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.boolean();
}

/// A boolean type.
///
/// Example:
/// ```dart
/// BoolType.parse(true);
/// ```
// ignore: constant_identifier_names
const BoolType = _BoolTypeFactory();

class _VoidTypeFactory extends JsonExtensionType<void> {
  const _VoidTypeFactory();

  @override
  void parse(Object? json) {}

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.nil();
}

/// A void type, representing null in JSON.
///
/// Example:
/// ```dart
/// VoidType.parse(null);
// ignore: constant_identifier_names
const VoidType = _VoidTypeFactory();

/// A dynamic type, representing any JSON value.
///
/// Example:
/// ```dart
/// DynamicType.parse(123);
/// DynamicType.parse('hello');
/// ```
class _DynamicTypeFactory extends JsonExtensionType<dynamic> {
  const _DynamicTypeFactory();

  @override
  dynamic parse(Object? json) => json;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.any();
}

// ignore: constant_identifier_names
const DynamicType = _DynamicTypeFactory();

class _BasicMapTypeFactory extends JsonExtensionType<Map<String, dynamic>> {
  const _BasicMapTypeFactory();

  @override
  Map<String, dynamic> parse(Object json) => json as Map<String, dynamic>;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.object();
}

/// A simplified Map type for Map<String, dynamic>.
///
/// Example:
/// ```dart
/// MapType.parse({'key': 'value'});
/// ```
// ignore: constant_identifier_names
const MapType = _BasicMapTypeFactory();

/// Creates a strongly typed List type schema.
///
/// Example:
/// ```dart
/// final stringList = listType(StringType, description: 'List of strings');
/// stringList.parse(['a', 'b']);
/// ```
JsonExtensionType<List<T>> listType<T>(
  JsonExtensionType<T> itemType, {
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

class _ListTypeFactory<T> extends JsonExtensionType<List<T>> {
  final JsonExtensionType<T> itemType;
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
  List<T> parse(Object json) =>
      (json as List).map((e) => itemType.parse(e)).toList();

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
JsonExtensionType<Map<K, V>> mapType<K, V>(
  JsonExtensionType<K> keyType,
  JsonExtensionType<V> valueType, {
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

class _MapTypeFactory<K, V> extends JsonExtensionType<Map<K, V>> {
  final JsonExtensionType<K> keyType;
  final JsonExtensionType<V> valueType;
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
  Map<K, V> parse(Object json) {
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
