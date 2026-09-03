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

import 'dart:async';

import 'package:genkit/genkit.dart' show GenkitAI, getCurrentSession;
import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

part 'agents_middleware.g.dart';
part 'agents_middleware_async.dart';
part 'agents_middleware_continue.dart';

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

  @Field(
    description:
        'Enables background delegation. Delegation tools accept a "background" '
        'flag that starts the sub-agent and returns a taskId immediately, and '
        'the check_background_tasks / wait_for_background_tasks / '
        'abort_background_tasks tools are added. Background delegation requires '
        'server-managed sub-agents (those with a session store that supports '
        'detach).',
  )
  bool? get async;
}

/// Input schema for a generated delegation tool.
@Schema()
abstract class $DelegateInput {
  @Field(
    description: 'A clear, self-contained description of the task to delegate.',
  )
  String get task;

  @Field(
    description:
        'Optional short label for this delegation (e.g. "sources-sweep"). '
        'Echoed on the result and on background-task reports next to the '
        'taskId, to keep several tasks readable. Not an identifier.',
  )
  String? get name;
}

/// Input schema for a delegation tool when [$AgentsOptions.async] is set: the
/// plain input plus the background flag.
@Schema()
abstract class $AsyncDelegateInput {
  @Field(
    description: 'A clear, self-contained description of the task to delegate.',
  )
  String get task;

  @Field(
    description:
        'Optional short label for this delegation. Echoed on the result and on '
        'background-task reports next to the taskId. Not an identifier.',
  )
  String? get name;

  @Field(
    description:
        'Run the delegation in the background. The tool returns immediately '
        'with a taskId; collect the result later with check_background_tasks '
        'or wait_for_background_tasks.',
  )
  bool? get background;
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

  @Field(
    description:
        'Handle for this delegation ("<agent>:<snapshotId>"), when the '
        'sub-agent keeps a session. Pass it to check_background_tasks, '
        'wait_for_background_tasks, abort_background_tasks, or continue_task.',
  )
  String? get taskId;

  @Field(
    description:
        'Outcome behind taskId: "pending" for a background launch, or the '
        'settled status ("completed", "failed", "aborted") for a synchronous '
        'delegation that carries a handle.',
  )
  String? get status;

  @Field(description: 'The caller-chosen label for this delegation, if given.')
  String? get name;
}

/// Input for the check and abort background-task tools: a list of task handles.
@Schema()
abstract class $BackgroundTasksInput {
  @Field(
    description:
        'Task IDs returned by background delegations (form '
        '"<agent>:<snapshotId>").',
  )
  List<String>? get taskIds;
}

/// Input for the wait background-task tool: the handle list plus a bound on how
/// long to block and the join semantics.
@Schema()
abstract class $WaitBackgroundTasksInput {
  @Field(
    description:
        'Task IDs returned by background delegations (form '
        '"<agent>:<snapshotId>").',
  )
  List<String>? get taskIds;

  @Field(
    description:
        'Maximum seconds to wait before returning the current statuses. 0 or '
        'omitted waits until every task settles; a negative value returns the '
        'current statuses immediately.',
  )
  int? get timeoutSeconds;

  @Field(
    description:
        '"all" (default) waits until every listed task settles. "first" '
        'returns as soon as any one settles; the remaining tasks report their '
        'current status and keep running.',
  )
  String? get waitFor;
}

/// A per-task entry returned by the check and wait background-task tools.
@Schema()
abstract class $BackgroundTaskReport {
  @Field(description: 'The task handle this report describes.')
  String get taskId;

  @Field(description: 'The sub-agent running the task.')
  String? get agent;

  @Field(description: 'The caller-chosen label of the delegation, if given.')
  String? get name;

  @Field(
    description:
        'Lifecycle state: "pending", "completed", "failed", "aborted", '
        '"expired", "aborting", or "unknown".',
  )
  String get status;

  @Field(
    description: "The sub-agent's final text response, for completed tasks.",
  )
  String? get response;

  @Field(description: 'The completed task\'s artifacts, if any.')
  List<$AgentDelegationArtifact>? get artifacts;

  @Field(
    description:
        'Describes why no response is available (failure, abort, expiry, or an '
        'unresolvable task ID).',
  )
  String? get error;
}

/// Output for the check and wait background-task tools.
@Schema()
abstract class $BackgroundTasksResult {
  @Field(description: 'One report per requested task ID.')
  List<$BackgroundTaskReport>? get tasks;

  @Field(
    description:
        'Set when the wait returned because timeoutSeconds elapsed while some '
        'tasks were still pending.',
  )
  bool? get timedOut;

  @Field(description: 'Usage guidance when the call itself was unusable.')
  String? get note;
}

/// Input for the continue_task tool.
@Schema()
abstract class $ContinueInput {
  @Field(
    description:
        'The task handle to continue ("<agent>:<snapshotId>"), from a '
        'delegation result or a background-task report.',
  )
  String get taskId;

  @Field(
    description:
        'Optional guidance delivered to the sub-agent as it continues. Omit it '
        'to retry a failed or aborted task exactly as it stood; required when '
        'following up on a completed task.',
  )
  String? get instructions;
}

/// Input for the continue_task tool when [$AgentsOptions.async] is set.
@Schema()
abstract class $AsyncContinueInput {
  @Field(
    description:
        'The task handle to continue ("<agent>:<snapshotId>"), from a '
        'delegation result or a background-task report.',
  )
  String get taskId;

  @Field(
    description:
        'Optional guidance delivered to the sub-agent as it continues. Omit it '
        'to retry a failed or aborted task exactly as it stood; required when '
        'following up on a completed task.',
  )
  String? get instructions;

  @Field(
    description:
        'Continue the task in the background. The tool returns immediately '
        'with a new taskId; collect the result later with the background-task '
        'tools.',
  )
  bool? get background;
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
///
/// With [async] set, delegation tools additionally accept a `background` flag,
/// and the `check_background_tasks` / `wait_for_background_tasks` /
/// `abort_background_tasks` tools are added for collecting background results.
GenerateMiddlewareRef<AgentsOptions> agents({
  required List<String> agents,
  String? toolPrefix,
  int? maxDelegations,
  int? historyLength,
  String? artifactStrategy,
  bool? async,
}) {
  return middlewareRef(
    name: 'agents',
    config: AgentsOptions(
      agents: agents,
      toolPrefix: toolPrefix,
      maxDelegations: maxDelegations,
      historyLength: historyLength,
      artifactStrategy: artifactStrategy,
      async: async,
    ),
  );
}

// ---------------------------------------------------------------------------
// Names + small helpers
// ---------------------------------------------------------------------------

const _defaultToolPrefix = 'delegate_to';
const _checkBackgroundTasksToolName = 'check_background_tasks';
const _waitBackgroundTasksToolName = 'wait_for_background_tasks';
const _abortBackgroundTasksToolName = 'abort_background_tasks';
const _continueTaskToolName = 'continue_task';

const _waitForAll = 'all';
const _waitForFirst = 'first';

/// Report status for a task that could not be resolved (malformed ID,
/// unconfigured agent, missing snapshot, or read error).
const _taskStatusUnknown = 'unknown';

/// Snapshot statuses that can no longer change on their own. Mirrors the
/// runtime's terminal set; `expired` is terminal but can still be re-read as a
/// settled row, so it is deliberately not cached (see `_reportTask`).
const _terminalStatuses = {'completed', 'failed', 'aborted', 'expired'};

/// Builds a delegation tool name from the prefix and agent name. An empty
/// prefix yields the bare agent name.
String _makeToolName(String prefix, String agentName) =>
    prefix.isEmpty ? agentName : '${prefix}_$agentName';

/// Builds the model-facing handle of a background delegation. Self-contained
/// (`<agent>:<snapshotId>`) so it survives a re-instantiated orchestrator that
/// has only its conversation history.
String _formatTaskId(String agentName, String snapshotId) =>
    '$agentName:$snapshotId';

/// Trims a snapshot ID to a compact artifact-namespace component.
String _shortSnapshotId(String id) => id.length > 8 ? id.substring(0, 8) : id;

/// Joins a message's non-empty text parts with newlines.
String _messageText(Message? m) => (m?.content ?? [])
    .map((p) => p.text ?? '')
    .where((t) => t.isNotEmpty)
    .join('\n');

/// Whether a settled finish reason carries a usable answer. Only `stop` does;
/// `blocked`, `length`, `failed`, `aborted`, `interrupted`, and `detached` do
/// not (mirrors Go's `FinishReason.CarriesResult`).
bool _carriesResult(AgentFinishReason? reason) =>
    reason?.value == AgentFinishReason.stop.value;

/// Maps a settled finish reason onto the status vocabulary shared by delegation
/// results and background-task reports.
String _settledStatus(AgentFinishReason? reason) {
  if (_carriesResult(reason)) return SnapshotStatus.completed.value;
  if (reason?.value == AgentFinishReason.aborted.value) {
    return SnapshotStatus.aborted.value;
  }
  return SnapshotStatus.failed.value;
}

/// The snapshot a settled output names, or `null` when nothing durable stands
/// behind it: a client-managed run, or a detached one (whose snapshotId names a
/// pending row rather than a settled turn).
String? _settledSnapshotId(AgentOutput out) {
  if (out.finishReason?.value == AgentFinishReason.detached.value) return null;
  return out.snapshotId;
}

/// Explains to the orchestrator why a sub-agent turn produced no answer. Prefers
/// the structured error, falls back to the agent's last message, and names the
/// finish reason when it has neither.
String _subAgentFailureMessage(
  AgentFinishReason? reason,
  AgentErrorInfo? error,
  Message? last,
) {
  final errMsg = error?.message;
  if (errMsg != null && errMsg.isNotEmpty) return errMsg;
  if (reason == null || reason.value.isEmpty) {
    return 'Unknown sub-agent failure.';
  }
  var msg = 'the turn ended as "${reason.value}" without completing the task';
  final text = _messageText(last);
  if (text.isNotEmpty) msg += '; the agent\'s last message was: $text';
  return '$msg.';
}

/// Tool text reported when a sub-agent interrupts for input the orchestrator
/// can never provide.
String _interruptedResponse(String agentName) =>
    "Sub-agent '$agentName' interrupted for additional input and could not "
    'complete the task. Interactive sub-agent interrupts are not currently '
    'supported; try delegating a more self-contained task.';

/// Tool text for a run that settled on a result-carrying reason but produced no
/// final model text (a custom agent that returned no message, or a model whose
/// last message holds only tool requests).
String _noFinalMessageResponse(int artifacts) {
  switch (artifacts) {
    case 0:
      return 'The task completed, but the agent gave no final message and '
          'produced no artifacts.';
    case 1:
      return 'The task completed, but the agent gave no final message; its '
          'result is in the one artifact it produced.';
    default:
      return 'The task completed, but the agent gave no final message; its '
          'result is in the $artifacts artifacts it produced.';
  }
}

/// The persisted conversation's final model message: what the sub-agent last
/// said. `null` when the snapshot carries no state or no model message.
Message? _lastModelMessage(SessionSnapshot snap) {
  final msgs = snap.state?.messages;
  if (msgs == null) return null;
  for (var i = msgs.length - 1; i >= 0; i--) {
    if (msgs[i].role == Role.model) return msgs[i];
  }
  return null;
}

/// Whether a read failure cannot be helped by retrying: the row is gone or the
/// request itself is rejected. Anything else is presumed transient.
bool _deadEndRead(Object err) {
  if (err is! GenkitException) return false;
  final s = err.status;
  return s == StatusCodes.NOT_FOUND ||
      s == StatusCodes.FAILED_PRECONDITION ||
      s == StatusCodes.INVALID_ARGUMENT;
}

// ---------------------------------------------------------------------------
// Resolved agent handle
// ---------------------------------------------------------------------------

/// A resolved sub-agent's actions and metadata, the Dart analog of Go's
/// `aix.AgentHandle`. Bundles the primary turn action with its snapshot/abort
/// companion actions and the parsed [AgentMetadata], so a delegation or a
/// background-task read spends one registry resolution instead of several.
class _AgentHandle {
  _AgentHandle({
    required this.name,
    required this.primary,
    this.snapshot,
    this.abort,
    this.metadata,
  });

  final String name;
  final Action primary;
  final Action? snapshot;
  final Action? abort;
  final AgentMetadata? metadata;

  /// Whether the agent owns its state on the client (no session store), the
  /// only case that accepts seeded init state. Unknown metadata is treated as
  /// not client-managed (the safe default: avoid seeding state an agent might
  /// reject), matching Go.
  bool get isClientManaged =>
      metadata?.stateManagement.value == AgentStateManagement.client.value;

  /// Whether the agent can run in the background (its store supports detach).
  /// Unknown metadata is treated as abortable (a wrong guess costs a refusal at
  /// launch time, not a silently missing capability), matching Go.
  bool get abortable => metadata?.abortable ?? true;
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

/// Middleware that enables delegating tasks to registered sub-agents.
///
/// A fresh instance is created per `generate()` call, so the mutable state
/// (delegation count, invocation sequence, captured conversation, task caches)
/// is naturally scoped to a single generation.
///
/// Concurrency note: unlike the Go port this needs no mutex. Dart runs one
/// isolate, so the shared counters mutate atomically between `await` points;
/// parallel tool calls interleave only at those points, and the reserve/release
/// bookkeeping is written to be correct across them.
class AgentsMiddleware extends GenerateMiddleware {
  AgentsMiddleware(AgentsOptions options, this._ai)
    : _agentNames = options.agents,
      _prefix = options.toolPrefix ?? _defaultToolPrefix,
      _sharedPrefix = options.toolPrefix ?? '',
      _maxDelegations = options.maxDelegations,
      _historyLength = options.historyLength ?? 0,
      _artifactStrategy = options.artifactStrategy ?? 'inline',
      _async = options.async ?? false;

  final GenkitAI _ai;
  final List<String> _agentNames;
  final String _prefix;

  /// Prefix for the shared tools (background-task + continue). An explicitly set
  /// `toolPrefix` namespaces them so two instances with distinct prefixes can
  /// coexist; the default `delegate_to` is a delegation verb, not an instance
  /// namespace, so it is not applied here (a null prefix is the same as empty).
  final String _sharedPrefix;
  final int? _maxDelegations;
  final int _historyLength;
  final String _artifactStrategy;
  final bool _async;

  // Shared mutable state — scoped to a single generate() call.

  /// Delegations made so far, enforcing [_maxDelegations].
  int _delegationCount = 0;

  /// Allocates invocation numbers; never decreases (unlike [_delegationCount]),
  /// so a refunded delegation's number is never reissued and two delegations
  /// cannot share an artifact namespace.
  int _seq = 0;

  List<Message> _conversationMessages = [];

  // Caches (persist across turns within the same generate cycle).
  final Map<String, _AgentHandle> _handleCache = {};
  final Map<String, String> _descriptionCache = {};

  /// Caller-chosen labels by task handle, echoed on background-task reports.
  final Map<String, String> _taskLabels = {};

  /// Terminal background-task reports cached for the rest of the call: settled
  /// rows never change, so a re-check skips the snapshot fetch and artifact
  /// re-merge.
  final Map<String, BackgroundTaskReport> _settledReports = {};

  static const _markerKey = 'agents-middleware-instructions';

  String get _checkToolName =>
      _makeToolName(_sharedPrefix, _checkBackgroundTasksToolName);
  String get _waitToolName =>
      _makeToolName(_sharedPrefix, _waitBackgroundTasksToolName);
  String get _abortToolName =>
      _makeToolName(_sharedPrefix, _abortBackgroundTasksToolName);
  String get _continueToolName =>
      _makeToolName(_sharedPrefix, _continueTaskToolName);

  // ── Resolution ────────────────────────────────────────────────────────

  /// Resolves a sub-agent's handle (primary + companion actions + metadata),
  /// caching it for the call. Returns `null` when the primary action is absent.
  Future<_AgentHandle?> _resolveHandle(String name) async {
    final cached = _handleCache[name];
    if (cached != null) return cached;

    final primary = await _ai.registry.lookupAction(.agent, name);
    if (primary == null) return null;

    final snapshot = await _ai.registry.lookupAction(.agentSnapshot, name);
    final abort = await _ai.registry.lookupAction(.agentAbort, name);

    AgentMetadata? metadata;
    final raw = primary.metadata['agent'];
    if (raw is Map<String, dynamic>) {
      metadata = AgentMetadata.fromJson(raw);
    }

    final handle = _AgentHandle(
      name: name,
      primary: primary,
      snapshot: snapshot,
      abort: abort,
      metadata: metadata,
    );
    _handleCache[name] = handle;
    return handle;
  }

  Future<String> _discoverDescription(String name) async {
    final cached = _descriptionCache[name];
    if (cached != null) return cached;

    final agentAction = await _ai.registry.lookupAction(.agent, name);
    var desc = agentAction?.description;

    // Fallback: `defineAgent` stores the description on the executable-prompt
    // action (the agent action itself may carry none).
    if (desc == null || desc.isEmpty) {
      final promptAction = await _ai.registry.lookupAction(
        .executablePrompt,
        name,
      );
      desc = promptAction?.description;
    }

    final resolvedDesc = (desc != null && desc.isNotEmpty)
        ? desc
        : 'No description available.';
    _descriptionCache[name] = resolvedDesc;
    return resolvedDesc;
  }

  // ── Tools ───────────────────────────────────────────────────────────────

  @override
  List<Tool> get tools {
    final tools = <Tool>[];
    for (final agentName in _agentNames) {
      final toolName = _makeToolName(_prefix, agentName);
      final description = 'Delegates a task to the "$agentName" sub-agent.';
      if (_async) {
        tools.add(
          Tool<AsyncDelegateInput, AgentDelegationResult>(
            name: toolName,
            description: description,
            inputSchema: AsyncDelegateInput.$schema,
            toolOutputSchema: AgentDelegationResult.$schema,
            fn: (input, _) async => .response(
              input.background == true
                  ? await _launchDelegation(agentName, input.task, input.name)
                  : await _runDelegation(agentName, input.task, input.name),
            ),
          ),
        );
      } else {
        tools.add(
          Tool<DelegateInput, AgentDelegationResult>(
            name: toolName,
            description: description,
            inputSchema: DelegateInput.$schema,
            toolOutputSchema: AgentDelegationResult.$schema,
            fn: (input, _) async => .response(
              await _runDelegation(agentName, input.task, input.name),
            ),
          ),
        );
      }
    }

    if (_async) tools.addAll(_backgroundTaskTools());

    // The continue tool is always registered when agents are configured. Go
    // registers it only when a sub-agent may be server-managed, but that needs
    // async agent resolution the synchronous `tools` getter cannot do here, so
    // it is registered unconditionally and refuses gracefully for a
    // client-managed handle.
    tools.add(_continueTool());

    return tools;
  }

  // ── Delegation ──────────────────────────────────────────────────────────

  /// Reserves the next delegation's invocation number, enforcing
  /// [_maxDelegations]. Returns `null` when the cap is reached.
  int? _reserveDelegation() {
    if (_maxDelegations != null && _delegationCount >= _maxDelegations) {
      return null;
    }
    _delegationCount++;
    _seq++;
    return _seq;
  }

  /// Returns a reserved cap slot to a delegation whose refusal names a retry
  /// that can succeed (see the callers). The released invocation number is never
  /// reissued (the [_seq] allocator only increases).
  void _releaseDelegation() => _delegationCount--;

  /// The prologue every delegation shares: enforces [_maxDelegations], reserves
  /// the invocation number, and resolves the sub-agent. A non-null `refusal` is
  /// the tool result to return as-is.
  Future<
    ({int invocationNum, _AgentHandle? handle, AgentDelegationResult? refusal})
  >
  _beginDelegation(String name) async {
    final invocationNum = _reserveDelegation();
    if (invocationNum == null) {
      return (
        invocationNum: 0,
        handle: null,
        refusal: AgentDelegationResult(
          response:
              'Delegation limit reached ($_maxDelegations). Complete the task '
              'using information already gathered.',
        ),
      );
    }
    final handle = await _resolveHandle(name);
    if (handle == null) {
      // A resolution failure keeps its slot: the agent is misconfigured or
      // missing, so every retry fails the same way, and refunding would leave
      // the cap unable to bite on exactly the runaway loop it exists to stop.
      return (
        invocationNum: 0,
        handle: null,
        refusal: AgentDelegationResult(
          response: "Error: Agent '$name' not found in registry.",
        ),
      );
    }
    return (invocationNum: invocationNum, handle: handle, refusal: null);
  }

  /// The synchronous delegation body, shared by the plain delegation tool and
  /// the async-enabled variant when the model does not request background.
  Future<AgentDelegationResult> _runDelegation(
    String name,
    String task,
    String? label,
  ) async {
    final begun = await _beginDelegation(name);
    if (begun.refusal != null) return begun.refusal!;
    final handle = begun.handle!;

    // History rides in client-managed init state, which server-managed agents
    // reject; forward it only to client-managed sub-agents.
    AgentInit? init;
    if (handle.isClientManaged) {
      final history = _recentTextHistory(_conversationMessages, _historyLength);
      if (history.isNotEmpty) {
        init = AgentInit(state: SessionState(messages: history));
      }
    }

    try {
      final out = await _runSubAgent(
        handle,
        message: Message(
          role: Role.user,
          content: [TextPart(text: task)],
        ),
        init: init,
      );
      final result = _foldDelegationOutput(handle, out, begun.invocationNum);
      _labelTask(result, label);
      return result;
    } catch (e) {
      // The agent runtime resolves failures/interrupts gracefully, so this only
      // fires for exceptions outside that handling. Keep the slot: the payload
      // is built the same way each time, so a retry fails the same way.
      return AgentDelegationResult(response: "Error calling agent '$name': $e");
    }
  }

  /// Runs one turn of the sub-agent. [detach] asks the runtime to move the work
  /// to the background immediately; [init] names the session source (seeded
  /// history for client-managed agents, or a snapshotId for a continuation).
  Future<AgentOutput> _runSubAgent(
    _AgentHandle handle, {
    Message? message,
    bool detach = false,
    AgentInit? init,
  }) async {
    final runResult = await handle.primary.runRaw(
      AgentInput(message: message, detach: detach ? true : null).toJson(),
      init: init?.toJson(),
    );
    return runResult.result as AgentOutput;
  }

  /// Turns a settled sub-agent output into a delegation tool result: interrupts
  /// and failures become explanatory text, and artifacts are merged into the
  /// parent session and surfaced per the configured strategy. A server-managed
  /// output is stamped with the `<agent>:<snapshotId>` handle and its outcome,
  /// and its artifacts are namespaced by the snapshot (so a later re-check of
  /// the same run merges identical names). A client-managed run is namespaced by
  /// [invocationNum].
  AgentDelegationResult _foldDelegationOutput(
    _AgentHandle handle,
    AgentOutput out,
    int invocationNum,
  ) {
    final name = handle.name;

    // Interrupted first: it carries no result and no handle (continuing past it
    // means answering the interrupt, which the orchestrator cannot do).
    if (out.finishReason?.value == AgentFinishReason.interrupted.value) {
      return AgentDelegationResult(response: _interruptedResponse(name));
    }

    var namespace = '${name}_$invocationNum';
    String? taskId;
    String? status;
    final settledId = _settledSnapshotId(out);
    if (settledId != null && settledId.isNotEmpty) {
      taskId = _formatTaskId(name, settledId);
      status = _settledStatus(out.finishReason);
      namespace = '${name}_${_shortSnapshotId(settledId)}';
    }

    if (!_carriesResult(out.finishReason)) {
      // Blocked, truncated, aborted, or failed. The last message explains the
      // outcome rather than answering the task.
      var response =
          "Error calling agent '$name': "
          '${_subAgentFailureMessage(out.finishReason, out.error, out.message)}';
      if (taskId != null) {
        response +=
            " The run's progress up to that point is saved; call "
            '$_continueToolName with this taskId to continue it, optionally '
            'with instructions.';
      }
      return AgentDelegationResult(
        response: response,
        taskId: taskId,
        status: status,
      );
    }

    final subArtifacts = (out.artifacts ?? [])
        .where((a) => a.name != null && a.name!.isNotEmpty)
        .toList();

    var response = _messageText(out.message);
    if (response.isEmpty) {
      response = _noFinalMessageResponse(subArtifacts.length);
    }

    List<AgentDelegationArtifact>? artifacts;
    if (subArtifacts.isNotEmpty) {
      // Merge into the parent session under both strategies (no-op if there is
      // no active session, e.g. a plain generate call).
      _mergeArtifacts(name, namespace, subArtifacts);
      artifacts = _delegatedArtifacts(namespace, subArtifacts);
    }

    return AgentDelegationResult(
      response: response,
      artifacts: (artifacts != null && artifacts.isNotEmpty) ? artifacts : null,
      taskId: taskId,
      status: status,
    );
  }

  /// Namespaces the sub-agent's artifacts, tags them with their source, and
  /// merges them into the active session. A no-op when there is no session.
  void _mergeArtifacts(
    String source,
    String namespace,
    List<Artifact> subArtifacts,
  ) {
    final session = getCurrentSession();
    if (session == null) return;
    final namespaced = subArtifacts.map((a) {
      return Artifact(
        name: '$namespace/${a.name}',
        parts: a.parts,
        metadata: {...?a.metadata, 'source': source, 'invocationId': namespace},
      );
    }).toList();
    session.addArtifacts(namespaced);
  }

  /// Builds the tool-result artifact list, including content only under the
  /// inline strategy.
  List<AgentDelegationArtifact> _delegatedArtifacts(
    String namespace,
    List<Artifact> subArtifacts,
  ) {
    return subArtifacts.map((a) {
      final namespacedName = '$namespace/${a.name}';
      if (_artifactStrategy == 'inline') {
        final content = a.parts
            .map((p) => p.text ?? '')
            .where((t) => t.isNotEmpty)
            .join('\n');
        return AgentDelegationArtifact(name: namespacedName, content: content);
      }
      return AgentDelegationArtifact(name: namespacedName);
    }).toList();
  }

  /// Stamps the caller-chosen label on a settled result and records it against
  /// the result's handle so background-task reports can echo it.
  void _labelTask(AgentDelegationResult result, String? label) {
    if (label == null || label.isEmpty) return;
    result.name = label;
    final taskId = result.taskId;
    if (taskId != null) _taskLabels[taskId] = label;
  }

  /// Returns up to [n] of the most recent user/model messages, each reduced to
  /// its non-empty text parts. Tool and tool-request parts are dropped (a model
  /// message mid-tool-loop can carry a dangling toolRequest that would confuse
  /// the sub-agent model). Empty when [n] <= 0.
  List<Message> _recentTextHistory(List<Message> msgs, int n) {
    if (n <= 0) return const [];
    final filtered = <Message>[];
    for (final m in msgs) {
      if (m.role != Role.user && m.role != Role.model) continue;
      final parts = m.content
          .where((p) => (p.text ?? '').isNotEmpty)
          .map((p) => TextPart(text: p.text!) as Part)
          .toList();
      if (parts.isNotEmpty) filtered.add(Message(role: m.role, content: parts));
    }
    if (filtered.length > n) {
      return filtered.sublist(filtered.length - n);
    }
    return filtered;
  }

  // ── Task handle parsing ───────────────────────────────────────────────────

  /// Parses a task handle by matching it against the configured agents, taking
  /// the longest matching name so a configured name containing ':' cannot have
  /// its tasks claimed by a shorter configured prefix of it. Returns `null` when
  /// no configured agent matches.
  ({String name, String snapshotId})? _resolveTaskId(String taskId) {
    String? best;
    var bestLen = 0;
    for (final name in _agentNames) {
      final prefix = '$name:';
      if (taskId.length > prefix.length &&
          taskId.startsWith(prefix) &&
          prefix.length > bestLen) {
        best = name;
        bestLen = prefix.length;
      }
    }
    if (best == null) return null;
    return (name: best, snapshotId: taskId.substring(bestLen));
  }

  // ── Generate hook ─────────────────────────────────────────────────────────

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
    // _delegationCount is NOT reset here — the hook runs on every tool-loop
    // turn, but the count must accumulate across the entire generate() call.
    _conversationMessages = options.messages;

    final agentList = <String>[];
    for (final agentName in _agentNames) {
      final description = await _discoverDescription(agentName);
      agentList.add('  - ${_makeToolName(_prefix, agentName)}: $description');
    }

    final agentsInstructions = _buildInstructions(agentList);

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

  /// Renders the `<sub-agents>` system prompt block, adding the async and
  /// continue guidance when those tools are active.
  String _buildInstructions(List<String> agentList) {
    final b = StringBuffer()
      ..writeln('<sub-agents>')
      ..writeln(
        'You can delegate tasks to specialized sub-agents using their '
        'delegation tools:',
      )
      ..writeln(agentList.join('\n'))
      ..writeln()
      ..writeln(
        'When a task is better handled by a specialized agent, delegate it '
        'using the appropriate tool. Provide a clear, self-contained task '
        'description.',
      );

    if (_async) {
      b
        ..writeln()
        ..writeln(
          'Delegations can run in the background: set "background": true on a '
          'delegation tool call to get a taskId back immediately while the '
          'sub-agent keeps working. Continue with other work, then collect '
          'results with $_checkToolName (returns current status without '
          'waiting) or $_waitToolName (blocks until the tasks settle). Use '
          '$_abortToolName to stop tasks whose results are no longer needed. '
          'Background tasks keep running across turns, and task IDs from '
          'earlier tool results stay valid: check them before delegating the '
          'same work again.',
        );
    }

    b
      ..writeln()
      ..writeln(
        'Results of delegations to sub-agents that keep sessions carry a '
        'taskId where the sub-agent\'s progress is addressable. If such a '
        'delegation fails or is aborted, its saved progress is not lost: call '
        '$_continueToolName with the taskId to continue it from where it '
        'stopped, either as-is or steered with instructions. A completed task '
        'accepts follow-up instructions in its own session the same way, '
        'without repeating the finished work. A task that stopped on an '
        'interrupt cannot be continued. A result without a taskId is not '
        'continuable; delegate again to redo that work.',
      )
      ..write('</sub-agents>');
    return b.toString();
  }
}
