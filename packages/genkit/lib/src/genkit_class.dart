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

import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import 'ai/agents/agent.dart' as agent_lib;
import 'ai/agents/agent.dart' show Agent, AgentFn, ClientTransform;
import 'ai/agents/session.dart'
    show Session, SessionStore, SnapshotCallback, getCurrentSession;

import 'ai/dotprompt_registry.dart';
import 'ai/embedder.dart';
import 'ai/evaluator.dart';
import 'ai/formatters/formatters.dart';
import 'ai/generate.dart';
import 'ai/generate_middleware.dart';
import 'ai/model.dart';
import 'ai/prompt.dart';
import 'ai/prompt_loader.dart';
import 'ai/remote_model.dart';
import 'ai/resource.dart';
import 'ai/template_helper.dart';
import 'ai/tool.dart';
import 'core/action.dart';
import 'core/dynamic_action_provider.dart';
import 'core/flow.dart';
import 'core/plugin.dart';
import 'core/reflection.dart';
import 'core/registry.dart';
import 'exception.dart';
import 'genkit_ai.dart';
import 'o11y/otlp_http_exporter.dart' show configureCollectorExporter;
import 'types.dart';
import 'utils.dart' as utils;

/// The main entry point for creating Genkit applications.
///
/// The [Genkit] instance initializes the framework, loads [GenkitPlugin]s, and
/// provides a central registry for defining Genkit primitives. It exposes
/// methods to create AI actions, such as [defineFlow], [defineTool],
/// [definePrompt], and [defineResource].
///
/// It extends [GenkitAI], inheriting the model-orchestration veneer
/// ([generate], [generateStream], [generateBidi], [embed], [embedMany], [run]).
///
/// If `isDevEnv` is true or the `GENKIT_ENV` environment variable is set to
/// 'dev', initializing [Genkit] also starts a local reflection server that
/// communicates with the Genkit Developer UI.
final class Genkit extends GenkitAI {
  ReflectionServerHandle? _reflectionServer;

  late final GenerateAction _generateAction;
  late final DotpromptRegistry _dotpromptRegistry;

  Genkit({
    List<GenkitPlugin> plugins = const [],
    ModelRef? model,
    bool? isDevEnv,
    int? reflectionPort,

    /// Directory to load `.prompt` files from.
    ///
    /// Defaults to `'./prompts'`. Set to `null` to disable automatic
    /// prompt loading.
    String? promptDir = './prompts',
  }) : super(Registry()) {
    configureCollectorExporter();

    // Initialize dotprompt registry with schema resolver wired to the registry
    _dotpromptRegistry = DotpromptRegistry(
      schemaResolver: (name) async {
        return registry.lookupValue<Map<String, dynamic>>('schema', name);
      },
    );

    // Register plugins
    for (final plugin in plugins) {
      registry.registerPlugin(plugin);
      for (final mw in plugin.middleware()) {
        registry.registerValue('middleware', mw.name, mw);
      }
    }

    if (model != null) {
      registry.registerValue('defaultModel', 'defaultModel', model);
    }

    // Register default formats
    configureFormats(registry);

    if (isDevEnv ?? utils.isDevEnv) {
      _reflectionServer = startReflectionServer(registry, port: reflectionPort);
    }

    _generateAction = defineGenerateAction(registry);

    registry.register(_generateAction);

    // Load .prompt files from the prompt directory
    if (promptDir != null) {
      loadPromptFolder(registry, _dotpromptRegistry, dir: promptDir);
    }
  }

  /// Shuts down the Genkit instance, stopping the reflection server if it is running.
  ///
  /// This is mostly meant for testing purposes.
  Future<void> shutdown() async {
    if (_reflectionServer != null) {
      await _reflectionServer!.stop();
    }
  }

  /// Defines a new strongly-typed Genkit flow.
  Flow<Input, Output, Chunk, Init> defineFlow<Input, Output, Chunk, Init>({
    required String name,
    required ActionFn<Input, Output, Chunk, Init> fn,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
    SchemanticType<Chunk>? streamSchema,
    SchemanticType<Init>? initSchema,
  }) {
    final flow = Flow(
      name: name,
      fn: (input, context) {
        if (input == null && inputSchema != null && null is! Input) {
          throw ArgumentError('Flow "$name" requires a non-null input.');
        }
        return fn(input as Input, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  /// Defines a bi-directional Genkit flow.
  Flow<Input, Output, Chunk, Init> defineBidiFlow<Input, Output, Chunk, Init>({
    required String name,
    required BidiActionFn<Input, Output, Chunk, Init> fn,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
    SchemanticType<Chunk>? streamSchema,
    SchemanticType<Init>? initSchema,
  }) {
    final flow = Flow(
      name: name,
      fn: (input, context) {
        if (context.inputStream == null) {
          throw GenkitException(
            'Bidi flow $name called without an input stream',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }
        return fn(context.inputStream!, context);
      },
      inputSchema: inputSchema,
      outputSchema: outputSchema,
      streamSchema: streamSchema,
      initSchema: initSchema,
    );
    registry.register(flow);
    return flow;
  }

  /// Defines an AI tool (function) that can be invoked by a model.
  Tool<Input, Output> defineTool<Input, Output>({
    required String name,
    required String description,
    required ToolFn<Input, Output> fn,
    SchemanticType<Input>? inputSchema,
    SchemanticType<Output>? outputSchema,
  }) {
    final tool = Tool(
      name: name,
      description: description,
      fn: fn,
      inputSchema: inputSchema,
      outputSchema: outputSchema,
    );
    registry.register(tool);
    return tool;
  }

  /// Defines an executable prompt with Handlebars template support.
  ///
  /// The prompt is registered in the registry and can be looked up by name.
  /// Returns an [ExecutablePrompt] that can be called directly, rendered,
  /// or streamed.
  ///
  /// Example:
  /// ```dart
  /// final hi = ai.definePrompt(
  ///   name: 'hi',
  ///   model: modelRef('googleai/gemini-flash-latest'),
  ///   prompt: 'Say hi to {{name}}',
  /// );
  ///
  /// final response = await hi({'name': 'Sparky'});
  /// ```
  ExecutablePrompt<Input> definePrompt<CustomOptions, Input>({
    required String name,
    String? variant,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    String? description,
    SchemanticType<Input>? inputSchema,
    String? system,
    List<Part>? systemParts,
    String? prompt,
    List<Part>? promptParts,
    List<Message>? messages,
    String? messagesTemplate,
    GenerateActionOutputConfig? output,
    int? maxTurns,
    bool? returnToolRequests,
    Map<String, dynamic>? metadata,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    List<GenerateMiddlewareRef>? use,
  }) {
    final promptConfig = PromptConfig<CustomOptions, Input>(
      name: name,
      variant: variant,
      model: model,
      config: config,
      description: description,
      inputSchema: inputSchema,
      system: system,
      systemParts: systemParts,
      prompt: prompt,
      promptParts: promptParts,
      messages: messages,
      messagesTemplate: messagesTemplate,
      output: output,
      maxTurns: maxTurns,
      returnToolRequests: returnToolRequests,
      metadata: metadata,
      tools: tools,
      toolNames: toolNames,
      toolChoice: toolChoice,
      use: use,
    );
    return definePromptAction<CustomOptions, Input>(
      registry,
      _dotpromptRegistry,
      promptConfig,
      metadata: metadata,
    );
  }

  /// Defines a prompt with a custom function for programmatic message building.
  ///
  /// Use this when you need full control over how the prompt messages are
  /// constructed at runtime. For template-based prompts, use [definePrompt].
  PromptAction<Input> defineCustomPrompt<Input>({
    required String name,
    String? description,
    SchemanticType<Input>? inputSchema,
    required PromptFn<Input> fn,
    Map<String, dynamic>? metadata,
  }) {
    final promptAction = PromptAction<Input>(
      name: name,
      description: description,
      inputSchema: inputSchema,
      fn: fn,
      metadata: metadata,
    );
    registry.register(promptAction);
    return promptAction;
  }

  /// Looks up a previously defined prompt by name.
  ///
  /// Returns the [ExecutablePrompt] registered under the given name
  /// and optional variant.
  ///
  /// Example:
  /// ```dart
  /// final hi = await ai.prompt('hi');
  /// final response = await hi({'name': 'Sparky'});
  /// ```
  Future<ExecutablePrompt> prompt(String name, {String? variant}) {
    return lookupPrompt(registry, name, variant: variant);
  }

  /// Defines and registers an agent by creating a prompt and wiring it into a
  /// multi-turn agent in one step.
  ///
  /// This is a convenience shortcut for calling [definePrompt] followed by
  /// [definePromptAgent].
  Agent<State> defineAgent<CustomOptions, Input, State>({
    required String name,
    String? variant,
    ModelRef<CustomOptions>? model,
    CustomOptions? config,
    String? description,
    SchemanticType<Input>? inputSchema,
    String? system,
    List<Part>? systemParts,
    String? prompt,
    List<Part>? promptParts,
    List<Message>? messages,
    String? messagesTemplate,
    GenerateActionOutputConfig? output,
    int? maxTurns,
    bool? returnToolRequests,
    Map<String, dynamic>? metadata,
    List<Tool>? tools,
    List<String>? toolNames,
    String? toolChoice,
    List<GenerateMiddlewareRef>? use,

    /// Supplies values for the prompt's input variables, so a single prompt
    /// can be reused and customized by multiple agents.
    Map<String, dynamic>? promptInput,

    /// Optional schema describing the shape of the custom session state. When
    /// provided, `chat().state` / `res.state` return parsed `State` instances.
    SchemanticType<State>? stateSchema,
    SessionStore? store,
    SnapshotCallback? snapshotCallback,
    ClientTransform? clientTransform,
  }) {
    // Register the prompt.
    definePrompt<CustomOptions, Input>(
      name: name,
      variant: variant,
      model: model,
      config: config,
      description: description,
      inputSchema: inputSchema,
      system: system,
      systemParts: systemParts,
      prompt: prompt,
      promptParts: promptParts,
      messages: messages,
      messagesTemplate: messagesTemplate,
      output: output,
      maxTurns: maxTurns,
      returnToolRequests: returnToolRequests,
      metadata: metadata,
      tools: tools,
      toolNames: toolNames,
      toolChoice: toolChoice,
      use: use,
    );

    // Wire it into a prompt agent.
    return agent_lib.definePromptAgent<State>(
      registry,
      promptName: variant != null ? '$name.$variant' : name,
      promptInput: promptInput,
      stateSchema: stateSchema,
      store: store,
      snapshotCallback: snapshotCallback,
      clientTransform: clientTransform,
    );
  }

  /// Registers a multi-turn custom agent action capable of maintaining
  /// persistent state.
  ///
  /// Use this when you need full control over the agent turn loop. For the
  /// common prompt-driven case, use [defineAgent].
  Agent<State> defineCustomAgent<State>({
    required String name,
    String? description,
    SchemanticType<State>? stateSchema,
    SessionStore? store,
    SnapshotCallback? snapshotCallback,
    ClientTransform? clientTransform,
    required AgentFn fn,
  }) {
    return agent_lib.defineCustomAgent<State>(
      registry,
      name: name,
      description: description,
      stateSchema: stateSchema,
      store: store,
      snapshotCallback: snapshotCallback,
      clientTransform: clientTransform,
      fn: fn,
    );
  }

  /// Registers an agent from an existing, previously-defined prompt.
  Agent<State> definePromptAgent<State>({
    required String promptName,

    /// Supplies values for the prompt's input variables, so a single prompt
    /// can be reused and customized by multiple agents.
    Map<String, dynamic>? promptInput,
    SchemanticType<State>? stateSchema,
    SessionStore? store,
    SnapshotCallback? snapshotCallback,
    ClientTransform? clientTransform,
  }) {
    return agent_lib.definePromptAgent<State>(
      registry,
      promptName: promptName,
      promptInput: promptInput,
      stateSchema: stateSchema,
      store: store,
      snapshotCallback: snapshotCallback,
      clientTransform: clientTransform,
    );
  }

  /// Returns the [Session] active in the current agent turn, or `null` when
  /// called outside of an agent turn.
  Session? currentSession() => getCurrentSession();

  /// Registers a Handlebars partial template for use in prompts.
  ///
  /// Partials can be referenced in prompt templates using `{{> name}}`.
  void definePartial(String name, String source) {
    _dotpromptRegistry.definePartial(name, source);
  }

  /// Registers a custom Handlebars helper function for use in prompts.
  ///
  /// Helpers can be referenced in prompt templates using `{{helperName arg}}`.
  void defineHelper(String name, TemplateHelperFn helper) {
    _dotpromptRegistry.defineHelper(name, helper);
  }

  /// Registers a named JSON Schema for use in prompt templates.
  ///
  /// Named schemas can be referenced by name in Picoschema definitions
  /// within `.prompt` files or inline prompt templates. This is useful for
  /// sharing common data structures across multiple prompts.
  ///
  /// Example:
  /// ```dart
  /// ai.defineSchema('MyAddress', {
  ///   'type': 'object',
  ///   'properties': {
  ///     'street': {'type': 'string'},
  ///     'city': {'type': 'string'},
  ///     'zip': {'type': 'string'},
  ///   },
  ///   'required': ['street', 'city', 'zip'],
  /// });
  /// ```
  void defineSchema(String name, Map<String, dynamic> jsonSchema) {
    registry.registerValue('schema', name, jsonSchema);
    _dotpromptRegistry.defineSchema(name, jsonSchema);
  }

  /// Defines a Genkit resource.
  ResourceAction defineResource({
    String? name,
    String? uri,
    String? template,
    String? description,
    Map<String, dynamic>? metadata,
    required ResourceFn fn,
  }) {
    final resourceName = name ?? uri ?? template;
    if (resourceName == null) {
      throw GenkitException(
        'Resource must specify a name, uri, or template.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    final resourceMetadata = <String, dynamic>{
      ...?metadata,
      'resource': {'uri': uri, 'template': template},
    };
    final resource = ResourceAction(
      name: resourceName,
      description: description,
      metadata: resourceMetadata,
      matches: createResourceMatcher(uri: uri, template: template),
      fn: fn,
    );
    registry.register(resource);
    return resource;
  }

  /// Defines an AI model interface.
  Model defineModel({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk, void> fn,
  }) {
    final model = Model(
      name: name,
      fn: (input, context) {
        return fn(input!, context);
      },
    );
    registry.register(model);
    return model;
  }

  /// Defines a bi-directional AI model interface.
  BidiModel defineBidiModel({
    required String name,
    required BidiActionFn<
      ModelRequest,
      ModelResponse,
      ModelResponseChunk,
      ModelRequest
    >
    fn,
  }) {
    final model = BidiModel(
      name: name,
      fn: (input, context) {
        if (context.inputStream == null) {
          throw GenkitException(
            'Bidi model $name called without an input stream',
            status: StatusCodes.INVALID_ARGUMENT,
          );
        }
        return fn(context.inputStream!, context);
      },
    );
    registry.register(model);
    return model;
  }

  /// Defines a remote Genkit model.
  Model defineRemoteModel({
    required String name,
    required String url,
    FutureOr<Map<String, String>?> Function(Map<String, dynamic> context)?
    headers,
    ModelInfo? modelInfo,
    http.Client? httpClient,
  }) {
    final model = remoteModel(
      name: name,
      url: url,
      headers: headers,
      modelInfo: modelInfo,
      httpClient: httpClient,
    );
    registry.register(model);
    return model;
  }

  /// Defines an embedder model.
  Embedder defineEmbedder({
    required String name,
    required ActionFn<EmbedRequest, EmbedResponse, void, void> fn,
  }) {
    final embedder = Embedder(
      name: name,
      fn: (input, context) {
        return fn(input!, context);
      },
    );
    registry.register(embedder);
    return embedder;
  }

  /// Defines a dynamic provider for actions.
  DynamicActionProvider defineDynamicActionProvider({
    required String name,
    FutureOr<Iterable<ActionMetadata>> Function()? listActionsFn,
    FutureOr<Action?> Function(String)? getActionFn,
    Map<String, dynamic>? metadata,
  }) {
    final provider = DynamicActionProvider(
      name: name,
      listActionsFn: listActionsFn,
      getActionFn: getActionFn,
      metadata: metadata,
    );
    registry.register(provider);
    return provider;
  }

  /// Defines an evaluator.
  Evaluator defineEvaluator({
    required String name,
    required String description,
    required ActionFn<EvalRequest, List<EvalFnResponse>, void, void> fn,
  }) {
    final evaluator = Evaluator(
      name: name,
      description: description,
      fn: (input, context) {
        return fn(input!, context);
      },
    );
    registry.register(evaluator);
    return evaluator;
  }
}
