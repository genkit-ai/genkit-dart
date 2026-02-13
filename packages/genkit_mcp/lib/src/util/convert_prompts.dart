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

import 'common.dart';
import 'convert_messages.dart';

List<Map<String, dynamic>>? toMcpPromptArguments(SchemanticType? schema) {
  if (schema == null) return null;
  final jsonSchema = schema.jsonSchema(useRefs: false).value;
  final schemaObject = extractObjectSchema(jsonSchema);
  if (schemaObject == null) {
    throw GenkitException(
      '[MCP Server] MCP prompts must take objects as input schema.',
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }

  final properties = schemaObject['properties'];
  if (properties is! Map) {
    throw GenkitException(
      '[MCP Server] MCP prompts must take objects as input schema.',
      status: StatusCodes.FAILED_PRECONDITION,
    );
  }

  final required =
      (schemaObject['required'] as List?)?.whereType<String>().toList() ?? [];
  final args = <Map<String, dynamic>>[];
  for (final entry in properties.entries) {
    final name = entry.key;
    if (name is! String) {
      throw GenkitException(
        '[MCP Server] MCP prompt arguments must use string keys.',
        status: StatusCodes.FAILED_PRECONDITION,
      );
    }
    final schemaMap = entry.value;
    if (schemaMap is! Map) {
      throw GenkitException(
        '[MCP Server] MCP prompts must take objects as input schema.',
        status: StatusCodes.FAILED_PRECONDITION,
      );
    }
    final schemaData = schemaMap.cast<String, dynamic>();
    if (!_allowsString(schemaData)) {
      throw GenkitException(
        '[MCP Server] MCP prompts may only take string arguments.',
        status: StatusCodes.FAILED_PRECONDITION,
      );
    }
    args.add({
      'name': name,
      if (schemaData['description'] != null)
        'description': schemaData['description'],
      'required': required.contains(name),
    });
  }
  return args;
}

List<Map<String, dynamic>> toMcpPromptMessages(List<Message> messages) {
  return messages.map(toMcpPromptMessage).toList();
}

bool _allowsString(Map<String, dynamic> schema) {
  final type = schema['type'];
  if (type is String) {
    return type == 'string';
  }
  if (type is List) {
    return type.contains('string');
  }
  return false;
}
