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
import '../exception.dart';
import '../types.dart' show GenerateActionOutputConfig, ToolChoice;
import 'dotprompt_registry.dart';
import 'generate_middleware.dart';
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

  // Resolve fields that are not first-class dotprompt metadata (`use`,
  // `toolChoice`, `maxTurns`, `returnToolRequests`) from the raw frontmatter
  // map. They are threaded through `PromptConfig` so they apply at generate
  // time (and, where applicable, surface on the prompt metadata built by
  // `definePromptAction`), matching the JS loader. A value of the wrong type is
  // an authoring error in a static file, so it fails fast with a clear message
  // at load time rather than being silently ignored or surfacing later as an
  // obscure downstream error.
  final use = _toMiddlewareRefs(metadata.raw?['use']);
  final toolChoice = _typedRawField<String>(
    metadata.raw,
    'toolChoice',
    registryName,
  );
  final maxTurns = _typedRawField<int>(metadata.raw, 'maxTurns', registryName);
  final returnToolRequests = _typedRawField<bool>(
    metadata.raw,
    'returnToolRequests',
    registryName,
  );

  // The raw metadata from `parse` is not schema-resolved, so Picoschema is
  // converted to JSON Schema here. Conversion is deferred to each use: the
  // schemas may name types registered with `defineSchema`, which can only run
  // after the `Genkit` constructor (and so this loader) has returned.
  final inputSchema = _frontmatterSchema(
    metadata.input?.schema,
    registry,
    registryName,
  );

  // Without a JSON Schema the raw Picoschema would be sent to the model as
  // the response schema, and the request would fail or be ignored.
  GenerateActionOutputConfig? outputConfig;
  Map<String, dynamic> Function()? deferredOutputJsonSchema;
  if (metadata.output != null) {
    final schema = metadata.output!.schema;
    final isPicoschema = schema != null && !_isJsonSchema(schema);
    if (isPicoschema) {
      deferredOutputJsonSchema = _FrontmatterSchema(
        schema,
        registry,
        registryName,
      ).resolveForModel;
    }
    outputConfig = GenerateActionOutputConfig.fromJson({
      'format': ?metadata.output!.format,
      if (!isPicoschema) 'jsonSchema': ?schema,
    });
  }

  // Create the prompt config. `definePromptAction` builds the registry/display
  // metadata (`type`, `prompt`) from these fields, so `use`/`toolChoice` are
  // surfaced for the Developer UI without building the metadata map here.
  // Output is `dynamic`: the frontmatter gives a JSON schema (carried on
  // `output`, and sent to the model) but no Dart type to parse into.
  // `ai.prompt<I, O>(name, outputParserSchema: ...)` supplies the parser at
  // lookup.
  final promptConfig =
      PromptConfig<Map<String, dynamic>, dynamic, Map<String, dynamic>>(
        name: _registryDefinitionKey(name, null, ns),
        variant: variant,
        model: model != null ? modelRef(model) : null,
        config: config,
        inputSchema: inputSchema,
        toolNames: tools,
        toolChoice: toolChoice == null ? null : ToolChoice(toolChoice),
        maxTurns: maxTurns,
        returnToolRequests: returnToolRequests,
        messagesTemplate: parsedPrompt.template,
        output: outputConfig,
        deferredOutputJsonSchema: deferredOutputJsonSchema,
        use: use,
      );

  definePromptAction(registry, dotpromptRegistry, promptConfig);

  _logger.fine('Registered prompt "$registryName" from "$filePath"');
}

String _registryDefinitionKey(String name, String? variant, String? ns) {
  final prefix = ns != null && ns.isNotEmpty ? '$ns/' : '';
  final suffix = variant != null ? '.$variant' : '';
  return '$prefix$name$suffix';
}

/// Reads a scalar frontmatter field of type [T] from the raw metadata map.
///
/// Returns `null` when the field is absent. A present value of the wrong type
/// is an authoring error in a static prompt file, so it throws a
/// [GenkitException] with a clear message at load time rather than silently
/// ignoring the value or letting it fail obscurely downstream.
T? _typedRawField<T>(Map<String, dynamic>? raw, String key, String promptName) {
  final value = raw?[key];
  if (value == null) return null;
  if (value is T) return value;
  throw GenkitException(
    "Invalid '$key' in prompt '$promptName': expected $T, got "
    '${value.runtimeType}.',
    status: StatusCode.invalidArgument,
  );
}

/// Normalizes the frontmatter `use` field into a list of middleware refs.
///
/// dotprompt does not model `use` as a first-class field, so it arrives as a
/// raw value from the parsed frontmatter. Two entry shapes are supported,
/// mirroring the code API where `use: [retry(maxRetries: 3)]` is a middleware
/// name plus optional config:
///
/// ```yaml
/// use:
///   - retry                 # bare string -> middlewareRef(name: 'retry')
///   - name: retry           # map with optional config
///     config:
///       maxRetries: 3
/// ```
///
/// Malformed entries (non-string / map without a `name`) are skipped rather
/// than throwing, consistent with the loader's tolerant handling of
/// frontmatter. Returns `null` when no valid middleware is declared.
List<GenerateMiddlewareRef>? _toMiddlewareRefs(dynamic use) {
  if (use is! List) return null;

  final refs = <GenerateMiddlewareRef>[];
  for (final entry in use) {
    if (entry is String) {
      refs.add(middlewareRef(name: entry));
    } else if (entry is Map) {
      final name = entry['name'];
      if (name is! String) {
        _logger.warning(
          'Skipping middleware entry without a valid "name": $entry',
        );
        continue;
      }
      final config = entry['config'];
      refs.add(
        middlewareRef<dynamic>(
          name: name,
          config: config is Map ? Map<String, dynamic>.from(config) : config,
        ),
      );
    } else {
      _logger.warning('Skipping unsupported middleware entry: $entry');
    }
  }

  return refs.isEmpty ? null : refs;
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
///
/// Named types (`schema: Recipe`, `address: Address`) are looked up among the
/// schemas registered with `defineSchema` each time the schema is used, until
/// they all resolve. See [_FrontmatterSchema].
SchemanticType<Map<String, dynamic>>? _frontmatterSchema(
  Map<String, dynamic>? schema,
  Registry registry,
  String promptName,
) {
  if (schema == null) return null;
  if (_isJsonSchema(schema)) {
    return SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: schema,
      parse: _parseInput,
    );
  }
  return _FrontmatterSchema(schema, registry, promptName);
}

// `parse` is also called with `null` when a prompt is invoked with no input,
// so guard the cast instead of letting it throw.
Map<String, dynamic> _parseInput(Object? json) =>
    json is Map ? json.cast<String, dynamic>() : <String, dynamic>{};

/// A Picoschema frontmatter schema, converted to JSON Schema on use.
///
/// Prompt folders are loaded by the `Genkit` constructor, before app code can
/// call `defineSchema`, so names can't be resolved at load time. Instead they
/// are looked up in the registry on each use, and the result is cached once
/// every name has resolved.
final class _FrontmatterSchema extends SchemanticType<Map<String, dynamic>> {
  _FrontmatterSchema(this._picoschema, this._registry, this._promptName);

  final Map<String, dynamic> _picoschema;
  final Registry _registry;
  final String _promptName;
  Map<String, dynamic>? _resolved;

  /// Converts the schema with the currently registered names. Names that are
  /// not registered yet come back as Picoschema's placeholder `{$ref: Name}`.
  (Map<String, dynamic>, Set<String> unresolved) _convert() {
    final cached = _resolved;
    if (cached != null) return (cached, const {});
    // `listValues` keys are registry paths (`/schema/<name>`); Picoschema
    // looks schemas up by bare name.
    final schemas = {
      for (final entry
          in _registry.listValues<Map<String, dynamic>>('schema').entries)
        entry.key.split('/').last: entry.value,
    };
    final converted = Picoschema.toJsonSchema(_picoschema, schemas: schemas);
    final unresolved = _unresolvedNames(converted);
    if (unresolved.isEmpty) _resolved = converted;
    return (converted, unresolved);
  }

  /// The JSON schema for the model. Throws instead of sending a dangling
  /// `$ref` the provider can't resolve.
  Map<String, dynamic> resolveForModel() {
    final (schema, unresolved) = _convert();
    if (unresolved.isNotEmpty) {
      final names = unresolved.map((n) => "'$n'").join(', ');
      throw GenkitException(
        'Schema $names referenced by prompt \'$_promptName\' '
        '${unresolved.length == 1 ? 'is' : 'are'} not defined. Register '
        'it with ai.defineSchema before calling the prompt.',
        status: StatusCode.failedPrecondition,
      );
    }
    return Map.of(schema);
  }

  /// For action metadata (the Dev UI input form). Never throws: a name that
  /// is not registered yet is left as a `$ref`.
  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      Map.of(_convert().$1);

  @override
  Map<String, dynamic> parse(Object? json) => _parseInput(json);
}

/// Names Picoschema could not resolve. It emits them as `{$ref: Name}`, while
/// real JSON Schema references are URIs (`#/$defs/...`, `https://...`).
Set<String> _unresolvedNames(Object? schema) {
  final names = <String>{};
  void visit(Object? node) {
    if (node is Map) {
      final ref = node[r'$ref'];
      if (ref is String && !ref.contains('#') && !ref.contains('/')) {
        names.add(ref);
      }
      node.values.forEach(visit);
    } else if (node is List) {
      node.forEach(visit);
    }
  }

  visit(schema);
  return names;
}

/// Whether [schema] is already a JSON Schema (as opposed to Picoschema).
///
/// JSON Schema carries a top-level `type` (one of the standard types), a
/// `$schema`/`$ref`/`$defs` key, or a structural keyword such as `properties`,
/// `items`, or a `*Of` combinator. (The top-level `type` is optional in JSON
/// Schema, so the structural keywords are needed to catch schemas that omit
/// it.) Picoschema maps field names to type strings or nested maps and has
/// none of these at the top level.
bool _isJsonSchema(Map<String, dynamic> schema) {
  const jsonSchemaKeywords = {
    r'$schema',
    r'$ref',
    r'$defs',
    'properties',
    'items',
    'anyOf',
    'oneOf',
    'allOf',
  };
  if (jsonSchemaKeywords.any(schema.containsKey)) {
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
