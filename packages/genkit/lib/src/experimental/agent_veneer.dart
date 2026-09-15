// Copyright 2026 Google LLC
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

/// Experimental agent veneer on the [Genkit] instance.
///
/// These methods live in the experimental surface so they can evolve without a
/// major version bump. See `package:genkit/experimental.dart` for the stability
/// policy.
library;

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

import '../ai/agents/agent.dart' as agent_lib;
import '../ai/agents/agent.dart' show Agent, AgentFn, ClientTransform;
import '../ai/agents/session.dart'
    show Session, SessionStore, getCurrentSession;
import '../ai/generate_middleware.dart' show GenerateMiddlewareRef;
import '../ai/model.dart' show ModelRef;
import '../ai/tool.dart' show Tool;
import '../genkit_class.dart';
import '../types.dart' show GenerateActionOutputConfig, Message, Part;

/// Experimental agent-authoring methods on [Genkit].
///
/// Import `package:genkit/experimental.dart` to bring these into scope. They
/// only touch the public [Genkit] surface (the registry and [Genkit.definePrompt]),
/// so call sites read the same as any built-in method: `ai.defineAgent(...)`.
@experimental
extension GenkitAgents on Genkit {
  /// Defines and registers an agent by creating a prompt and wiring it into a
  /// multi-turn agent in one step.
  ///
  /// This is a convenience shortcut for calling [Genkit.definePrompt] followed
  /// by [definePromptAgent].
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
    ClientTransform? clientTransform,
    required AgentFn<State> fn,
  }) {
    return agent_lib.defineCustomAgent<State>(
      registry,
      name: name,
      description: description,
      stateSchema: stateSchema,
      store: store,
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
    ClientTransform? clientTransform,
  }) {
    return agent_lib.definePromptAgent<State>(
      registry,
      promptName: promptName,
      promptInput: promptInput,
      stateSchema: stateSchema,
      store: store,
      clientTransform: clientTransform,
    );
  }

  /// Returns the [Session] active in the current agent turn, or `null` when
  /// called outside of an agent turn.
  ///
  /// When a `State` type argument is supplied it is applied to the returned
  /// session so `getCustom()` / `updateCustom(...)` are typed. Because Dart
  /// generics are reified, the requested `State` must match the one the running
  /// agent was defined with (a mismatch throws on the cast). Defaults to the
  /// untyped `Session<dynamic>?` view.
  Session<State>? currentSession<State>() => getCurrentSession<State>();
}
