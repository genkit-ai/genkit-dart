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

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

Map<String, dynamic> toMcpTool(Tool tool) {
  final meta = _extractMcpMeta(tool.metadata);
  final metaEntry = meta == null ? null : {'_meta': meta};
  final annotations = _extractMcpAnnotations(tool.metadata);
  // Allow per-tool override via metadata; default to 'optional' so that
  // task-augmented requests are accepted by the server.
  final execution =
      _extractMcpExecution(tool.metadata) ?? const {'taskSupport': 'optional'};
  return {
    'name': tool.name,
    'description': tool.description ?? '',
    'inputSchema':
        _toJsonSchema(tool.inputSchema) ??
        {
          r'$schema': 'http://json-schema.org/draft-07/schema#',
          'type': 'object',
        },
    if (tool.outputSchema != null)
      'outputSchema': _toJsonSchema(tool.outputSchema),
    'execution': execution,
    'annotations': ?annotations,
    ...?metaEntry,
  };
}

Map<String, dynamic>? _toJsonSchema(SchemanticType? type) {
  if (type == null) return null;
  final schema = type.jsonSchema(useRefs: true).value;
  schema[r'$schema'] = 'http://json-schema.org/draft-07/schema#';
  return schema;
}

dynamic _extractMcpMeta(Map<String, dynamic> metadata) {
  final mcp = metadata['mcp'];
  if (mcp is Map && mcp.containsKey('_meta')) {
    return mcp['_meta'];
  }
  return null;
}

Map<String, dynamic>? _extractMcpAnnotations(Map<String, dynamic> metadata) {
  final mcp = metadata['mcp'];
  if (mcp is Map && mcp['annotations'] is Map) {
    return (mcp['annotations'] as Map).cast<String, dynamic>();
  }
  return null;
}

Map<String, dynamic>? _extractMcpExecution(Map<String, dynamic> metadata) {
  final mcp = metadata['mcp'];
  if (mcp is Map && mcp['execution'] is Map) {
    return (mcp['execution'] as Map).cast<String, dynamic>();
  }
  return null;
}
