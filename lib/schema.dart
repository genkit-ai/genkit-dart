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

export 'package:json_schema_builder/json_schema_builder.dart' show Schema;
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class GenkitSchema {
  const GenkitSchema();
}

class Key {
  final String? name;
  final String? description;

  const Key({this.name, this.description});
}

abstract class JsonExtensionType<T> {
  const JsonExtensionType();
  T parse(Object json);
  jsb.Schema get jsonSchema;
}

class StringTypeFactory implements JsonExtensionType<String> {
  const StringTypeFactory();

  @override
  String parse(Object json) => json as String;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.string();
}

// ignore: constant_identifier_names
const StringType = StringTypeFactory();

class IntTypeFactory implements JsonExtensionType<int> {
  const IntTypeFactory();

  @override
  int parse(Object json) => json as int;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.integer();
}

// ignore: constant_identifier_names
const IntType = IntTypeFactory();

class DoubleTypeFactory implements JsonExtensionType<double> {
  const DoubleTypeFactory();

  @override
  double parse(Object json) {
    if (json is int) return json.toDouble();
    return json as double;
  }

  @override
  jsb.Schema get jsonSchema => jsb.Schema.number();
}

// ignore: constant_identifier_names
const DoubleType = DoubleTypeFactory();

class BoolTypeFactory implements JsonExtensionType<bool> {
  const BoolTypeFactory();

  @override
  bool parse(Object json) => json as bool;

  @override
  jsb.Schema get jsonSchema => jsb.Schema.boolean();
}

// ignore: constant_identifier_names
const BoolType = BoolTypeFactory();

class VoidTypeFactory implements JsonExtensionType<void> {
  const VoidTypeFactory();

  @override
  void parse(Object? json) {}

  @override
  jsb.Schema get jsonSchema => jsb.Schema.nil();
}

// ignore: constant_identifier_names
const VoidType = VoidTypeFactory();
