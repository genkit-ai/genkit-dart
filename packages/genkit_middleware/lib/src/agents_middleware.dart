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

import 'dart:math';

import 'package:genkit/genkit.dart' show GenkitAI, Session, getCurrentSession;
import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

part 'agents_middleware.g.dart';

// ---------------------------------------------------------------------------
// Schema
// ---------------------------------------------------------------------------

/// Configuration options for the [agents] middleware.
@Schema()
abstract class $AgentsOptions {
  @Field(
    description:
        'Names of registered agents available for delegation. Each name gets '
        'a dedicated delegation tool.',
  )
  List<String> get agents;

  @Field(
    description:
        'Prefix for generated delegation tool names. Defaults to '
        '"delegate_to" (tools become delegate_to_<agent>). Set to an empty '
        'string to use bare agent names.',
  )
  String? get toolPrefix;

  @Field(
    description:
        'Maximum sub-agent delegations allowed per generate call. Prevents '
        'runaway delegation loops.',
  )
  int? get maxDelegations;

  @Field(
    description:
        'Number of recent conversation messages (user/model only) to forward '
        'to sub-agents as additional context. 0 or omitted means only the '
        'task description is sent.',
  )
  int? get historyLength;

  @Field(
    description:
        'How sub-agent artifacts are handled: "inline" (default) includes '
        'artifact content in the delegation tool result AND merges artifacts '
        'into the parent session; "session" merges artifacts into the parent '
        'session only (the tool result mentions names but not content).',
  )
  String? get artifactStrategy;
}

/// Input schema for a generated delegation tool.
@Schema()
abstract class $DelegateInput {
  @Field(
    description: 'A clear, self-contained description of the task to delegate.',
  )
  String get task;
}

/// An artifact reported back by a delegation tool.
@Schema()
abstract class $AgentDelegationArtifact {
  @Field(description: 'Name of the artifact.')
  String? get name;

  @Field(description: 'Text content of the artifact (inline strategy only).')
  String? get content;
}

/// Output schema for a generated delegation tool.
@Schema()
abstract class $AgentDelegationResult {
  @Field(description: "The sub-agent's text response.")
  String get response;

  @Field(description: 'Artifacts produced by the sub-agent, if any.')
  List<$AgentDelegationArtifact>? get artifacts;
}

// ---------------------------------------------------------------------------
// Plugin + helper
// ---------------------------------------------------------------------------

/// Plugin that registers the `agents` sub-agent delegation middleware.
class AgentsPlugin extends GenkitPlugin {
  @override
  String get name => 'agents';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<AgentsOptions>(
      name: 'agents',
      configSchema: AgentsOptions.$schema,
      create: (config, ctx) {
        if (config == null || config.agents.isEmpty) {
          throw ArgumentError(
            'agents middleware requires at least one agent in the "agents" '
            'option.',
          );
        }
        return AgentsMiddleware(config, ctx.ai);
      },
    ),
  ];
}

/// Creates a middleware ref that enables sub-agent delegation.
///
/// For every agent name listed the middleware injects a dedicated delegation
/// tool (e.g. `delegate_to_researcher`) whose description is auto-discovered
/// from the agent's registry metadata. A `<sub-agents>` block is appended to
/// the system prompt listing the available agents and their descriptions.
GenerateMiddlewareRef<AgentsOptions> agents({
  required List<String> agents,
  String? toolPrefix,
  int? maxDelegations,
  int? historyLength,
  String? artifactStrategy,
}) {
  return middlewareRef(
    name: 'agents',
    config: AgentsOptions(
      agents: agents,
      toolPrefix: toolPrefix,
      maxDelegations: maxDelegations,
      historyLength: historyLength,
      artifactStrategy: artifactStrategy,
    ),
  );
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

String _makeToolName(String prefix, String agentName) =>
    prefix.isEmpty ? agentName : '${prefix}_$agentName';

/// Generates a short, unique invocation ID for a sub-agent call.
/// Format: `{agentName}_{random4}` — e.g. `researcher_k9m2`.
String _makeInvocationId(String agentName) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random();
  final suffix = List.generate(
    4,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return '${agentName}_$suffix';
}

/// Middleware that enables delegating tasks to registered sub-agents.
///
/// A fresh instance is created per `generate()` call, so the mutable state
/// (delegation count, captured conversation) is naturally scoped to a single
/// generation.
class AgentsMiddleware extends GenerateMiddleware {
  AgentsMiddleware(AgentsOptions options, this._ai)
    : _agentNames = options.agents,
      _prefix = options.toolPrefix ?? 'delegate_to',
      _maxDelegations = options.maxDelegations,
      _historyLength = options.historyLength ?? 0,
      _artifactStrategy = options.artifactStrategy ?? 'inline';

  final GenkitAI _ai;
  final List<String> _agentNames;
  final String _prefix;
  final int? _maxDelegations;
  final int _historyLength;
  final String _artifactStrategy;

  // Shared mutable state — scoped to a single generate() call.
  int _delegationCount = 0;
  List<Message> _conversationMessages = [];

  // Caches (persist across turns within the same generate cycle).
  final Map<String, Action> _agentCache = {};
  final Map<String, String> _descriptionCache = {};

  static const _markerKey = 'agents-middleware-instructions';

  Future<Action?> _resolveAgent(String name) async {
    final cached = _agentCache[name];
    if (cached != null) return cached;
    final action = await _ai.registry.lookupAction('agent', name);
    if (action != null) {
      _agentCache[name] = action;
    }
    return action;
  }

  Future<String?> _discoverDescription(String name) async {
    final cached = _descriptionCache[name];
    if (cached != null) return cached;

    // Try the agent action first.
    final agentAction = await _ai.registry.lookupAction('agent', name);
    var desc = agentAction?.description;

    // Fallback: `defineAgent` stores the description on the executable-prompt
    // action (the agent action itself carries no description).
    if (desc == null || desc.isEmpty) {
      final promptAction = await _ai.registry.lookupAction(
        'executable-prompt',
        name,
      );
      desc = promptAction?.description;
    }

    if (desc != null && desc.isNotEmpty) {
      _descriptionCache[name] = desc;
    }
    return desc;
  }

  @override
  List<Tool> get tools {
    return _agentNames.map((agentName) {
      final toolName = _makeToolName(_prefix, agentName);
      return Tool<DelegateInput, AgentDelegationResult>(
        name: toolName,
        description: 'Delegates a task to the "$agentName" sub-agent.',
        inputSchema: DelegateInput.$schema,
        outputSchema: AgentDelegationResult.$schema,
        fn: (input, _) => _delegate(agentName, input.task),
      );
    }).toList();
  }

  Future<AgentDelegationResult> _delegate(String agentName, String task) async {
    // ── Guard rail ──────────────────────────────────────────────────────
    if (_maxDelegations != null && _delegationCount >= _maxDelegations) {
      return AgentDelegationResult(
        response:
            'Delegation limit reached ($_maxDelegations). Complete the task '
            'using information already gathered.',
      );
    }
    _delegationCount++;

    final agentAction = await _resolveAgent(agentName);
    if (agentAction == null) {
      return AgentDelegationResult(
        response: "Error: Agent '$agentName' not found in registry.",
      );
    }

    try {
      // Optionally include recent conversation history as context. Only
      // user/model messages are forwarded, and each is reduced to its text
      // parts. This avoids leaking tool/tool-request parts — a model message
      // mid-tool-loop can carry dangling toolRequest parts with no matching
      // tool response, which would confuse the sub-agent model.
      final historyMsgs = <Message>[];
      if (_historyLength > 0 && _conversationMessages.isNotEmpty) {
        final contextMsgs = _conversationMessages
            .where((m) => m.role == Role.user || m.role == Role.model)
            .toList();
        final recent = contextMsgs.length > _historyLength
            ? contextMsgs.sublist(contextMsgs.length - _historyLength)
            : contextMsgs;
        for (final m in recent) {
          final textParts = m.content
              .where((p) => (p.text ?? '').isNotEmpty)
              .toList();
          if (textParts.isNotEmpty) {
            historyMsgs.add(Message(role: m.role, content: textParts));
          }
        }
      }

      // Prior conversation is seeded via the session state (init.state), which
      // only client-managed agents (no persistent store) accept — sending
      // state to a server-managed agent throws a precondition error. So skip
      // history forwarding for server-managed sub-agents (the task is still
      // delivered).
      final agentMeta = agentAction.metadata['agent'];
      final stateManagement = agentMeta is Map
          ? agentMeta['stateManagement']
          : null;
      final init = (historyMsgs.isNotEmpty && stateManagement != 'server')
          ? AgentInit(state: SessionState(messages: historyMsgs))
          : null;

      final runResult = await agentAction.runRaw(
        AgentInput(
          message: Message(
            role: Role.user,
            content: [TextPart(text: task)],
          ),
        ).toJson(),
        init: init?.toJson(),
      );
      final output = runResult.result as AgentOutput;

      // The agent runtime resolves gracefully rather than throwing: a failed
      // turn returns finishReason 'failed' with structured error details, and
      // an interrupted turn returns finishReason 'interrupted'. Handle both
      // explicitly here (the catch below only fires for exceptions thrown
      // outside the agent's graceful handling).

      // ── Interrupt: surface as a normal tool response ──────────────────
      // We deliberately do NOT propagate the interrupt to the parent. There is
      // no stateful sub-agent runtime to resume back into, so the parent could
      // never satisfy the interrupt. For now we report it as text the
      // orchestrator can reason about.
      if (output.finishReason == AgentFinishReason.interrupted) {
        return AgentDelegationResult(
          response:
              "Sub-agent '$agentName' interrupted for additional input and "
              'could not complete the task. Interactive sub-agent interrupts '
              'are not currently supported; try delegating a more '
              'self-contained task.',
        );
      }

      // ── Failure: surface the error to the orchestrator ────────────────
      if (output.finishReason == AgentFinishReason.failed) {
        final message = output.error?.message ?? 'Unknown sub-agent failure.';
        return AgentDelegationResult(
          response: "Error calling agent '$agentName': $message",
        );
      }

      // Extract text content from the agent's response.
      final textContent = (output.message?.content ?? [])
          .map((p) => p.text ?? '')
          .where((t) => t.isNotEmpty)
          .join('\n');

      // ── Artifact handling ─────────────────────────────────────────────
      final subArtifacts = (output.artifacts ?? [])
          .where((a) => a.name != null)
          .toList();

      final invocationId = _makeInvocationId(agentName);

      // Merge artifacts into the parent session (both strategies), if any.
      if (subArtifacts.isNotEmpty) {
        final session = getCurrentSession();
        if (session != null) {
          _mergeArtifacts(session, subArtifacts, agentName, invocationId);
        }
      }

      // Build tool result based on strategy.
      List<AgentDelegationArtifact>? artifacts;
      if (subArtifacts.isNotEmpty) {
        artifacts = subArtifacts.map((a) {
          final namespacedName = '$invocationId/${a.name}';
          if (_artifactStrategy == 'inline') {
            final content = a.parts
                .map((p) => p.text ?? '')
                .where((t) => t.isNotEmpty)
                .join('\n');
            return AgentDelegationArtifact(
              name: namespacedName,
              content: content,
            );
          }
          return AgentDelegationArtifact(name: namespacedName);
        }).toList();
      }

      return AgentDelegationResult(
        response: textContent.isNotEmpty ? textContent : '(no response)',
        artifacts: (artifacts != null && artifacts.isNotEmpty)
            ? artifacts
            : null,
      );
    } catch (e) {
      // The agent runtime resolves failures and interrupts gracefully (see
      // above), so this only fires for exceptions thrown outside that handling
      // (e.g. schema parse errors on run). Return them as tool output so the
      // model can recover.
      return AgentDelegationResult(
        response: "Error calling agent '$agentName': $e",
      );
    }
  }

  void _mergeArtifacts(
    Session session,
    List<Artifact> subArtifacts,
    String agentName,
    String invocationId,
  ) {
    final namespaced = subArtifacts.map((a) {
      return Artifact(
        name: '$invocationId/${a.name}',
        parts: a.parts,
        metadata: {
          ...?a.metadata,
          'source': agentName,
          'invocationId': invocationId,
        },
      );
    }).toList();
    session.addArtifacts(namespaced);
  }

  @override
  Future<GenerateResponseHelper> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    final options = envelope.request;

    // Capture the latest messages for optional history forwarding. Note:
    // _delegationCount is NOT reset here — the generate hook runs on every turn
    // of the tool loop, but the count must accumulate across the entire
    // generate() call.
    _conversationMessages = options.messages;

    // ── Auto-discover descriptions for the system prompt ──────────────────
    final agentList = <String>[];
    for (final agentName in _agentNames) {
      final description =
          (await _discoverDescription(agentName)) ??
          'No description available.';
      final toolName = _makeToolName(_prefix, agentName);
      agentList.add('  - $toolName: $description');
    }

    final agentsInstructions =
        '<sub-agents>\n'
        'You can delegate tasks to specialized sub-agents using their '
        'delegation tools:\n'
        '${agentList.join('\n')}\n'
        '\n'
        'When a task is better handled by a specialized agent, delegate it '
        'using the appropriate tool. Provide a clear, self-contained task '
        'description.\n'
        '</sub-agents>';

    final messages = List<Message>.from(options.messages);

    // Check if we've already injected (multi-turn).
    final alreadyInjected = messages.any(
      (msg) => msg.content.any(
        (part) => part.isText && part.metadata?[_markerKey] == true,
      ),
    );

    if (!alreadyInjected) {
      final systemIdx = messages.indexWhere((m) => m.role == Role.system);
      if (systemIdx != -1) {
        final systemMsg = messages[systemIdx];
        messages[systemIdx] = Message(
          role: systemMsg.role,
          content: [
            ...systemMsg.content,
            TextPart(text: agentsInstructions, metadata: {_markerKey: true}),
          ],
          metadata: systemMsg.metadata,
        );
      } else {
        messages.insert(
          0,
          Message(
            role: Role.system,
            content: [
              TextPart(text: agentsInstructions, metadata: {_markerKey: true}),
            ],
          ),
        );
      }
    }

    final newOptions = GenerateActionOptions(
      model: options.model,
      docs: options.docs,
      messages: messages,
      tools: options.tools,
      toolChoice: options.toolChoice,
      config: options.config,
      output: options.output,
      resume: options.resume,
      returnToolRequests: options.returnToolRequests,
      maxTurns: options.maxTurns,
      stepName: options.stepName,
    );

    return next((
      request: newOptions,
      currentTurn: envelope.currentTurn,
      messageIndex: envelope.messageIndex,
    ), ctx);
  }
}
