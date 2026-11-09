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

import 'dart:async';

import 'package:dotprompt/dotprompt.dart' as dp;
import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../core/cancellation.dart';
import '../core/registry.dart';
import '../exception.dart';
import '../o11y/instrumentation.dart';
import '../schema.dart';
import '../types.dart';
import 'dotprompt_registry.dart';
import 'generate.dart';
import 'generate_middleware.dart';
import 'generate_types.dart';
import 'model.dart';
import 'prompt_types.dart';
import 'tool.dart';

/// An input schema whose named types are resolved on use, set by the
/// `.prompt` loader. [Prompt.render] calls [ensureResolved] so an undefined
/// name fails the render instead of loosening the schema.
@internal
abstract interface class DeferredSchema {
  /// Throws a [GenkitException] if the schema is invalid or names a type
  /// that is still undefined.
  void ensureResolved();
}

/// Configuration for defining a prompt.
///
/// This holds all the metadata needed to define a prompt action.
final class PromptConfig<Input, Output, CustomOptions> {
  /// The name of the prompt.
  final String name;

  /// An optional variant identifier.
  final String? variant;

  /// The model to use.
  final ModelRef<CustomOptions>? model;

  /// Model configuration (temperature, etc.).
  final CustomOptions? config;

  /// A human-readable description.
  final String? description;

  /// Input schema for the prompt.
  final SchemanticType<Input>? inputSchema;

  /// System prompt as a Handlebars template string.
  final String? system;

  /// System prompt as literal parts.
  final List<Part>? systemParts;

  /// User prompt as a Handlebars template string.
  final String? prompt;

  /// User prompt as literal parts.
  final List<Part>? promptParts;

  /// Literal message history.
  final List<Message>? messages;

  /// Messages as a Handlebars template string (e.g. loaded from .prompt files).
  final String? messagesTemplate;

  /// Typed output schema. Supplies the request's JSON schema and parses
  /// `response.output` into [Output].
  ///
  /// Prompts loaded from `.prompt` files have a JSON schema but no Dart type,
  /// so they leave this null and carry the schema on [output] instead.
  final SchemanticType<Output>? outputSchema;

  /// Raw output configuration (`format`, `constrained`, `instructions`).
  ///
  /// This is the escape hatch for settings [outputSchema] does not cover, and
  /// the only way for a `.prompt` file to supply a JSON schema. When both set a
  /// `jsonSchema`, [outputSchema] wins and the constructor throws.
  final GenerateActionOutputConfig? output;

  /// Maximum number of tool-call turns.
  final int? maxTurns;

  /// Whether to return tool requests instead of executing them.
  final bool? returnToolRequests;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  /// Tools available to the prompt.
  final List<Tool>? tools;

  /// Tool names (for tools already registered in the registry).
  final List<String>? toolNames;

  /// Tool choice strategy.
  final ToolChoice? toolChoice;

  /// Middleware references.
  final List<GenerateMiddlewareRef>? use;

  /// Supplies [output]'s JSON schema at render time instead of up front.
  ///
  /// Set by the `.prompt` loader for Picoschema output schemas, which may name
  /// types registered with `defineSchema` after the prompt was loaded. Called
  /// on every render until it succeeds; throws when a name is still undefined.
  final Map<String, dynamic> Function()? deferredOutputJsonSchema;

  PromptConfig({
    required this.name,
    this.variant,
    this.model,
    this.config,
    this.description,
    this.inputSchema,
    this.system,
    this.systemParts,
    this.prompt,
    this.promptParts,
    this.messages,
    this.messagesTemplate,
    this.outputSchema,
    this.output,
    this.maxTurns,
    this.returnToolRequests,
    this.metadata,
    this.tools,
    this.toolNames,
    this.toolChoice,
    this.use,
    this.deferredOutputJsonSchema,
  }) {
    if (outputSchema != null && output?.jsonSchema != null) {
      throw ArgumentError(
        'Prompt "$name" sets a JSON schema on both outputSchema and output. '
        'Use outputSchema for the schema and output for format/constrained/'
        'instructions only.',
      );
    }
    final error = _outputTypeError<Output>(
      label: 'Prompt "$name"',
      config: this,
      hasParser: outputSchema != null,
    );
    if (error != null) throw ArgumentError(error);
  }

  /// Whether the model is asked for structured output, i.e. whether a
  /// formatter will parse the response into `output` at all.
  bool get _requestsStructuredOutput =>
      output?.format != null || _definesWireSchema;

  /// Whether the model is given an output schema. Known without resolving a
  /// deferred schema, so definition-time checks don't depend on what has been
  /// registered yet.
  bool get _definesWireSchema =>
      outputSchema != null ||
      output?.jsonSchema != null ||
      deferredOutputJsonSchema != null;

  /// Whether the prompt configures any output, i.e. whether [resolvedOutput]
  /// is non-null. Known without resolving a deferred schema.
  bool get _hasOutput => output != null || _definesWireSchema;

  /// The format [resolvedOutput] is parsed with (`_effectiveFormat` of it),
  /// known without resolving a deferred schema.
  String? get _outputFormat =>
      output?.format ?? (_definesWireSchema ? 'json' : null);

  /// The full name including variant.
  String get fullName => variant != null ? '$name.$variant' : name;

  /// The wire output config, with [outputSchema]'s (or the deferred) JSON
  /// schema folded in.
  ///
  /// Null when the prompt configures no output at all, so the rendered
  /// options stay free of an empty `output` block. Cached once resolved: the
  /// config is immutable and this is read on every render (and every agent
  /// turn). A deferred schema that fails to resolve is retried next time.
  GenerateActionOutputConfig? get resolvedOutput {
    // A throwing `_resolveOutput` leaves the flag unset, so it is retried.
    if (!_outputResolved) {
      _resolvedOutput = _resolveOutput();
      _outputResolved = true;
    }
    return _resolvedOutput;
  }

  GenerateActionOutputConfig? _resolvedOutput;
  bool _outputResolved = false;

  GenerateActionOutputConfig? _resolveOutput() {
    final jsonSchema = outputSchema != null
        ? toJsonSchema(type: outputSchema)
        : deferredOutputJsonSchema?.call();
    if (jsonSchema == null) return output;
    return GenerateActionOutputConfig.fromJson({
      ...?output?.toJson(),
      'jsonSchema': jsonSchema,
    });
  }
}

/// Per-call options passed to [Prompt.call], [Prompt.render] and
/// [Prompt.stream] as named parameters, bundled to thread them through the
/// rendering and generate steps. Not public: callers use the named parameters.
final class _CallOptions {
  final ModelRef<dynamic>? model;
  final Object? config;
  final List<Tool>? tools;
  final List<String>? toolNames;
  final ToolChoice? toolChoice;
  final bool? returnToolRequests;
  final int? maxTurns;
  final GenerateActionOutputConfig? output;
  final Map<String, dynamic>? context;
  final List<GenerateMiddlewareRef>? use;
  final List<Message>? messages;
  final CancellationToken? cancel;

  const _CallOptions({
    this.model,
    this.config,
    this.tools,
    this.toolNames,
    this.toolChoice,
    this.returnToolRequests,
    this.maxTurns,
    this.output,
    this.context,
    this.use,
    this.messages,
    this.cancel,
  });
}

/// Memoized compiled templates for one registered prompt.
///
/// Held separately from [Prompt] so the typed views produced by a
/// `prompt<Input, Output>()` lookup share one cache with the registered prompt
/// instead of recompiling per lookup. Futures (not values) are memoized so
/// concurrent first-renders await the same compile.
class _PromptTemplates {
  Future<dp.PromptFunction>? system;
  Future<dp.PromptFunction>? prompt;
  Future<dp.PromptFunction>? messages;
}

/// Identifies a defined prompt: its registered name and metadata.
///
/// Obtained from [Prompt.ref]; not constructed directly.
final class PromptRef {
  /// The full prompt name, including the variant (e.g. `greet.formal`).
  final String name;

  /// The prompt's registry metadata (`{'type': 'prompt', 'prompt': {...}}`).
  ///
  /// Read-only at every level.
  final Map<String, dynamic> metadata;

  PromptRef._(this.name, Map<String, dynamic> metadata)
    : metadata = _freeze(metadata) as Map<String, dynamic>;
}

/// A read-only copy of [value], all the way down. Copying (rather than
/// wrapping) also keeps callers' edits from reaching the prompt's own config,
/// e.g. its `toolNames` list. String-keyed maps stay `Map<String, dynamic>`
/// so callers can keep casting nested entries to that type.
Object? _freeze(Object? value) => switch (value) {
  Map<String, dynamic>() => Map<String, dynamic>.unmodifiable(
    value.map((k, v) => MapEntry(k, _freeze(v))),
  ),
  Map() => Map.unmodifiable(value.map((k, v) => MapEntry(k, _freeze(v)))),
  List() => List.unmodifiable(value.map(_freeze)),
  _ => value,
};

/// A defined prompt that can render, generate, and stream.
///
/// It acts as a callable that invokes `generate` with the rendered prompt
/// template, and also provides `.render()` and `.stream()` methods.
///
/// [Output] is the parsed structured output type: `(await prompt(input)).output`
/// is an `Output?`. It is inferred from `outputSchema` at definition, and is
/// `dynamic` for a prompt defined without one.
final class Prompt<Input, Output> {
  /// A reference to the prompt (name + metadata).
  final PromptRef ref;

  final Registry _registry;
  final DotpromptRegistry _dotpromptRegistry;

  // Fully erased: rendering only reads the template/model/tool fields, never
  // the schemas, so the config's own type arguments are irrelevant here. This
  // also lets `_retyped` rebuild the view over any Input/Output pair.
  final PromptConfig<dynamic, dynamic, dynamic> _config;
  final _PromptTemplates _templates;

  /// Parses `response.output` into [Output]. Null for an untyped prompt, where
  /// the raw JSON value is cast to [Output] (typically `dynamic`) instead.
  final SchemanticType<Output>? _outputSchema;

  Prompt._({
    required this._registry,
    required this._dotpromptRegistry,
    required PromptConfig<Input, Output, dynamic> config,
    required Map<String, dynamic> metadata,
  }) : _config = config,
       _outputSchema = config.outputSchema,
       _templates = _PromptTemplates(),
       ref = PromptRef._(config.fullName, metadata);

  /// Creates a typed view of an existing prompt, for `prompt<Input, Output>()`.
  ///
  /// A plain cast cannot do this: `Prompt<I, dynamic>` is not an
  /// `Prompt<I, Joke>`. The registry, config, and template cache are
  /// shared, so the view behaves as the registered prompt with a parsed output.
  ///
  /// [Input] is the caller's assertion. The registry does not retain it, and
  /// rendering serializes whatever it is handed, so it is not re-checked here.
  Prompt._retyped(Prompt<dynamic, dynamic> source, this._outputSchema)
    : _registry = source._registry,
      _dotpromptRegistry = source._dotpromptRegistry,
      _config = source._config,
      _templates = source._templates,
      ref = source.ref;

  /// Renders the prompt template with the given input, producing
  /// [GenerateActionOptions] suitable for the `generate` action.
  ///
  /// The named parameters override (or, for lists, extend) what the prompt
  /// defines, as in [call]. [messages] is the conversation history. It goes
  /// at `{{history}}` in a messages template (a `.prompt` file body), and
  /// otherwise after the system message. It is ignored when the prompt
  /// defines static `messages`.
  Future<GenerateActionOptions> render<CustomOptions>(
    Input? input, {
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    ToolChoice? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    GenerateActionOutputConfig? output,
    List<GenerateMiddlewareRef>? use,
  }) => _render(
    input,
    _CallOptions(
      messages: messages,
      model: model,
      config: config,
      tools: tools,
      toolNames: toolNames,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: output,
      use: use,
    ),
  );

  Future<GenerateActionOptions> _render(Input? input, _CallOptions opts) async {
    return runInNewSpan(
      'render',
      (telemetryContext) async {
        if (_config.inputSchema case final DeferredSchema schema) {
          schema.ensureResolved();
        }

        final messages = <Message>[];

        // 1. Render system prompt
        await _renderSystem(input, messages);

        // 2. Render history / messages
        await _renderMessages(input, messages, opts);

        // 3. Render user prompt
        await _renderUserPrompt(input, messages);

        // Resolve model
        final resolvedModel = opts.model ?? _config.model;

        // Resolve config — merge config maps
        final configMap = _configToMap(_config.config);
        final optsConfigMap = _configToMap(opts.config);
        final resolvedConfig = <String, dynamic>{
          ...?configMap,
          ...?optsConfigMap,
        };

        // Resolve tools
        final resolvedToolNames = <String>{
          ...?_config.toolNames,
          ...?opts.toolNames,
          ...?_config.tools?.map((t) => t.name),
          ...?opts.tools?.map((t) => t.name),
        }.toList();

        // Resolve middleware refs. These must be carried on the returned
        // options so callers that run the rendered request directly (e.g. the
        // agent runtime via `runGenerateAction`) still apply the middleware.
        final resolvedUse = <MiddlewareRef>[
          ...?_config.use?.map(
            (mw) =>
                MiddlewareRef(name: mw.name, config: _configToMap(mw.config)),
          ),
          ...?opts.use?.map(
            (mw) =>
                MiddlewareRef(name: mw.name, config: _configToMap(mw.config)),
          ),
        ];

        return GenerateActionOptions(
          model: resolvedModel?.name,
          messages: messages,
          config: resolvedConfig.isNotEmpty ? resolvedConfig : null,
          tools: resolvedToolNames.isNotEmpty ? resolvedToolNames : null,
          toolChoice: opts.toolChoice ?? _config.toolChoice,
          returnToolRequests:
              opts.returnToolRequests ?? _config.returnToolRequests,
          maxTurns: opts.maxTurns ?? _config.maxTurns,
          output: _applyOutputOverride(_config, opts.output),
          use: resolvedUse.isNotEmpty ? resolvedUse : null,
        );
      },
      input: input,
      actionType: 'promptTemplate',
    );
  }

  /// Generates a response by rendering the prompt and calling the model.
  ///
  /// The named parameters match `Genkit.generate`, except for the content the
  /// prompt defines itself (system, prompt) and interrupt resumption
  /// (`interruptRespond` / `interruptRestart`), which prompts do not support
  /// yet. Scalars ([model], [toolChoice], [maxTurns], ...) replace the
  /// prompt's value, [config] is merged key by key over the prompt's config,
  /// and [tools], [toolNames] and [use] are appended to the prompt's.
  /// [messages] is the conversation history; see [render] for where it goes.
  ///
  /// ```dart
  /// final response = await joke(
  ///   JokeInput(topic: 'cats'),
  ///   config: {'temperature': 0.2},
  ///   messages: history,
  /// );
  /// ```
  ///
  /// [output] replaces the prompt's output config, except that the prompt's
  /// format and schema (its typed contract) carry over unless [output] picks a
  /// different `format`:
  ///
  /// ```dart
  /// // joke defined with outputSchema: Joke.$schema
  /// await joke(input, output: GenerateActionOutputConfig(constrained: false));
  /// // still the Joke schema, still parsed into a Joke
  ///
  /// await joke(input, output: GenerateActionOutputConfig(format: 'text'));
  /// // no schema sent; `output` is null, the reply is on `text`
  /// ```
  ///
  /// The override does not change how the response is parsed into `Output`,
  /// so a `jsonSchema` set on [output] that does not match `Output` fails at
  /// parse time.
  ///
  /// [cancel] is observed by the model call, tools, and middleware. A
  /// cancelled call resolves with a response whose `finishReason` is
  /// `FinishReason.aborted` (rather than throwing).
  Future<GenerateResult<Output>> call<CustomOptions>(
    Input? input, {
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    ToolChoice? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    GenerateActionOutputConfig? output,
    Map<String, dynamic>? context,
    List<GenerateMiddlewareRef>? use,
    CancellationToken? cancel,
  }) => _generate(
    input,
    _CallOptions(
      messages: messages,
      model: model,
      config: config,
      tools: tools,
      toolNames: toolNames,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: output,
      context: context,
      use: use,
      cancel: cancel,
    ),
  );

  /// Streams a response by rendering the prompt and calling the model.
  ///
  /// Takes the same named parameters as [call].
  ActionStream<GenerateResponseChunk<Output>, GenerateResult<Output>>
  stream<CustomOptions>(
    Input? input, {
    List<Message>? messages,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    List<Tool>? tools,
    List<String>? toolNames,
    ToolChoice? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    GenerateActionOutputConfig? output,
    Map<String, dynamic>? context,
    List<GenerateMiddlewareRef>? use,
    CancellationToken? cancel,
  }) {
    final streamController = StreamController<GenerateResponseChunk<Output>>();
    final actionStream =
        ActionStream<GenerateResponseChunk<Output>, GenerateResult<Output>>(
          streamController.stream,
        );

    _generate(
      input,
      _CallOptions(
        messages: messages,
        model: model,
        config: config,
        tools: tools,
        toolNames: toolNames,
        toolChoice: toolChoice,
        returnToolRequests: returnToolRequests,
        maxTurns: maxTurns,
        output: output,
        context: context,
        use: use,
        cancel: cancel,
      ),
      onChunk: (chunk) {
        if (!streamController.isClosed) {
          streamController.add(chunk);
        }
      },
    ).then(
      (result) {
        actionStream.setResult(result);
        if (!streamController.isClosed) {
          streamController.close();
        }
      },
      onError: (Object e, StackTrace s) {
        actionStream.setError(e, s);
        if (!streamController.isClosed) {
          streamController.addError(e, s);
          streamController.close();
        }
      },
    );

    return actionStream;
  }

  /// Parses a raw output value into [Output] for a [request] rendered by this
  /// prompt.
  ///
  /// When a per-call `output` switched the prompt's format (e.g. to text),
  /// the formatter's value is not an [Output]: a pinned [Output] gets null
  /// (the reply is still on `text`) and an unpinned one gets the raw value.
  Output? _parseOutput(
    GenerateActionOptions request,
    Object? raw, {
    bool partial = false,
  }) {
    // Compared without resolving the prompt's schema, which may be deferred
    // and undefined when the call brought its own.
    final switchedFormat =
        _effectiveFormat(request.output) != _config._outputFormat;
    if (switchedFormat) {
      return _isUnconstrained<Output>() ? raw as Output? : null;
    }
    return partial
        ? parsePartialOutput(raw, _outputSchema)
        : parseOutput(raw, _outputSchema);
  }

  /// Internal generate implementation shared by [call] and [stream].
  Future<GenerateResult<Output>> _generate(
    Input? input,
    _CallOptions opts, {
    StreamingCallback<GenerateResponseChunk<Output>>? onChunk,
  }) async {
    return runInNewSpan(
      ref.name,
      (telemetryContext) async {
        final options = await _render(input, opts);

        // Resolve tools from both config and opts into a child registry
        final allTools = <Tool>[...?_config.tools, ...?opts.tools];

        final middleware = <GenerateMiddlewareOneof>[
          ...?_config.use?.map(
            (mw) => (middlewareRef: mw, middlewareInstance: null),
          ),
          ...?opts.use?.map(
            (mw) => (middlewareRef: mw, middlewareInstance: null),
          ),
        ];

        var registry = _registry;
        if (allTools.isNotEmpty) {
          registry = Registry.childOf(_registry);
          for (final tool in allTools) {
            registry.register(tool);
          }
        }

        final raw = await generateHelper(
          registry,
          messages: options.messages,
          model: options.model != null ? modelRef(options.model!) : null,
          config: options.config,
          tools: options.tools,
          toolChoice: options.toolChoice,
          returnToolRequests: options.returnToolRequests,
          maxTurns: options.maxTurns,
          output: options.output,
          context: opts.context,
          cancel: opts.cancel,
          middleware: middleware.isNotEmpty ? middleware : null,
          onChunk: onChunk == null
              ? null
              : (c) => onChunk(
                  GenerateResponseChunk<Output>(
                    c.modelChunk,
                    previousChunks: List.from(c.previousChunks),
                    output: _parseOutput(options, c.output, partial: true),
                  ),
                ),
        );

        // An aborted or failed response carries no output; `_parseOutput`
        // returns null for it so the response (and its resumable history)
        // survives a structured-output call.
        return GenerateResult<Output>(
          raw.modelResponse,
          request: raw.modelRequest,
          output: _parseOutput(options, raw.output),
          cause: raw.cause,
        );
      },
      input: input,
      actionType: 'dotprompt',
    );
  }

  // --- Internal rendering methods ---

  Future<void> _renderSystem(Input? input, List<Message> messages) async {
    if (_config.system != null) {
      // Handlebars template (Future-based memoization for concurrency safety)
      _templates.system ??= _dotpromptRegistry.compile(_config.system!);
      final compiled = await _templates.system!;
      final rendered = await compiled.render(
        dp.DataArgument(input: _inputToMap(input)),
      );
      messages.addAll(rendered.messages.map(dpMessageToGenkitMessage));
      // If dotprompt rendered it as a user message, change role to system
      if (messages.isNotEmpty && messages.last.role != Role.system) {
        final last = messages.removeLast();
        messages.add(Message(role: Role.system, content: last.content));
      }
    } else if (_config.systemParts != null) {
      messages.add(Message(role: Role.system, content: _config.systemParts!));
    }
  }

  Future<void> _renderMessages(
    Input? input,
    List<Message> messages,
    _CallOptions opts,
  ) async {
    if (_config.messagesTemplate != null) {
      // Handlebars template for messages
      _templates.messages ??= _dotpromptRegistry.compile(
        _config.messagesTemplate!,
      );
      final compiled = await _templates.messages!;
      final rendered = await compiled.render(
        dp.DataArgument(
          input: _inputToMap(input),
          messages: opts.messages?.map(genkitMessageToDpMessage).toList(),
        ),
      );
      messages.addAll(rendered.messages.map(dpMessageToGenkitMessage));
    } else if (_config.messages != null) {
      messages.addAll(_config.messages!);
    } else {
      // If no messages config, add history from opts
      if (opts.messages != null) {
        messages.addAll(opts.messages!);
      }
    }
  }

  Future<void> _renderUserPrompt(Input? input, List<Message> messages) async {
    if (_config.prompt != null) {
      // Handlebars template (Future-based memoization for concurrency safety)
      _templates.prompt ??= _dotpromptRegistry.compile(_config.prompt!);
      final compiled = await _templates.prompt!;
      final rendered = await compiled.render(
        dp.DataArgument(input: _inputToMap(input)),
      );
      // The dotprompt render may produce multiple messages; add all as user
      for (final msg in rendered.messages) {
        final genkitMsg = dpMessageToGenkitMessage(msg);
        if (genkitMsg.role == Role.user) {
          messages.add(genkitMsg);
        } else {
          messages.add(Message(role: Role.user, content: genkitMsg.content));
        }
      }
    } else if (_config.promptParts != null) {
      messages.add(Message(role: Role.user, content: _config.promptParts!));
    }
  }

  Map<String, dynamic>? _inputToMap(Input? input) {
    if (input == null) return null;
    if (input is Map<String, dynamic>) return input;
    // Try to serialize via toJson
    try {
      return (input as dynamic).toJson() as Map<String, dynamic>;
    } catch (_) {
      return {'input': input};
    }
  }
}

/// Converts a config value to a Map. Follows the same pattern as generate.dart.
Map<String, dynamic>? _configToMap(dynamic config) {
  if (config == null) return null;
  if (config is Map) return config.cast<String, dynamic>();
  if (config is String || config is num || config is bool) return null;

  try {
    return (config as dynamic).toJson() as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

/// Defines a template prompt and registers it in the registry.
///
/// This creates both a `PromptAction` (registered as actionType
/// 'executable-prompt') and returns a [Prompt] that can be called
/// directly.
Prompt<Input, Output> definePromptAction<Input, Output, CustomOptions>(
  Registry registry,
  DotpromptRegistry dotpromptRegistry,
  PromptConfig<Input, Output, CustomOptions> config, {
  Map<String, dynamic>? metadata,
}) {
  final promptMetadata = _buildPromptMetadata(config, metadata);

  final prompt = Prompt<Input, Output>._(
    registry: registry,
    dotpromptRegistry: dotpromptRegistry,
    config: config,
    metadata: promptMetadata,
  );

  // Register a PromptAction in the registry
  final action = PromptAction<Input>.fromPrompt(
    prompt,
    name: config.fullName,
    description: config.description,
    inputSchema: config.inputSchema,
    metadata: promptMetadata,
  );
  registry.register(action);

  return prompt;
}

/// Builds prompt metadata for registry/reflection purposes.
Map<String, dynamic> _buildPromptMetadata<Input, Output, CustomOptions>(
  PromptConfig<Input, Output, CustomOptions> config,
  Map<String, dynamic>? extraMetadata,
) {
  return {
    ...?extraMetadata,
    ...?config.metadata,
    'type': 'prompt',
    'prompt': {
      'name': config.name,
      if (config.variant != null) 'variant': config.variant,
      if (config.model != null) 'model': config.model!.name,
      if (config.config != null) 'config': _configToMap(config.config),
      if (config.toolNames != null) 'tools': config.toolNames,
      if (config.toolChoice != null) 'toolChoice': config.toolChoice,
      if (config.messagesTemplate != null) 'template': config.messagesTemplate,
      if (config.maxTurns != null) 'maxTurns': config.maxTurns,
      if (config.returnToolRequests != null)
        'returnToolRequests': config.returnToolRequests,
      // Surface middleware as `{name, config}` entries, mirroring the JS
      // prompt loader's `metadata.prompt.use`.
      if (config.use != null)
        'use': [
          for (final mw in config.use!)
            {'name': mw.name, if (mw.config != null) 'config': mw.config},
        ],
    },
  };
}

/// The registered action for a prompt.
///
/// When invoked, it renders the prompt and returns [GenerateActionOptions]
/// (i.e., the generate request).
base class PromptAction<Input>
    extends Action<Input, GenerateActionOptions, void, void> {
  // Output-erased: a prompt of any output type is stored here, and
  // `lookupPrompt` re-types it on the way out.
  final Prompt<Input, dynamic>? _prompt;

  /// A prompt whose request is built by [fn]. Backs
  /// `Genkit.defineCustomPrompt` and plugin-provided prompts (e.g. MCP).
  PromptAction({
    required String name,
    required PromptFn<Input> fn,
    SchemanticType<Input>? inputSchema,
    String? description,
    Map<String, dynamic>? metadata,
  }) : this._(
         name: name,
         inputSchema: inputSchema,
         description: description,
         metadata: metadata,
         fn: requireInput('Prompt', name, fn),
       );

  /// The registry entry for a template prompt; see [definePromptAction].
  @internal
  PromptAction.fromPrompt(
    Prompt<Input, dynamic> prompt, {
    required String name,
    SchemanticType<Input>? inputSchema,
    String? description,
    Map<String, dynamic>? metadata,
  }) : this._(
         name: name,
         inputSchema: inputSchema,
         description: description,
         metadata: metadata,
         prompt: prompt,
         fn: (input, ctx) => prompt.render(input),
       );

  PromptAction._({
    required super.name,
    required super.fn,
    super.inputSchema,
    super.description,
    Map<String, dynamic>? metadata,
    this._prompt,
  }) : super(
         actionType: .executablePrompt,
         outputSchema: GenerateActionOptions.$schema,
         metadata: _promptActionMetadata(description, metadata),
       );

  /// The template prompt, when this action was created by
  /// [definePromptAction]; null for a [PromptFn]-backed prompt.
  @internal
  Prompt<Input, dynamic>? get prompt => _prompt;
}

/// Builds the generate request for a custom prompt from its [input].
///
/// See `Genkit.defineCustomPrompt`.
typedef PromptFn<Input> =
    Future<GenerateActionOptions> Function(
      Input input,
      ActionFnArg<void, Input, void> ctx,
    );

Map<String, dynamic> _promptActionMetadata(
  String? description,
  Map<String, dynamic>? metadata,
) {
  final result = <String, dynamic>{...?metadata};
  result['type'] = 'prompt';
  if (description != null) {
    result['description'] = description;
  }
  return result;
}

/// Looks up a prompt by name in the registry and returns its
/// [Prompt], typed as `Prompt<Input, Output>`.
///
/// The registry does not retain the prompt's input type, so [Input] is purely
/// the caller's assertion; rendering serializes whatever it is handed.
/// [Output] is parsed with, in order:
///
/// 1. [outputParserSchema], when the caller supplies one (the usual case for a
///    `.prompt` file, whose schema has no Dart type);
/// 2. the schema the prompt was defined with, when it produces an [Output];
/// 3. nothing, when [Output] is a type raw decoded JSON already fits
///    (`dynamic`, `Map<String, dynamic>`, ...). Otherwise this throws.
///
/// What the prompt must define depends on [Output]:
///
/// - a domain type (`Summary`), or any [outputParserSchema]: a schema the
///   model is given. [outputParserSchema] only parses and is never sent, so a
///   prompt that only says `format: json` cannot back it;
/// - a JSON-shaped type (`Map<String, dynamic>`): a structured format;
/// - `dynamic`: nothing.
///
/// Failing here, rather than on a cast or a silent null in the eventual
/// response, keeps the error at the call that has to change.
Future<Prompt<Input, Output>> lookupPrompt<Input, Output>(
  Registry registry,
  String name, {
  String? variant,
  SchemanticType<Output>? outputParserSchema,
}) async {
  final label = 'Prompt $name${variant != null ? ' (variant $variant)' : ''}';
  final lookupName = variant != null ? '$name.$variant' : name;
  final action = await registry.lookupAction(.executablePrompt, lookupName);

  final found = action is PromptAction ? action.prompt : null;
  if (found == null) {
    throw GenkitException('$label not found', status: StatusCode.notFound);
  }

  final defined = found._outputSchema;
  final resolved =
      outputParserSchema ??
      (defined is SchemanticType<Output> ? defined : null);
  final error = _outputTypeError<Output>(
    label: label,
    config: found._config,
    hasParser: resolved != null,
    site: .lookup,
  );
  if (error != null) {
    throw GenkitException(error, status: StatusCode.invalidArgument);
  }
  return Prompt<Input, Output>._retyped(found, resolved);
}

/// Where [_outputTypeError] runs; only the suggested fixes differ.
enum _OutputCheckSite { define, lookup }

/// Checks that [config] backs [Output], returning an error message or null.
///
/// One rule, three levels, shared by `definePrompt` and `prompt()`:
///
/// | Output | the prompt must define |
/// |---|---|
/// | a domain type (`Joke`), or any parser | a schema the model is given |
/// | JSON-shaped (`Map<String, dynamic>`) | a structured format (or schema) |
/// | unconstrained (`dynamic`) | nothing |
///
/// A parser alone is not enough for the first level: `outputParserSchema` is
/// never sent, so on a format-only prompt the model would only be guessing
/// the shape. Such a prompt is still typeable at the JSON-shaped level.
///
/// The callers throw their own exception type: `ArgumentError` for a
/// synchronous definition mistake, `GenkitException` from the async lookup
/// (which also reports not-found that way).
String? _outputTypeError<Output>({
  required String label,
  required PromptConfig<dynamic, dynamic, dynamic> config,
  required bool hasParser,
  _OutputCheckSite site = .define,
}) {
  final lookup = site == _OutputCheckSite.lookup;
  // Covers every way a prompt defines its wire schema: `outputSchema`, a
  // `jsonSchema` on `output`, and a `.prompt` file's `output.schema`.
  final hasWireSchema = config._definesWireSchema;
  final requestsJson = config._requestsStructuredOutput;

  if (hasParser || !_isJsonAssignable<Output>()) {
    if (hasParser && hasWireSchema) return null;
    if (!lookup) {
      // A definition's only parser is its outputSchema, which is also its
      // wire schema, so the only failure here is a missing outputSchema.
      return '$label declares an output type of $Output but has no '
          'outputSchema to parse it. Pass outputSchema: to definePrompt().';
    }
    if (hasWireSchema) {
      return '$label was not defined with an output schema for $Output. '
          'Pass outputParserSchema: to prompt(), or look it up untyped.';
    }
    final reason = requestsJson
        ? 'requests JSON but defines no output schema'
        : 'defines no output schema and does not request structured output';
    final parserNote = hasParser
        ? ' outputParserSchema only parses the response; it is never sent.'
        : '';
    final fallback = requestsJson
        ? 'look it up as prompt<dynamic, Map<String, dynamic>>()'
        : 'look it up untyped';
    return '$label $reason, so the model is never given the shape of $Output '
        'and the output cannot be parsed reliably.$parserNote To parse into '
        '$Output, define the schema on the prompt (outputSchema: in '
        'definePrompt, or output.schema in the .prompt file), or $fallback.';
  }

  // JSON-shaped: no schema needed, but without a structured format no
  // formatter runs, so `output` would come back null on every call.
  if (_isUnconstrained<Output>() || requestsJson) return null;
  return lookup
      ? '$label does not request structured output, so its output would '
            'always be null. Set output.format (e.g. json) on the prompt, or '
            'look it up untyped.'
      : '$label declares an output type of $Output but does not request '
            'structured output, so its output would always be null. Set a '
            'format on output: (e.g. json) or pass outputSchema:.';
}

/// The format a request is parsed with: the explicit one, else `json` when a
/// schema is set (what `resolveFormat` does).
String? _effectiveFormat(GenerateActionOutputConfig? output) =>
    output?.format ?? (output?.jsonSchema != null ? 'json' : null);

/// Applies a per-call output override to the prompt's own output config.
///
/// The override replaces the config wholesale (as in JS), except for the
/// prompt's output contract: its format and schema carry over unless the
/// override picks a different format. So `constrained: false` keeps
/// json + schema, while `format: 'text'` drops both, and a typed prompt then
/// yields a null `output` (see [Prompt._parseOutput]). A `jsonSchema` set on
/// the override wins over the prompt's.
///
/// The prompt's schema is resolved only when the result carries it, so an
/// override with its own schema or format still works while a deferred
/// schema name is undefined.
GenerateActionOutputConfig? _applyOutputOverride(
  PromptConfig<dynamic, dynamic, dynamic> config,
  GenerateActionOutputConfig? override,
) {
  if (override == null) return config.resolvedOutput;
  final switchesFormat =
      override.format != null && override.format != config._outputFormat;
  if (!config._hasOutput || switchesFormat) return override;
  return GenerateActionOutputConfig.fromJson({
    ...override.toJson(),
    'format': ?config.output?.format,
    'jsonSchema': ?(override.jsonSchema ?? config.resolvedOutput?.jsonSchema),
  });
}

/// Whether a raw decoded JSON value can inhabit [T] without a schema to parse
/// it, i.e. whether `rawValue as T` is safe.
///
/// True for `dynamic`/`Object`/`Object?` (the caller pinned nothing) and for
/// the JSON types a decoder already produces, so `Output` of
/// `Map<String, dynamic>` or `String` needs no schema. False for a domain type
/// like `Joke`, which only a schema can produce; those must supply one or the
/// cast blows up at generate time with a bare `TypeError`.
///
/// Checked through `List<T>` rather than `T` directly because a bare
/// `<value> is T` cannot be written for an unbound type parameter.
bool _isJsonAssignable<T>() =>
    _isUnconstrained<T>() ||
    <Map<String, dynamic>>[] is List<T> ||
    <List<dynamic>>[] is List<T> ||
    <String>[] is List<T> ||
    <num>[] is List<T> ||
    <int>[] is List<T> ||
    <double>[] is List<T> ||
    <bool>[] is List<T>;

/// Whether [T] pins nothing (`dynamic`, `Object`, `Object?`), as on an untyped
/// prompt or lookup. Such a prompt may legitimately produce text only.
bool _isUnconstrained<T>() => <Object>[] is List<T>;
