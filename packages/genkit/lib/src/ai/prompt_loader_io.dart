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

import 'dart:io';

import 'package:dotprompt/dotprompt.dart' show Picoschema;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';

import '../core/registry.dart';
import '../types.dart' show GenerateActionOutputConfig;
import 'dotprompt_registry.dart';
import 'model.dart';
import 'prompt.dart';

final _logger = Logger('genkit.prompt_loader');

/// Loads all `.prompt` files from the given directory and registers them
/// as prompt actions.
///
/// Files starting with `_` are registered as partials.
/// Files with a dot in the name (e.g., `name.variant.prompt`) are
/// treated as variants.
///
/// This mirrors the JS `loadPromptFolder` function.
void loadPromptFolder(
  Registry registry,
  DotpromptRegistry dotpromptRegistry, {
  String dir = './prompts',
  String ns = '',
}) {
  final promptsPath = p.normalize(p.absolute(dir));
  final directory = Directory(promptsPath);
  if (directory.existsSync()) {
    _loadPromptFolderRecursively(
      registry,
      dotpromptRegistry,
      promptsPath,
      ns,
      '',
    );
  }
}

void _loadPromptFolderRecursively(
  Registry registry,
  DotpromptRegistry dotpromptRegistry,
  String basePath,
  String ns,
  String subDir,
) {
  final dirPath = subDir.isEmpty ? basePath : p.join(basePath, subDir);
  final directory = Directory(dirPath);
  final entities = directory.listSync();

  for (final entity in entities) {
    final fileName = p.basename(entity.path);

    if (entity is File && fileName.endsWith('.prompt')) {
      if (fileName.startsWith('_')) {
        // Partial: register with dotprompt
        final partialName = fileName.substring(1, fileName.length - 7);
        final content = entity.readAsStringSync();
        dotpromptRegistry.definePartial(partialName, content);
        _logger.fine(
          'Registered Dotprompt partial "$partialName" '
          'from "${entity.path}"',
        );
      } else {
        // Regular prompt: load and register
        _loadPrompt(
          registry,
          dotpromptRegistry,
          basePath,
          fileName,
          subDir,
          ns,
        );
      }
    } else if (entity is Directory) {
      // Recurse into subdirectories
      final childSubDir = subDir.isEmpty ? fileName : p.join(subDir, fileName);
      _loadPromptFolderRecursively(
        registry,
        dotpromptRegistry,
        basePath,
        ns,
        childSubDir,
      );
    }
  }
}

void _loadPrompt(
  Registry registry,
  DotpromptRegistry dotpromptRegistry,
  String basePath,
  String filename,
  String subDir,
  String ns,
) {
  // Parse name and variant from filename
  final prefix = subDir.isNotEmpty ? '$subDir/' : '';
  var name = '$prefix${p.basenameWithoutExtension(filename)}';
  String? variant;

  if (name.contains('.')) {
    final parts = name.split('.');
    name = parts[0];
    variant = parts[1];
  }

  final filePath = p.join(basePath, subDir, filename);
  final source = File(filePath).readAsStringSync();
  final parsedPrompt = dotpromptRegistry.parse(source);

  // Build the registry key
  final registryName = _registryDefinitionKey(name, variant, ns);

  // Extract metadata from the parsed prompt
  final metadata = parsedPrompt.metadata;

  // Determine model, tools, config from frontmatter
  final model = metadata.model;
  final config = metadata.config;
  final tools = metadata.tools;

  // Build the input schema from the frontmatter `input.schema`. The raw
  // metadata from `parse` is not schema-resolved, so Picoschema is converted
  // to JSON Schema here (mirroring what `renderMetadata` does internally).
  // Without this the action has no input schema, so the Developer UI shows no
  // input fields and input is never validated.
  final inputSchema = _toInputSchema(metadata.input?.schema);

  // Build output config from parsed metadata. As with the input schema, the
  // output schema may be Picoschema and must be converted to JSON Schema
  // before it reaches the model, otherwise the raw Picoschema is sent as the
  // response schema and the request fails or is ignored.
  GenerateActionOutputConfig? outputConfig;
  if (metadata.output != null) {
    final outputSchema = _toJsonSchema(metadata.output!.schema);
    outputConfig = GenerateActionOutputConfig.fromJson({
      'format': ?metadata.output!.format,
      'jsonSchema': ?outputSchema,
    });
  }

  // Build prompt metadata for the registry
  final promptMeta = <String, dynamic>{
    'type': 'prompt',
    'prompt': {
      'name': name,
      'variant': ?variant,
      'model': ?model,
      'config': ?config,
      'tools': ?tools,
      'template': parsedPrompt.template,
    },
  };

  // Create the prompt config
  final promptConfig = PromptConfig<Map<String, dynamic>, Map<String, dynamic>>(
    name: _registryDefinitionKey(name, null, ns),
    variant: variant,
    model: model != null ? modelRef(model) : null,
    config: config,
    inputSchema: inputSchema,
    toolNames: tools,
    messagesTemplate: parsedPrompt.template,
    output: outputConfig,
    metadata: promptMeta,
  );

  definePromptAction<Map<String, dynamic>, Map<String, dynamic>>(
    registry,
    dotpromptRegistry,
    promptConfig,
    metadata: promptMeta,
  );

  _logger.fine('Registered prompt "$registryName" from "$filePath"');
}

String _registryDefinitionKey(String name, String? variant, String? ns) {
  final prefix = ns != null && ns.isNotEmpty ? '$ns/' : '';
  final suffix = variant != null ? '.$variant' : '';
  return '$prefix$name$suffix';
}

/// Converts a frontmatter schema map to a JSON Schema map.
///
/// A `.prompt` file may declare its schema as Picoschema (the compact form
/// shown in the docs) or as plain JSON Schema. `parse` leaves Picoschema
/// untouched, so it is converted here; values that are already JSON Schema are
/// returned unchanged. Returns `null` when there is no schema.
///
/// This intentionally does not gate on [Picoschema.isPicoschema], which does
/// not recognize the `type, description` form (e.g. `name: string, the person
/// to greet`) that the docs and examples use. [_isJsonSchema] is used instead
/// so that form is converted rather than passed through raw.
Map<String, dynamic>? _toJsonSchema(Map<String, dynamic>? schema) {
  if (schema == null) return null;
  if (_isJsonSchema(schema)) return schema;
  return Picoschema.toJsonSchema(schema);
}

/// Whether [schema] is already a JSON Schema (as opposed to Picoschema).
///
/// JSON Schema carries a top-level `type` (one of the standard types) or a
/// `$schema`/`$ref`/`$defs` key. Picoschema maps field names to type strings
/// or nested maps and has none of these at the top level.
bool _isJsonSchema(Map<String, dynamic> schema) {
  if (schema.containsKey(r'$schema') ||
      schema.containsKey(r'$ref') ||
      schema.containsKey(r'$defs')) {
    return true;
  }
  const jsonSchemaTypes = {
    'object',
    'array',
    'string',
    'number',
    'integer',
    'boolean',
    'null',
  };
  return jsonSchemaTypes.contains(schema['type']);
}

/// Builds a [SchemanticType] for a prompt's input from its frontmatter
/// `input.schema`, converting Picoschema to JSON Schema as needed.
///
/// Returns `null` when no input schema is declared, in which case the prompt
/// accepts free-form input as before.
SchemanticType<Map<String, dynamic>>? _toInputSchema(
  Map<String, dynamic>? schema,
) {
  final jsonSchema = _toJsonSchema(schema);
  if (jsonSchema == null) return null;
  return SchemanticType.from<Map<String, dynamic>>(
    jsonSchema: jsonSchema,
    parse: (json) => (json as Map).cast<String, dynamic>(),
  );
}
