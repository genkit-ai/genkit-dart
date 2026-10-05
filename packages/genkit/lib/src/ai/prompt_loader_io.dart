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

import 'dart:collection';
import 'dart:io';

import 'package:dotprompt/dotprompt.dart' show Picoschema, PicoschemaException;
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
    final isPicoschema = schema != null && Picoschema.isPicoschema(schema);
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
/// JSON Schema is detected by [Picoschema.isPicoschema], like in JS and
/// Python: it needs a top-level `type` or `properties` (or `$ref`, `$schema`,
/// `anyOf`/`oneOf`/`allOf`/`enum`). A bare `items` or `$defs` is not enough,
/// since `{items: string, total: number}` is a valid Picoschema object.
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
  if (!Picoschema.isPicoschema(schema)) {
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
///
/// Invalid Picoschema (e.g. `tags(list): string`) is logged when the prompt is
/// loaded and thrown when the prompt is rendered, like an undefined name. It
/// is not thrown at load because that would stop `Genkit(promptDir:)` and
/// every unrelated flow and prompt with it (JS also fails only that prompt).
final class _FrontmatterSchema extends SchemanticType<Map<String, dynamic>>
    implements DeferredSchema {
  _FrontmatterSchema(this._picoschema, this._registry, this._promptName) {
    try {
      _last = _convertNow();
    } on GenkitException catch (e) {
      _invalid = e;
      _logger.warning(e.message);
    }
  }

  final Map<String, dynamic> _picoschema;
  final Registry _registry;
  final String _promptName;

  /// Set when the schema is not valid Picoschema. That doesn't depend on
  /// what is registered, so it is final.
  GenkitException? _invalid;

  /// The latest conversion and the names it could not resolve. Reused until
  /// one of those names is registered, so a name that is never defined
  /// doesn't cost a full conversion on every use.
  (Map<String, dynamic>, Set<String> missing)? _last;

  (Map<String, dynamic>, Set<String> missing) _convertNow() {
    final schemas = _RegistrySchemas(_registry);
    try {
      final converted = Picoschema.toJsonSchema(_picoschema, schemas: schemas);
      return (converted, schemas.missing);
    } on PicoschemaException catch (e) {
      throw GenkitException(
        "Invalid schema in prompt '$_promptName': ${_describe(e)}",
        status: StatusCode.invalidArgument,
        cause: e,
      );
    }
  }

  /// Converts the schema with the currently registered names, returning the
  /// names that are not registered (yet). Those convert to an empty schema.
  ///
  /// Throws the load-time [GenkitException] for invalid Picoschema.
  (Map<String, dynamic>, Set<String> missing) _convert() {
    if (_invalid case final invalid?) throw invalid;
    final last = _last!;
    final nowRegistered = last.$2.any(
      (name) =>
          _registry.lookupValue<Map<String, dynamic>>('schema', name) != null,
    );
    return nowRegistered ? _last = _convertNow() : last;
  }

  /// The JSON schema for the model. Throws instead of sending a schema with
  /// a hole where an undefined name was.
  Map<String, dynamic> resolveForModel() {
    final (schema, missing) = _convert();
    if (missing.isNotEmpty) {
      final names = missing.map((n) => "'$n'").join(', ');
      final plural = missing.length > 1;
      throw GenkitException(
        'Unknown type${plural ? 's' : ''} $names in prompt \'$_promptName\'. '
        'Use a Picoschema scalar type (string, number, integer, boolean, '
        'null, any) or register the schema with ai.defineSchema before '
        'calling the prompt.',
        status: StatusCode.failedPrecondition,
      );
    }
    return Map.of(schema);
  }

  @override
  void ensureResolved() => resolveForModel();

  /// For action metadata (the Dev UI input form). Never throws: a name that
  /// is not registered yet is left as an empty (any) schema, and so is the
  /// whole schema when it is invalid.
  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) =>
      _invalid != null ? <String, Object?>{} : Map.of(_convert().$1);

  @override
  Map<String, dynamic> parse(Object? json) => _parseInput(json);
}

/// The message of a Picoschema error, without dotprompt's `Picoschema: `
/// prefix (the caller already names the prompt).
///
/// The old Dart-only `name(description): type` form now fails as a bad
/// parenthetical type, the most likely error after the dotprompt 2.0
/// upgrade, so that message also says where descriptions go.
String _describe(PicoschemaException e) {
  const prefix = 'Picoschema: ';
  final message = e.message.startsWith(prefix)
      ? e.message.substring(prefix.length)
      : e.message;
  if (!message.contains('parenthetical types')) return message;
  return '$message. Descriptions go after a comma, as in '
      '`email: string, the email` or `tags(array, the tags): string`.';
}

/// The `schemas` lookup handed to [Picoschema.toJsonSchema], backed by the
/// registry's `defineSchema` values (including parent registries).
///
/// Picoschema throws on the first unknown name. Answering every lookup
/// instead (with an empty schema, recording the name in [missing]) lets one
/// pass collect all missing names and still yield a usable schema for the
/// Dev UI. So `[]` answers for any name, while [keys] (and so `length`,
/// `containsKey` and iteration) reflect only the registered names. If a later
/// Picoschema copied this map instead of indexing it, registered names would
/// still resolve; only listing every missing name in one error would be lost.
final class _RegistrySchemas extends MapBase<String, Map<String, dynamic>> {
  _RegistrySchemas(this._registry);

  final Registry _registry;

  /// Names that were looked up but are not registered.
  final Set<String> missing = {};

  @override
  Map<String, dynamic>? operator [](Object? key) {
    if (key is! String) return null;
    final schema = _registry.lookupValue<Map<String, dynamic>>('schema', key);
    if (schema != null) return schema;
    missing.add(key);
    return const {};
  }

  // `listValues` keys are registry paths (`/schema/<name>`).
  @override
  Iterable<String> get keys => _registry
      .listValues<Map<String, dynamic>>('schema')
      .keys
      .map((path) => path.substring('/schema/'.length));

  @override
  void operator []=(String key, Map<String, dynamic> value) =>
      throw UnsupportedError('read-only');

  @override
  Map<String, dynamic>? remove(Object? key) =>
      throw UnsupportedError('read-only');

  @override
  void clear() => throw UnsupportedError('read-only');
}
