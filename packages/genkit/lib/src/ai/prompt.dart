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
import '../core/registry.dart';
import '../exception.dart';
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
class PromptConfig<CustomOptions, Input> {
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

  /// Output format configuration.
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
  final String? toolChoice;

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
    this.output,
    this.maxTurns,
    this.returnToolRequests,
    this.metadata,
    this.tools,
    this.toolNames,
    this.toolChoice,
    this.use,
  });

  /// The full name including variant.
  String get fullName => variant != null ? '$name.$variant' : name;
}

/// Options for generating from a prompt (everything except prompt/system
/// content, which is defined by the prompt itself).
class PromptGenerateOptions<CustomOptions> {
  final ModelRef<CustomOptions>? model;
  final CustomOptions? config;
  final List<Tool>? tools;
  final List<String>? toolNames;
  final String? toolChoice;
  final bool? returnToolRequests;
  final int? maxTurns;
  final GenerateActionOutputConfig? output;
  final Map<String, dynamic>? context;
  final List<GenerateMiddlewareRef>? use;
  final List<Message>? messages;

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
  });
}

/// An executable prompt that can render, generate, and stream.
///
/// It acts as a callable that invokes `generate` with the rendered prompt
/// template, and also provides `.render()` and `.stream()` methods.
class ExecutablePrompt<Input> {
  /// A reference to the prompt (name + optional metadata).
  final ({String name, Map<String, dynamic>? metadata}) ref;

  final Registry _registry;
  final DotpromptRegistry _dotpromptRegistry;
  final PromptConfig<dynamic, Input> _config;

  // Memoized compiled template futures (Future-based for concurrency safety).
  Future<dp.PromptFunction>? _compiledSystem;
  Future<dp.PromptFunction>? _compiledPrompt;
  Future<dp.PromptFunction>? _compiledMessages;

  ExecutablePrompt._({
    required Registry registry,
    required DotpromptRegistry dotpromptRegistry,
    required PromptConfig<dynamic, Input> config,
    Map<String, dynamic>? metadata,
  }) : _registry = registry,
       _dotpromptRegistry = dotpromptRegistry,
       _config = config,
       ref = (name: config.fullName, metadata: metadata);

  /// Renders the prompt template with the given input, producing
  /// [GenerateActionOptions] suitable for the `generate` action.
  Future<GenerateActionOptions> render(
    Input? input, [
    PromptGenerateOptions? opts,
  ]) async {
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
    final resolvedConfig = <String, dynamic>{...?configMap, ...?optsConfigMap};

    // Resolve tools
    final resolvedToolNames = <String>{
      ...?_config.toolNames,
      ...?opts?.toolNames,
      ...?_config.tools?.map((t) => t.name),
      ...?opts?.tools?.map((t) => t.name),
    }.toList();

    return GenerateActionOptions(
      model: resolvedModel?.name,
      messages: messages,
      config: resolvedConfig.isNotEmpty ? resolvedConfig : null,
      tools: resolvedToolNames.isNotEmpty ? resolvedToolNames : null,
      toolChoice: opts?.toolChoice ?? _config.toolChoice,
      returnToolRequests:
          opts?.returnToolRequests ?? _config.returnToolRequests,
      maxTurns: opts?.maxTurns ?? _config.maxTurns,
      output: opts?.output ?? _config.output,
    );
  }

  /// Generates a response by rendering the prompt and calling the model.
  Future<GenerateResponseHelper> call(
    Input? input, [
    PromptGenerateOptions? opts,
  ]) => _generate(input, opts);

  /// Streams a response by rendering the prompt and calling the model.
  ActionStream<GenerateResponseChunk, GenerateResponseHelper> stream(
    Input? input, [
    PromptGenerateOptions? opts,
  ]) {
    final streamController = StreamController<GenerateResponseChunk>();
    final actionStream =
        ActionStream<GenerateResponseChunk, GenerateResponseHelper>(
          streamController.stream,
        );

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

  /// Internal generate implementation shared by [call] and [stream].
  Future<GenerateResponseHelper> _generate(
    Input? input,
    PromptGenerateOptions? opts, {
    StreamingCallback<GenerateResponseChunk>? onChunk,
  }) async {
    final options = await render(input, opts);

    // Resolve tools from both config and opts into a child registry
    final allTools = <Tool>[...?_config.tools, ...?opts?.tools];

    final middleware = <GenerateMiddlewareOneof>[
      ...?_config.use?.map(
        (mw) => (middlewareRef: mw, middlewareInstance: null),
      ),
      ...?opts?.use?.map((mw) => (middlewareRef: mw, middlewareInstance: null)),
    ];

    var registry = _registry;
    if (allTools.isNotEmpty) {
      registry = Registry.childOf(_registry);
      for (final tool in allTools) {
        registry.register(tool);
      }
    }

    return generateHelper(
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
      middleware: middleware.isNotEmpty ? middleware : null,
      onChunk: onChunk,
    );
  }

  // --- Internal rendering methods ---

  Future<void> _renderSystem(Input? input, List<Message> messages) async {
    if (_config.system != null) {
      // Handlebars template (Future-based memoization for concurrency safety)
      _compiledSystem ??= _dotpromptRegistry.compile(_config.system!);
      final compiled = await _compiledSystem!;
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
      _compiledMessages ??= _dotpromptRegistry.compile(
        _config.messagesTemplate!,
      );
      final compiled = await _compiledMessages!;
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
      _compiledPrompt ??= _dotpromptRegistry.compile(_config.prompt!);
      final compiled = await _compiledPrompt!;
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
  if (config is Map) return config as Map<String, dynamic>;
  return (config as dynamic).toJson() as Map<String, dynamic>;
}

/// Defines an executable prompt and registers it in the registry.
///
/// This creates both a `PromptAction` (registered as actionType 'prompt')
/// and returns an [ExecutablePrompt] that can be called directly.
ExecutablePrompt<Input> definePromptAction<CustomOptions, Input>(
  Registry registry,
  DotpromptRegistry dotpromptRegistry,
  PromptConfig<CustomOptions, Input> config, {
  Map<String, dynamic>? metadata,
}) {
  final promptMetadata = _buildPromptMetadata(config, metadata);

  final executablePrompt = ExecutablePrompt<Input>._(
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
Map<String, dynamic> _buildPromptMetadata<CustomOptions, Input>(
  PromptConfig<CustomOptions, Input> config,
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
    },
  };
}

/// The registered action for a prompt.
///
/// When invoked, it renders the prompt template and returns
/// [GenerateActionOptions] (i.e., the generate request).
class PromptAction<Input>
    extends Action<Input, GenerateActionOptions, void, void> {
  final ExecutablePrompt<Input>? _executablePrompt;

  PromptAction({
    required super.name,
    ExecutablePrompt<Input>? executablePrompt,
    PromptFn<Input>? fn,
    super.inputSchema,
    super.description,
    Map<String, dynamic>? metadata,
  }) : _executablePrompt = executablePrompt,
       super(
         actionType: 'prompt',
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
  ExecutablePrompt<Input>? get executablePrompt => _executablePrompt;
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
/// [ExecutablePrompt].
Future<ExecutablePrompt> lookupPrompt(
  Registry registry,
  String name, {
  String? variant,
}) async {
  final lookupName = variant != null ? '$name.$variant' : name;
  final action = await registry.lookupAction('prompt', lookupName);
  if (action != null && action is PromptAction) {
    final ep = action.executablePrompt;
    if (ep != null) return ep;
  }
  throw GenkitException(
    'Prompt $name${variant != null ? ' (variant $variant)' : ''} not found',
    status: StatusCodes.NOT_FOUND,
  );
}
