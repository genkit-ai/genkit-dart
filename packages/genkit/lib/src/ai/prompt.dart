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

/// Configuration for defining a prompt.
///
/// This holds all the metadata needed to define an executable prompt action.
class PromptConfig<Input, Output, CustomOptions> {
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
  }) {
    if (outputSchema != null && output?.jsonSchema != null) {
      throw ArgumentError(
        'Prompt "$name" sets a JSON schema on both outputSchema and output. '
        'Use outputSchema for the schema and output for format/constrained/'
        'instructions only.',
      );
    }
  }

  /// The full name including variant.
  String get fullName => variant != null ? '$name.$variant' : name;

  /// The wire output config, with [outputSchema]'s JSON schema folded in.
  ///
  /// Returns null when the prompt configures no output at all, so the rendered
  /// options stay free of an empty `output` block.
  GenerateActionOutputConfig? get resolvedOutput {
    if (outputSchema == null) return output;
    return GenerateActionOutputConfig.fromJson({
      ...?output?.toJson(),
      'jsonSchema': toJsonSchema(type: outputSchema),
    });
  }
}

/// Options for generating from a prompt (everything except prompt/system
/// content, which is defined by the prompt itself).
class PromptGenerateOptions<CustomOptions> {
  final ModelRef<CustomOptions>? model;
  final CustomOptions? config;
  final List<Tool>? tools;
  final List<String>? toolNames;
  final ToolChoice? toolChoice;
  final bool? returnToolRequests;
  final int? maxTurns;
  final GenerateActionOutputConfig? output;
  final Map<String, dynamic>? context;
  final List<GenerateMiddlewareRef>? use;
  final List<Message>? messages;

  /// Cooperative cancellation token, observed by the model call, tools, and
  /// middleware to abort generation. A cancelled call resolves with a response
  /// whose `finishReason` is `FinishReason.aborted` (rather than throwing).
  final CancellationToken? cancel;

  PromptGenerateOptions({
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
/// Held separately from [ExecutablePrompt] so the typed views produced by a
/// `prompt<Input, Output>()` lookup share one cache with the registered prompt
/// instead of recompiling per lookup. Futures (not values) are memoized so
/// concurrent first-renders await the same compile.
class _PromptTemplates {
  Future<dp.PromptFunction>? system;
  Future<dp.PromptFunction>? prompt;
  Future<dp.PromptFunction>? messages;
}

/// An executable prompt that can render, generate, and stream.
///
/// It acts as a callable that invokes `generate` with the rendered prompt
/// template, and also provides `.render()` and `.stream()` methods.
///
/// [Output] is the parsed structured output type: `(await prompt(input)).output`
/// is an `Output?`. It is inferred from `outputSchema` at definition, and is
/// `dynamic` for a prompt defined without one.
final class ExecutablePrompt<Input, Output> {
  /// A reference to the prompt (name + optional metadata).
  final ({String name, Map<String, dynamic>? metadata}) ref;

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

  ExecutablePrompt._({
    required this._registry,
    required this._dotpromptRegistry,
    required PromptConfig<Input, Output, dynamic> config,
    Map<String, dynamic>? metadata,
  }) : _config = config,
       _outputSchema = config.outputSchema,
       _templates = _PromptTemplates(),
       ref = (name: config.fullName, metadata: metadata);

  /// Creates a typed view of an existing prompt, for `prompt<Input, Output>()`.
  ///
  /// A plain cast cannot do this: `ExecutablePrompt<I, dynamic>` is not an
  /// `ExecutablePrompt<I, Joke>`. The registry, config, and template cache are
  /// shared, so the view behaves as the registered prompt with a parsed output.
  ///
  /// [Input] is the caller's assertion. The registry does not retain it, and
  /// rendering serializes whatever it is handed, so it is not re-checked here.
  ExecutablePrompt._retyped(
    ExecutablePrompt<dynamic, dynamic> source,
    this._outputSchema,
  ) : _registry = source._registry,
      _dotpromptRegistry = source._dotpromptRegistry,
      _config = source._config,
      _templates = source._templates,
      ref = source.ref;

  /// Renders the prompt template with the given input, producing
  /// [GenerateActionOptions] suitable for the `generate` action.
  Future<GenerateActionOptions> render(
    Input? input, [
    PromptGenerateOptions? opts,
  ]) async {
    return runInNewSpan(
      'render',
      (telemetryContext) async {
        final messages = <Message>[];

        // 1. Render system prompt
        await _renderSystem(input, messages);

        // 2. Render history / messages
        await _renderMessages(input, messages, opts);

        // 3. Render user prompt
        await _renderUserPrompt(input, messages);

        // Resolve model
        final resolvedModel = opts?.model ?? _config.model;

        // Resolve config — merge config maps
        final configMap = _configToMap(_config.config);
        final optsConfigMap = _configToMap(opts?.config);
        final resolvedConfig = <String, dynamic>{
          ...?configMap,
          ...?optsConfigMap,
        };

        // Resolve tools
        final resolvedToolNames = <String>{
          ...?_config.toolNames,
          ...?opts?.toolNames,
          ...?_config.tools?.map((t) => t.name),
          ...?opts?.tools?.map((t) => t.name),
        }.toList();

        // Resolve middleware refs. These must be carried on the returned
        // options so callers that run the rendered request directly (e.g. the
        // agent runtime via `runGenerateAction`) still apply the middleware.
        final resolvedUse = <MiddlewareRef>[
          ...?_config.use?.map(
            (mw) =>
                MiddlewareRef(name: mw.name, config: _configToMap(mw.config)),
          ),
          ...?opts?.use?.map(
            (mw) =>
                MiddlewareRef(name: mw.name, config: _configToMap(mw.config)),
          ),
        ];

        return GenerateActionOptions(
          model: resolvedModel?.name,
          messages: messages,
          config: resolvedConfig.isNotEmpty ? resolvedConfig : null,
          tools: resolvedToolNames.isNotEmpty ? resolvedToolNames : null,
          toolChoice: opts?.toolChoice ?? _config.toolChoice,
          returnToolRequests:
              opts?.returnToolRequests ?? _config.returnToolRequests,
          maxTurns: opts?.maxTurns ?? _config.maxTurns,
          // `_config.resolvedOutput` folds the typed `outputSchema` into the
          // wire config; a per-call `output` still overrides it wholesale.
          output: opts?.output ?? _config.resolvedOutput,
          use: resolvedUse.isNotEmpty ? resolvedUse : null,
        );
      },
      input: input,
      actionType: 'promptTemplate',
    );
  }

  /// Generates a response by rendering the prompt and calling the model.
  Future<GenerateResponseHelper<Output>> call(
    Input? input, [
    PromptGenerateOptions? opts,
  ]) => _generate(input, opts);

  /// Streams a response by rendering the prompt and calling the model.
  ActionStream<GenerateResponseChunk<Output>, GenerateResponseHelper<Output>>
  stream(Input? input, [PromptGenerateOptions? opts]) {
    final streamController = StreamController<GenerateResponseChunk<Output>>();
    final actionStream =
        ActionStream<
          GenerateResponseChunk<Output>,
          GenerateResponseHelper<Output>
        >(streamController.stream);

    _generate(
      input,
      opts,
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

  /// Parses a raw JSON output value into [Output].
  ///
  /// Without a schema the prompt is untyped and [Output] is whatever the caller
  /// asserted (normally `dynamic`), so the raw value passes through.
  Output? _parseOutput(Object? raw) {
    if (raw == null) return null;
    final schema = _outputSchema;
    return schema == null ? raw as Output : schema.parse(raw);
  }

  /// Parses a streamed chunk's *partial* output.
  ///
  /// Partial JSON often fails a strict schema while the value is still
  /// arriving. That is not a generation failure, so the chunk's typed output is
  /// simply unavailable; the final response is still parsed strictly.
  Output? _parsePartialOutput(Object? raw) {
    try {
      return _parseOutput(raw);
    } on Object {
      return null;
    }
  }

  /// Internal generate implementation shared by [call] and [stream].
  Future<GenerateResponseHelper<Output>> _generate(
    Input? input,
    PromptGenerateOptions? opts, {
    StreamingCallback<GenerateResponseChunk<Output>>? onChunk,
  }) async {
    return runInNewSpan(
      ref.name,
      (telemetryContext) async {
        final options = await render(input, opts);

        // Resolve tools from both config and opts into a child registry
        final allTools = <Tool>[...?_config.tools, ...?opts?.tools];

        final middleware = <GenerateMiddlewareOneof>[
          ...?_config.use?.map(
            (mw) => (middlewareRef: mw, middlewareInstance: null),
          ),
          ...?opts?.use?.map(
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
          context: opts?.context,
          cancel: opts?.cancel,
          middleware: middleware.isNotEmpty ? middleware : null,
          onChunk: onChunk == null
              ? null
              : (c) => onChunk(
                  GenerateResponseChunk<Output>(
                    c.rawChunk,
                    previousChunks: List.from(c.previousChunks),
                    output: _parsePartialOutput(c.output),
                  ),
                ),
        );

        // An aborted or failed response carries no output; `_parseOutput`
        // returns null for it so the response (and its resumable history)
        // survives a structured-output call.
        return GenerateResponseHelper<Output>(
          raw.rawResponse,
          request: raw.modelRequest,
          output: _parseOutput(raw.output),
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
    PromptGenerateOptions? opts,
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
          messages: opts?.messages?.map(genkitMessageToDpMessage).toList(),
        ),
      );
      messages.addAll(rendered.messages.map(dpMessageToGenkitMessage));
    } else if (_config.messages != null) {
      messages.addAll(_config.messages!);
    } else {
      // If no messages config, add history from opts
      if (opts?.messages != null) {
        messages.addAll(opts!.messages!);
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

/// Defines an executable prompt and registers it in the registry.
///
/// This creates both a `PromptAction` (registered as actionType
/// 'executable-prompt') and returns an [ExecutablePrompt] that can be called
/// directly.
ExecutablePrompt<Input, Output>
definePromptAction<Input, Output, CustomOptions>(
  Registry registry,
  DotpromptRegistry dotpromptRegistry,
  PromptConfig<Input, Output, CustomOptions> config, {
  Map<String, dynamic>? metadata,
}) {
  final promptMetadata = _buildPromptMetadata(config, metadata);

  final executablePrompt = ExecutablePrompt<Input, Output>._(
    registry: registry,
    dotpromptRegistry: dotpromptRegistry,
    config: config,
    metadata: promptMetadata,
  );

  // Register a PromptAction in the registry
  final action = PromptAction<Input>(
    name: config.fullName,
    description: config.description,
    inputSchema: config.inputSchema,
    executablePrompt: executablePrompt,
    metadata: promptMetadata,
  );
  registry.register(action);

  return executablePrompt;
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
/// When invoked, it renders the prompt template and returns
/// [GenerateActionOptions] (i.e., the generate request).
base class PromptAction<Input>
    extends Action<Input, GenerateActionOptions, void, void> {
  // Output-erased: a prompt of any output type is stored here, and
  // `lookupPrompt` re-types it on the way out.
  final ExecutablePrompt<Input, dynamic>? _executablePrompt;

  PromptAction({
    required super.name,
    ExecutablePrompt<Input, dynamic>? executablePrompt,
    PromptFn<Input>? fn,
    super.inputSchema,
    super.description,
    Map<String, dynamic>? metadata,
  }) : _executablePrompt = executablePrompt,
       super(
         actionType: .executablePrompt,
         outputSchema: GenerateActionOptions.$schema,
         metadata: _promptActionMetadata(description, metadata),
         fn: (input, ctx) async {
           if (executablePrompt != null) {
             return executablePrompt.render(input);
           }
           if (fn != null) {
             if (input == null && inputSchema != null && null is! Input) {
               throw ArgumentError('Prompt "$name" requires a non-null input.');
             }
             return fn(input as Input, ctx);
           }
           throw StateError('PromptAction has no executable prompt or fn');
         },
       );

  /// The executable prompt instance, if this action was created via
  /// [definePromptAction].
  ExecutablePrompt<Input, dynamic>? get executablePrompt => _executablePrompt;
}

/// Legacy prompt function type for backwards compatibility.
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
/// [ExecutablePrompt], typed as `ExecutablePrompt<Input, Output>`.
///
/// The registry does not retain the prompt's input type, so [Input] is purely
/// the caller's assertion; rendering serializes whatever it is handed.
/// [Output] is backed by a real schema, resolved in this order:
///
/// 1. [outputSchema], when the caller supplies one (the usual case for a
///    `.prompt` file, which has a JSON schema but no Dart type);
/// 2. the schema the prompt was defined with, when it produces an [Output];
/// 3. otherwise this throws, unless [Output] is unconstrained (`dynamic`).
///
/// Failing here, rather than on a cast inside the eventual response, keeps the
/// error at the call that has to change.
Future<ExecutablePrompt<Input, Output>> lookupPrompt<Input, Output>(
  Registry registry,
  String name, {
  String? variant,
  SchemanticType<Output>? outputSchema,
}) async {
  final label = 'Prompt $name${variant != null ? ' (variant $variant)' : ''}';
  final lookupName = variant != null ? '$name.$variant' : name;
  final action = await registry.lookupAction(.executablePrompt, lookupName);

  final found = action is PromptAction ? action.executablePrompt : null;
  if (found == null) {
    throw GenkitException('$label not found', status: StatusCodes.NOT_FOUND);
  }

  final defined = found._outputSchema;
  final resolved =
      outputSchema ?? (defined is SchemanticType<Output> ? defined : null);
  if (resolved == null && !_isUnconstrained<Output>()) {
    throw GenkitException(
      '$label was not defined with an output schema for $Output. Pass '
      'outputSchema: to prompt<$Input, $Output>(), or look it up untyped.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return ExecutablePrompt<Input, Output>._retyped(found, resolved);
}

/// Whether [T] is an unconstrained type argument, i.e. the caller did not pin
/// an output type and raw JSON can pass through unparsed.
///
/// True for `dynamic`, `Object`, and `Object?`, which any JSON value already
/// satisfies; false for a real type like `Joke`, which needs a schema to parse.
bool _isUnconstrained<T>() => <Object>[] is List<T>;
