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
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class StringTypeFactory extends JsonExtensionType<String> {
  const StringTypeFactory();

  @override
  String parse(Object json) => json as String;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.string();
}

// ignore: constant_identifier_names
const StringType = StringTypeFactory();

class IntTypeFactory extends JsonExtensionType<int> {
  const IntTypeFactory();

  @override
  int parse(Object json) => json as int;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.integer();
}

// ignore: constant_identifier_names
const IntType = IntTypeFactory();

class DoubleTypeFactory extends JsonExtensionType<double> {
  const DoubleTypeFactory();

  @override
  double parse(Object json) {
    if (json is int) return json.toDouble();
    return json as double;
  }

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.number();
}

// ignore: constant_identifier_names
const DoubleType = DoubleTypeFactory();

class BoolTypeFactory extends JsonExtensionType<bool> {
  const BoolTypeFactory();

  @override
  bool parse(Object json) => json as bool;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.boolean();
}

// ignore: constant_identifier_names
const BoolType = BoolTypeFactory();

class VoidTypeFactory extends JsonExtensionType<void> {
  const VoidTypeFactory();

  @override
  void parse(Object? json) {}

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.nil();
}

// ignore: constant_identifier_names
const VoidType = VoidTypeFactory();

class MapTypeFactory extends JsonExtensionType<Map<String, dynamic>> {
  const MapTypeFactory();

  @override
  Map<String, dynamic> parse(Object? json) => json as Map<String, dynamic>;

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) => jsb.Schema.object();
}

// ignore: constant_identifier_names
const MapType = MapTypeFactory();

JsonExtensionType<List<T>> listType<T>(JsonExtensionType<T> itemType) {
  return _ListTypeFactory<T>(itemType);
}

class _ListTypeFactory<T> extends JsonExtensionType<List<T>> {
  final JsonExtensionType<T> itemType;

  const _ListTypeFactory(this.itemType);

  @override
  List<T> parse(Object? json) =>
      (json as List).map((e) => itemType.parse(e)).toList();

  @override
  jsb.Schema jsonSchema({bool useRefs = false}) =>
      jsb.Schema.list(items: itemType.jsonSchema(useRefs: useRefs));
}
