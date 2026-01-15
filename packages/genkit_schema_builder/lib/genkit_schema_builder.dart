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

class GenkitSchema {
  const GenkitSchema();
}

class Key {
  final String? name;
  final String? description;

  const Key({this.name, this.description});
}

class JsonSchemaMetadata {
  final String? name;
  final jsb.Schema definition;
  final List<JsonExtensionType> dependencies;

  const JsonSchemaMetadata({
    this.name,
    required this.definition,
    this.dependencies = const [],
  });
}

abstract class JsonExtensionType<T> {
  const JsonExtensionType();
  T parse(Object json);

  // ignore: avoid_renaming_method_parameters
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
            'Failed to inline schema for ${schemaMetadata?.name}: $e');
      }
    }
    return SchemaHelpers.buildSchema(this);
  }

  JsonSchemaMetadata? get schemaMetadata => null;
}

class SchemaHelpers {
  static jsb.Schema buildSchema(JsonExtensionType root) {
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
        r'$defs':
            definitions.map((k, v) => MapEntry(k, jsonDecode(v.toJson()))),
      });
    }

    return jsb.Schema.fromMap({
      'allOf': [rootMeta.definition.toJson()],
      r'$defs': definitions.map((k, v) => MapEntry(k, jsonDecode(v.toJson()))),
    });
  }

  static void _collectDefinitions(
    JsonExtensionType node,
    Map<String, jsb.Schema> definitions,
    Set<JsonExtensionType> visited,
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
    List<JsonExtensionType> dependencies,
    Set<String> visited,
  ) {
    final json = jsonDecode(schema.toJson()) as Map<String, dynamic>;
    return _traverseAndInline(json, dependencies, visited);
  }

  static Map<String, dynamic> _traverseAndInline(
    Map<String, dynamic> json,
    List<JsonExtensionType> dependencies,
    Set<String> visited,
  ) {
    if (json.containsKey(r'$ref') ||
        json.containsKey('ref') ||
        json.containsKey(r'$ref')) {
      final ref = (json[r'$ref'] ?? json['ref'] ?? json[r'$ref']) as String;
      if (ref.startsWith('#/\$defs/')) {
        final name = ref.replaceFirst('#/\$defs/', '');
        if (visited.contains(name)) {
          throw StateError(
              'Recursive schema detected for $name without useRefs=true');
        }

        final dependency = dependencies.firstWhere(
          (d) => d.schemaMetadata?.name == name,
          orElse: () =>
              throw StateError('Dependency $name not found for inlining'),
        );

        final meta = dependency.schemaMetadata!;
        return _inlineSchema(
          meta.definition,
          meta.dependencies,
          {...visited, name},
        );
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
