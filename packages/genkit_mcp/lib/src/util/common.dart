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

import 'package:schemantic/schemantic.dart';

/// Safely casts [value] to a `Map<String, dynamic>`.
///
/// Returns an empty map if the value is null or not a Map.
Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return <String, dynamic>{};
}

/// Safely casts [value] to a `List<Map<String, dynamic>>`.
///
/// Returns an empty list if the value is null or not a List.
List<Map<String, dynamic>> asListOfMaps(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
  return const [];
}

/// Extracts the MCP `_meta` field from a metadata map or raw MCP payload.
dynamic extractMcpMeta(Object? source) {
  if (source is Map && source['mcp'] is Map) {
    final mcp = source['mcp'];
    if (mcp is Map && mcp.containsKey('_meta')) {
      return mcp['_meta'];
    }
  }
  if (source is Map && source.containsKey('_meta')) {
    return source['_meta'];
  }
  return null;
}

/// Processes a raw MCP tool result into a more usable form.
///
/// Attempts to parse JSON text, return structured content, or return the
/// original result as-is depending on the content type.
dynamic processToolResult(Map<String, dynamic> result) {
  final content = asListOfMaps(result['content']);
  if (result['isError'] == true) {
    return {'error': _toText(content)};
  }
  if (content.isEmpty) return result;
  final allText = content.every((c) => c['text'] is String);
  if (allText) {
    final text = _toText(content);
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return jsonDecode(text);
      } catch (_) {
        return text;
      }
    }
    return text;
  }
  if (content.length == 1) return content.first;
  return result;
}

/// Concatenates text parts from a list of MCP content blocks.
String _toText(List<Map<String, dynamic>> content) {
  return content.map((part) => part['text']?.toString() ?? '').join();
}

/// Builds a [SchemanticType] from MCP prompt arguments.
SchemanticType<Map<String, dynamic>> promptSchemaFromArgs(
  List<Map<String, dynamic>> args,
) {
  if (args.isEmpty) {
    return .map(.string(), .dynamicSchema());
  }
  final properties = <String, dynamic>{};
  final required = <String>[];
  for (final arg in args) {
    final name = arg['name'];
    if (name is! String) continue;
    properties[name] = {
      'type': 'string',
      if (arg['description'] != null) 'description': arg['description'],
    };
    if (arg['required'] == true) required.add(name);
  }
  return PromptArgumentsSchema(properties: properties, required: required);
}

/// Creates a [SchemanticType] from a raw MCP tool `inputSchema` JSON object.
///
/// Falls back to `Map<String, dynamic>` if [inputSchema] is not a Map.
SchemanticType<Map<String, dynamic>> mcpToolInputSchemaFromJson(
  Object? inputSchema,
) {
  if (inputSchema is Map) {
    return McpToolInputSchema(inputSchema.cast<String, dynamic>());
  }
  return .map(.string(), .dynamicSchema());
}

/// A [SchemanticType] that wraps a raw JSON schema received from a remote
/// MCP server's tool definition.
///
/// This allows Genkit's registry to reflect the actual input schema that
/// the remote tool advertises, rather than an opaque `Map<String, dynamic>`.
class McpToolInputSchema extends SchemanticType<Map<String, dynamic>> {
  final Map<String, dynamic> _jsonSchema;

  const McpToolInputSchema(this._jsonSchema);

  @override
  Map<String, dynamic> parse(Object? json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return json.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap(_jsonSchema),
    dependencies: const [],
  );
}

/// A [SchemanticType] backed by a dynamic set of string properties.
///
/// Used to represent the input schema for MCP prompts whose arguments
/// are only known at runtime.
class PromptArgumentsSchema extends SchemanticType<Map<String, dynamic>> {
  final Map<String, dynamic> properties;
  final List<String> required;

  const PromptArgumentsSchema({
    required this.properties,
    required this.required,
  });

  @override
  Map<String, dynamic> parse(Object? json) {
    return json as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    }),
    dependencies: const [],
  );
}

/// Extracts an object schema from a JSON schema, handling `allOf` wrappers.
///
/// Returns the first sub-schema that has a `properties` key, or the schema
/// itself if it has one.
Map<String, dynamic>? extractObjectSchema(Object? schema) {
  if (schema is Map<String, dynamic>) {
    if (schema['type'] == 'object' || schema['properties'] is Map) {
      return schema;
    }
    if (schema['allOf'] is List) {
      for (final entry in schema['allOf'] as List) {
        final objectSchema = extractObjectSchema(entry);
        if (objectSchema != null) return objectSchema;
      }
    }
  }
  return null;
}
