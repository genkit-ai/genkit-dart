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

Map<String, dynamic> toJsonSchema({
  JsonExtensionType? type,
  Map<String, dynamic>? jsonSchema,
  bool useRefs = true,
}) {
  var result = Schema.any().value;
  if (jsonSchema != null) {
    result = jsonSchema;
  }

  if (type != null) {
    result = type.jsonSchema(useRefs: useRefs).value;
  }

  result['\$schema'] = 'http://json-schema.org/draft-07/schema#';

  return result;
}

/// Flattens a JSON schema by dereferencing all `$ref`s and removing `$defs`.
///
/// Throws [FormatException] if recursive references are detected.
Map<String, dynamic> flattenSchema(Map<String, dynamic> schema) {
  // 1. Identify definitions
  final defs = <String, Map<String, dynamic>>{};
  if (schema.containsKey('\$defs')) {
    final rawDefs = schema['\$defs'] as Map;
    rawDefs.forEach((k, v) {
      if (k is String && v is Map<String, dynamic>) {
        defs[k] = v;
      }
    });
  }
  // Also check for 'definitions' just in case, though $defs is preferred in newer drafts
  if (schema.containsKey('definitions')) {
    final rawDefs = schema['definitions'] as Map;
    rawDefs.forEach((k, v) {
      if (k is String && v is Map<String, dynamic>) {
        defs[k] = v;
      }
    });
  }

  // 2. Recursive flatten with cycle detection
  Map<String, dynamic> resolve(
    Map<String, dynamic> s,
    Set<String> visitedRefs,
  ) {
    if (s.containsKey('\$ref')) {
      final ref = s['\$ref'] as String;
      if (visitedRefs.contains(ref)) {
        throw FormatException('Circular reference detected: $ref');
      }

      // Parse ref (assuming local ref #/$defs/Name or #/definitions/Name)
      final parts = ref.split('/');
      if (parts.length < 3 || parts[0] != '#') {
        return s;
      }

      final defName = parts.last;
      final definition = defs[defName];
      if (definition == null) {
        throw FormatException('Reference not found: $ref');
      }

      final newVisited = Set<String>.from(visitedRefs)..add(ref);
      return resolve(definition, newVisited);
    }

    // Deep copy and recursive traverse children
    final result = <String, dynamic>{};
    for (final entry in s.entries) {
      if (entry.key == '\$defs' || entry.key == 'definitions') {
        continue; // Strip definitions
      }

      final value = entry.value;
      if (value is Map<String, dynamic>) {
        result[entry.key] = resolve(value, visitedRefs);
      } else if (value is List) {
        result[entry.key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return resolve(item, visitedRefs);
          }
          return item;
        }).toList();
      } else {
        result[entry.key] = value;
      }
    }
    return result;
  }

  return resolve(schema, {});
}
